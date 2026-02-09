# UniFi API Troubleshooting

## Authentication Issues

### ".env file not found"
**Cause:** Missing `.env` file

**Solution:**
1. Create `.env` file:
   ```bash
   cat >> ~/claude-homelab/.env <<EOF
   UNIFI_URL="https://10.1.0.1"
   UNIFI_USERNAME="api"
   UNIFI_PASSWORD="your-password"
   UNIFI_SITE="default"
   EOF
   ```
2. Set restrictive permissions:
   ```bash
   chmod 600 ~/claude-homelab/.env
   ```

### "UNIFI_URL and UNIFI_USERNAME must be set in .env"
**Cause:** Missing required environment variables

**Solution:**
1. Verify all required variables are in `.env`:
   ```bash
   grep UNIFI ~/claude-homelab/.env
   ```
2. Required variables:
   - `UNIFI_URL` (e.g., `https://10.1.0.1`)
   - `UNIFI_USERNAME` (e.g., `api`)
   - `UNIFI_PASSWORD` (your local admin password)
   - `UNIFI_SITE` (usually `default`)

### "Login failed (empty cookie file)"
**Cause:** Invalid credentials or controller unreachable

**Solution:**
1. Verify credentials in `.env`:
   ```bash
   cat ~/claude-homelab/.env | grep UNIFI
   ```
2. Test connection manually:
   ```bash
   curl -sk "https://10.1.0.1/status"
   ```
3. Check username/password (local UniFi OS user, not Ubiquiti account)
4. Verify HTTPS access to gateway IP
5. Check if UniFi Network application is running on gateway

### "Cannot reach UniFi controller"
**Cause:** Network connectivity or gateway offline

**Solution:**
1. Ping gateway IP:
   ```bash
   ping -c 3 10.1.0.1
   ```
2. Check if you're on the same network/VLAN
3. Verify firewall not blocking HTTPS (443)
4. Check gateway is powered on and booted
5. Try accessing UniFi OS web UI in browser

### "Network application error: Unauthorized"
**Cause:** Cookie expired or invalid session

**Solution:**
1. Delete cached cookie and retry:
   ```bash
   unset UNIFI_COOKIE_FILE
   cd ~/claude-homelab/skills/unifi
   bash scripts/health.sh
   ```
2. Verify credentials are correct
3. Check user has admin privileges (Settings → Admins)
4. Try creating a new local admin user

## SSL Certificate Errors

### "SSL certificate problem: unable to get local issuer certificate"
**Cause:** Self-signed certificate on UniFi gateway

**Solution:**
All scripts use `-k` flag with curl (insecure mode) to skip certificate validation. This is expected for local UniFi OS gateways with self-signed certificates.

If you want to use proper certificates:
1. Install custom SSL cert on UniFi OS gateway
2. Or add gateway cert to system trust store
3. Remove `-k` flag from `unifi-api.sh`

## Device Issues

### Devices showing as "disconnected" but are online
**Cause:** Adoption issue or device reboot

**Solution:**
1. Check device state in web UI (Settings → Devices)
2. Force re-adoption:
   - SSH to device
   - Run: `set-inform http://controller-ip:8080/inform`
3. Check device has network connectivity to gateway
4. Verify PoE power if applicable (switches/APs)

### Device not appearing in device list
**Cause:** Device not adopted or wrong site

**Solution:**
1. Verify device is on network and powered
2. Check adoption status in web UI
3. Verify correct site in `.env`:
   ```bash
   UNIFI_SITE="default"  # or your site name
   ```
4. List all sites:
   ```bash
   source scripts/unifi-api.sh
   curl -sk -b "$UNIFI_COOKIE_FILE" "$UNIFI_URL/api/users/self" | jq
   ```

### Incorrect device count
**Cause:** Cached data or stale API response

**Solution:**
1. Re-run script to refresh data
2. Check health endpoint for accurate counts:
   ```bash
   bash scripts/health.sh
   ```
3. Compare with web UI device list

## Client Issues

### Client not appearing in active clients
**Cause:** Client disconnected or API caching

**Solution:**
1. Verify client is actually connected (check device directly)
2. Wait 60 seconds for controller to update
3. Check if client is on guest network (different isolation settings)
4. Verify client has valid IP address (DHCP lease)

### Client hostname showing as "Unknown"
**Cause:** Client not providing hostname via DHCP

