# fail2ban + SWAG Integration Skill

Manage fail2ban intrusion prevention system running inside the SWAG reverse proxy container for comprehensive security monitoring and IP blocking.

## What It Does

- **Monitor Security**: View fail2ban status, active jails, and banned IPs
- **Manage Bans**: Manually ban/unban IP addresses
- **Create Custom Jails**: Build protection for specific attack patterns
- **Test Filters**: Validate regex patterns against actual logs
- **Troubleshoot Issues**: Debug why bans aren't working
- **Backup/Restore**: Save and restore fail2ban configurations
- **View Logs**: Monitor fail2ban and nginx logs in real-time

## Setup

### Environment Configuration

This skill requires environment variables to be configured. Add these to your `~/.homelab-skills/.env` file:

```bash
# fail2ban-swag configuration
SWAG_HOST="your-hostname"                    # Hostname or IP of server running SWAG
SWAG_CONTAINER_NAME="swag"                   # SWAG container name (default: swag)
SWAG_APPDATA_PATH="/path/to/appdata/swag"   # Path to SWAG appdata directory
```

**Example configuration:**
```bash
SWAG_HOST="homelab.local"
SWAG_CONTAINER_NAME="swag"
SWAG_APPDATA_PATH="/mnt/appdata/swag"
```

### Prerequisites

1. **SSH Access**: Ensure you can SSH to your SWAG host without password (SSH keys configured)
2. **Script Permissions**: Make the wrapper script executable

```bash
cd skills/fail2ban-swag
chmod +x scripts/fail2ban-swag.sh
```

3. **Test Connection**:
```bash
./scripts/fail2ban-swag.sh status
```

## Usage Examples

### Check Current Status

```bash
# View overall fail2ban status
./scripts/fail2ban-swag.sh status

# List all active jails
./scripts/fail2ban-swag.sh list-jails

# Check specific jail
./scripts/fail2ban-swag.sh jail-status nginx-http-auth
```

### View Banned IPs

```bash
# Check banned IPs in specific jail
./scripts/fail2ban-swag.sh banned-ips nginx-unauthorized

# Search for specific IP in logs
./scripts/fail2ban-swag.sh search-ip 192.168.1.100
```

### Unban Someone

```bash
# Unban from all jails
./scripts/fail2ban-swag.sh unban 192.168.1.100

# Unban from specific jail
./scripts/fail2ban-swag.sh unban 192.168.1.100 nginx-http-auth
```

### Create Custom Protection

**Example: Block repeated 403 Forbidden responses**

```bash
# 1. Create filter
./scripts/fail2ban-swag.sh create-filter custom-403 \
  --regex '^<HOST>.*"(GET|POST).*" (403) .*$'

# 2. Test filter
./scripts/fail2ban-swag.sh test-filter custom-403

# 3. Create jail
./scripts/fail2ban-swag.sh create-jail custom-403 \
  --filter custom-403 \
  --logpath "/config/log/nginx/access.log" \
  --maxretry 10 \
  --findtime 300 \
  --bantime 3600

# 4. Reload fail2ban
./scripts/fail2ban-swag.sh reload

# 5. Verify jail is active
./scripts/fail2ban-swag.sh jail-status custom-403
```

### Monitor Activity

```bash
# Watch fail2ban log in real-time
./scripts/fail2ban-swag.sh logs --follow

# Watch nginx access log
./scripts/fail2ban-swag.sh nginx-access-log --follow

# View recent activity
./scripts/fail2ban-swag.sh logs | tail -50
```

### Troubleshoot Issues

```bash
# Check if bans are working (view iptables rules)
./scripts/fail2ban-swag.sh iptables

# Test filter regex against logs
./scripts/fail2ban-swag.sh test-filter nginx-http-auth

# Search for IP across all logs
./scripts/fail2ban-swag.sh search-ip 45.133.172.215
```

## Workflow

### Daily Operations

1. **Morning Check**:
   - Run `./scripts/fail2ban-swag.sh status`
   - Review any bans: `./scripts/fail2ban-swag.sh logs | grep Ban | tail -20`

2. **User Locked Out**:
   - Identify IP: Ask user for their IP or check logs
   - Unban: `./scripts/fail2ban-swag.sh unban <ip>`
   - Verify: `./scripts/fail2ban-swag.sh search-ip <ip>`

3. **Create Custom Protection**:
   - Identify attack pattern in logs
   - Create filter with regex
   - Test filter against logs
   - Create jail with appropriate thresholds
   - Reload fail2ban
   - Monitor jail activity

### Weekly Maintenance

1. **Review Ban Activity**:
```bash
for jail in nginx-http-auth nginx-badbots nginx-botsearch nginx-deny nginx-unauthorized; do
    echo "=== $jail ==="
    ./scripts/fail2ban-swag.sh jail-status "$jail"
done
```

2. **Backup Configuration**:
```bash
./scripts/fail2ban-swag.sh backup
# Saves: fail2ban-backup-YYYY-MM-DD.tar.gz
```

3. **Check for False Positives**:
```bash
# Review recent bans
./scripts/fail2ban-swag.sh logs | grep "Ban " | tail -50

# If legitimate IPs banned, add to whitelist in jail.local
```

## Troubleshooting

### Bans Not Working

**Check:**
1. fail2ban is running: `ssh $SWAG_HOST "docker exec $SWAG_CONTAINER_NAME ps aux | grep fail2ban"`
2. Correct iptables chain: `./scripts/fail2ban-swag.sh iptables | grep DOCKER-USER`
3. Jail configuration: Verify `chain = DOCKER-USER` in jail.local
4. Container has NET_ADMIN capability

**Solution:**
```bash
# Verify configuration
./scripts/fail2ban-swag.sh jail-status <jail-name>

# Check iptables rules
./scripts/fail2ban-swag.sh iptables

# Reload fail2ban
./scripts/fail2ban-swag.sh reload
```

### Filter Not Matching

**Check:**
```bash
# Test filter against logs
./scripts/fail2ban-swag.sh test-filter <filter-name>

# Expected output: "Lines: X matches: Y"
# If matches: 0, regex needs adjustment
```

**Solution:**
- View actual log format: `./scripts/fail2ban-swag.sh nginx-access-log | head -5`
- Test regex at regex101.com (Python flavor)
- Adjust filter regex
- Reload fail2ban

### High False Positives

**Check:**
- Which IPs are getting banned: `./scripts/fail2ban-swag.sh logs | grep Ban`
- Which jails are triggering: `./scripts/fail2ban-swag.sh jail-status <jail>`

**Solution:**
- Add legitimate IPs to ignoreip in jail.local
- Increase maxretry threshold
- Increase findtime window
- Adjust filter regex to be more specific

## Notes

### Important Considerations

- **fail2ban runs INSIDE the SWAG container** - all commands execute via `docker exec`
- **Uses DOCKER-USER iptables chain** - INPUT chain will NOT work for containers
- **Requires NET_ADMIN capability** - container needs elevated privileges for iptables
- **Configuration persists via bind mounts** - stored at `${SWAG_APPDATA_PATH}/fail2ban/`

### Common Jails

Typical SWAG installations include these jails:

1. **nginx-http-auth**: HTTP Basic Auth failures
2. **nginx-badbots**: Malicious User-Agents
3. **nginx-botsearch**: Vulnerability scanners
4. **nginx-deny**: nginx access rule violations
5. **nginx-unauthorized**: HTTP 401 responses (most active)

### Whitelisted Networks

Typical networks to whitelist in `ignoreip` configuration:

- 10.0.0.0/24, 192.168.0.0/24 (Private LANs)
- 172.16.0.0/12 (Docker networks)
- Your external admin IP (e.g., 203.0.113.10)

### Security Recommendations

1. **Monitor regularly**: Check status daily
2. **Review bans**: Look for patterns in banned IPs
3. **Adjust thresholds**: Fine-tune based on false positive rate
4. **Backup configuration**: Weekly backups before changes
5. **Test filters**: Always test new filters before deploying
6. **Document custom jails**: Keep notes on why custom protections were added

## Reference

### Documentation

- **SKILL.md**: Complete skill documentation with all commands and workflows
- **references/quick-reference.md**: Copy-paste command examples
- **references/filter-examples.md**: Pre-built filter patterns for common attacks
- **references/troubleshooting.md**: Detailed troubleshooting procedures

### Research

- See `../docs/research/swag-fail2ban-integration/` for detailed setup documentation and research findings

### Official Resources

- [fail2ban Documentation](https://fail2ban.readthedocs.io/)
- [LinuxServer.io SWAG Docs](https://docs.linuxserver.io/images/docker-swag)
- [fail2ban Filters](https://fail2ban.readthedocs.io/en/latest/filters.html)

## Getting Help

**Collect diagnostics:**
```bash
{
  echo "=== fail2ban status ==="
  ./scripts/fail2ban-swag.sh status

  echo ""
  echo "=== Recent logs ==="
  ./scripts/fail2ban-swag.sh logs | tail -50

  echo ""
  echo "=== iptables ==="
  ./scripts/fail2ban-swag.sh iptables
} > diagnostics.txt
```

**Ask Claude Code**:
- "Check fail2ban status"
- "Why isn't this IP getting banned?"
- "Create a jail to block SQL injection attempts"
- "Unban my IP address"