**Solution:**
1. Use MAC or IP to identify client
2. Set custom alias in UniFi web UI (Settings → WiFi)
3. Check client DHCP settings (some devices don't send hostname)
4. Use MAC vendor lookup to identify device type

### Client signal showing as 0 dBm
**Cause:** Wired client (signal only applies to wireless)

**Solution:**
Check `is_wired` field:
```bash
bash scripts/clients.sh json | jq '.data[] | select(.ip == "10.1.10.50") | {hostname, is_wired, signal}'
```

## Bandwidth & DPI Issues

### Top apps showing empty or missing data
**Cause:** DPI not enabled or insufficient data collected

**Solution:**
1. Enable Deep Packet Inspection:
   - Settings → Traffic Management → Enable DPI
   - Wait 24 hours for data collection
2. Check if data exists:
   ```bash
   source scripts/unifi-api.sh
   unifi_get stat/sitedpi | jq '.data[0].by_app | length'
   ```
3. Verify network traffic is flowing through gateway (not bypassed)

### DPI showing incorrect application
**Cause:** DPI signature limitations

**Solution:**
1. DPI is best-effort and may misidentify encrypted traffic
2. Use port-based filtering as fallback
3. Check UniFi DPI database version (Settings → System)
4. Known limitation: Encrypted protocols (HTTPS, VPN) harder to classify

### Bandwidth stats don't match other tools
**Cause:** Different measurement periods or sampling

**Solution:**
1. UniFi DPI tracks cumulative traffic since last reset
2. Compare same time periods
3. Check if data is site-wide vs per-device
4. Note: DPI adds ~5% CPU overhead, may affect accuracy on busy networks

## Alert Issues

### Not seeing recent alerts
**Cause:** Alert retention or wrong time filter

**Solution:**
1. Check alert count:
   ```bash
   source scripts/unifi-api.sh
   unifi_get stat/alarm | jq '.data | length'
   ```
2. Increase limit:
   ```bash
   bash scripts/alerts.sh 100
   ```
3. Check alert settings (Settings → Notifications)
4. Verify system time is correct on gateway

### Too many false positive alerts
**Cause:** Overly sensitive alert thresholds

**Solution:**
1. Adjust alert settings in web UI
2. Filter by alert type:
   ```bash
   source scripts/unifi-api.sh
   unifi_get stat/alarm | jq '.data[] | select(.key | contains("Disconnected"))'
   ```
3. Disable non-critical alerts (Settings → Notifications)

## Connection Issues

### "Connection refused" error
**Cause:** Wrong port or UniFi OS not running

**Solution:**
1. UniFi OS uses HTTPS (443), not 8443:
   ```bash
   # Correct
   UNIFI_URL="https://10.1.0.1"

   # Wrong
   UNIFI_URL="https://10.1.0.1:8443"
   ```
2. Verify port access:
   ```bash
   telnet 10.1.0.1 443
   ```
3. Check UniFi OS is running (access web UI)

### "Timeout" errors
**Cause:** Network latency or gateway overloaded

**Solution:**
1. Increase curl timeout in `unifi-api.sh`:
   ```bash
   curl -sk --max-time 30 ...
   ```
2. Check gateway CPU/memory usage (web UI → System)
3. Reduce concurrent API calls
4. Check network path for latency issues

### Intermittent connection failures
**Cause:** Cookie expiration or session timeout

**Solution:**
1. Scripts automatically re-login on failure
2. If persists, check gateway logs:
   - Web UI → System → Logs
3. Verify no firewall/IDS blocking API calls
4. Check for UniFi OS updates (may fix bugs)

## Data Issues

### Stale or outdated data
**Cause:** API caching or controller sync delay

**Solution:**
1. Wait 60-120 seconds for controller to update
2. Force refresh by disconnecting/reconnecting device
3. Check controller health:
   ```bash
   bash scripts/health.sh
   ```
4. Restart UniFi Network application if needed

### Missing fields in JSON output
**Cause:** Field not supported by device or firmware version

**Solution:**
1. Check device firmware (Settings → System → Firmware)
2. Update to latest firmware
3. Not all devices support all fields (e.g., older APs)
4. Use conditional checks in scripts:
   ```bash
   jq '.data[] | {name, uptime: (.uptime // "N/A")}'
   ```

## Multi-Site Issues

### Cannot access non-default site
**Cause:** Wrong site name in configuration

**Solution:**
1. List all sites:
   ```bash
   source scripts/unifi-api.sh
   curl -sk -b "$UNIFI_COOKIE_FILE" "$UNIFI_URL/api/users/self" | jq '.sites'
   ```
2. Update `.env` with correct site name:
   ```bash
   UNIFI_SITE="site-name"  # Not display name, actual site ID
   ```
3. Common site names: `default`, `site01`, `home`, etc.

### Data mixed between sites
**Cause:** Site not properly scoped in API calls

**Solution:**
All scripts automatically scope to site defined in `UNIFI_SITE`. Verify site name is correct in `.env`.

## Performance Issues

### Slow script execution
**Cause:** Multiple API calls or large data sets

**Solution:**
1. Use JSON output and cache locally:
   ```bash
   bash scripts/devices.sh json > /tmp/devices.json
   jq '.data[] | select(.name == "AP1")' < /tmp/devices.json
   ```
2. Reduce alert/event limits:
   ```bash
   bash scripts/alerts.sh 20  # Instead of 100
   ```
3. Run scripts less frequently (e.g., every 5 minutes vs every minute)

### Dashboard script times out
**Cause:** Too many concurrent API calls

**Solution:**
1. Use individual scripts instead of dashboard for specific data
2. Increase timeout in scripts
3. Check gateway resources (CPU/memory)

## API Endpoint Issues

### "404 Not Found" on specific endpoint
**Cause:** Endpoint not available on your UniFi OS version

**Solution:**
1. Check tested endpoints in `references/unifi-readonly-endpoints.md`
2. Verify UniFi OS version (Settings → System)
3. Update UniFi OS if endpoint requires newer version
4. Some endpoints only on UDM/UDR (not UCG)

### "api.err.NotFound" in JSON response
**Cause:** Resource doesn't exist or wrong path

**Solution:**
1. Check endpoint path is correct (case-sensitive)
2. Verify resource exists (e.g., device MAC, site name)
3. See tested endpoints for known working paths

## Known Limitations

- **API Documentation:** UniFi local API is largely undocumented and reverse-engineered
- **Version Differences:** Endpoints vary by UniFi OS and Network app version
- **Rate Limiting:** No official rate limits, but too many requests may slow gateway
- **Data Retention:** Historical data limited (typically 7 days for most stats)
- **DPI Accuracy:** Encrypted traffic harder to classify correctly
- **Cookie Duration:** Sessions may expire after inactivity (scripts auto-refresh)
- **Write Operations:** These scripts are read-only by design (no configuration changes)

## Version-Specific Issues

### UniFi OS Console (UCG Max, UDM, UDR)
- Uses `/proxy/network` prefix (handled automatically)
- HTTPS on port 443 (not 8443)
- UniFi OS login required (not just Network app)

### Legacy Controllers
- Use port 8443
- Different API paths (no `/proxy/network`)
- Scripts designed for UniFi OS, may need modification

## Debug Mode

Enable detailed curl output for debugging:

```bash
cd ~/claude-homelab/skills/unifi

# Show full curl commands
bash -x scripts/devices.sh 2>&1 | grep curl

# Test login manually
source scripts/unifi-api.sh
curl -vsk -c /tmp/unifi-cookie.txt \
  -H "Content-Type: application/json" \
  -X POST "$UNIFI_URL/api/auth/login" \
  --data '{"username":"'$UNIFI_USERNAME'","password":"'$UNIFI_PASSWORD'"}'
```

## Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| "Login failed (empty cookie file)" | Invalid credentials | Check username/password in `.env` |
| "Cannot reach UniFi controller" | Network/connectivity issue | Verify IP, check network access |
| "api.err.NotFound" | Wrong endpoint or resource | Check endpoint path, verify resource exists |
| "api.err.Unauthorized" | Session expired | Delete cookie, script will re-login |
| "SSL certificate problem" | Self-signed cert | Expected behavior, scripts use `-k` flag |
| Empty data array | No devices/clients | Check adoption status, verify data exists |
| "Connection refused" | Wrong port or service down | Use 443, check UniFi OS is running |

## Getting Help

1. **Check logs:** UniFi OS logs (System → Logs in web UI)
2. **Verify setup:** Run `bash scripts/health.sh` to test connectivity
3. **Test endpoints:** Use `curl` directly to test API calls
4. **Check documentation:** See `references/unifi-readonly-endpoints.md`
5. **Community:** UniFi forums and r/Ubiquiti for API questions

## Useful Debug Commands

```bash
cd ~/claude-homelab/skills/unifi
source scripts/unifi-api.sh

# Test login
unifi_login /tmp/test-cookie.txt && echo "Login successful" || echo "Login failed"

# Test API access
unifi_get stat/health | jq '.meta.rc'  # Should return "ok"

# Check connectivity
curl -sk "$UNIFI_URL/status" | jq

# List all available data
unifi_get stat/sysinfo | jq keys
```
