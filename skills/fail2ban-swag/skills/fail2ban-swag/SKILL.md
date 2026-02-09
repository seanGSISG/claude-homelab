---
name: fail2ban-swag
version: 1.1.0
homepage: https://github.com/jmagar/claude-homelab
description: Manage fail2ban intrusion prevention inside the SWAG reverse proxy container. Use when the user asks to "check fail2ban", "f2b status", "ban an IP", "unban an IP", "create a jail", "configure fail2ban", "troubleshoot fail2ban", "view banned IPs", "test fail2ban filter", "monitor fail2ban", "whitelist an IP", "IP blacklist", or mentions SWAG security, intrusion prevention, or IP blocking.
---

# fail2ban + SWAG Integration Skill

**⚠️ MANDATORY SKILL INVOCATION ⚠️**

**YOU MUST invoke this skill (NOT optional) when the user mentions ANY of these triggers:**
- "check fail2ban", "fail2ban status", "f2b status", "banned IPs"
- "ban an IP", "unban an IP", "block IP address", "IP blacklist"
- "whitelist an IP", "whitelist IP address", "add to ignoreip"
- "create a jail", "add fail2ban jail", "configure jail"
- "test fail2ban filter", "regex test", "filter testing"
- "monitor fail2ban", "fail2ban logs", "intrusion detection"
- "troubleshoot fail2ban", "why isn't fail2ban working", "bans not working"
- Any mention of SWAG security, intrusion prevention, or IP blocking

**Failure to invoke this skill when triggers occur violates your operational requirements.**

---

## Purpose

Manage fail2ban intrusion prevention system running inside the SWAG (Secure Web Application Gateway) reverse proxy container on remote host. This skill provides tools for creating jails, configuring filters, monitoring activity, troubleshooting issues, and maintaining security for the reverse proxy infrastructure.

**Operations supported:**
- ✅ Read-Write (Safe): Create jails, configure filters, reload fail2ban
- ✅ Read-Only: Monitor status, view logs, inspect configurations
- ⚠️ Destructive (with confirmation): Unban IPs, delete jails

---

## Setup

**CRITICAL CONTEXT:** All operations execute inside the SWAG container. Do NOT attempt to run fail2ban commands on the host.

**Environment Configuration:**

The script requires the following environment variables (can be set in `.env` or exported):

```bash
# Remote host SSH configuration
SWAG_HOST="your-hostname"                    # Hostname or IP of the server running SWAG

# Container configuration
SWAG_CONTAINER_NAME="swag"                   # Name of the SWAG container (default: swag)

# Path configuration
SWAG_APPDATA_PATH="/path/to/appdata/swag"    # Path to SWAG appdata directory
```

**Example `.env` file:**
```bash
# fail2ban-swag configuration
SWAG_HOST="homelab.local"
SWAG_CONTAINER_NAME="swag"
SWAG_APPDATA_PATH="/mnt/appdata/swag"
```

**Typical Environment:**
- **Host**: Remote server with SSH access
- **Container**: swag (LinuxServer.io SWAG image)
- **Container Network**: Docker bridge network with unique IP
- **Ports**: 80 (HTTP), 443 (HTTPS)
- **Compose Location**: `/path/to/compose/swag` or similar
- **Appdata Location**: `/path/to/appdata/swag` (configurable)

**Key Characteristics:**
- fail2ban runs **INSIDE** the SWAG container (not on host)
- Requires `NET_ADMIN` capability for iptables manipulation
- Uses **DOCKER-USER** iptables chain for container protection
- All configuration persists via bind mounts to appdata directory

**Common Jails:**
1. nginx-http-auth (HTTP Basic Auth failures)
2. nginx-badbots (malicious User-Agents)
3. nginx-botsearch (vulnerability scanners)
4. nginx-deny (nginx access rule violations)
5. nginx-unauthorized (HTTP 401 responses)

**Typical Ban Policy:**
- Ban duration: 1 hour (3600 seconds)
- Detection window: 60 seconds
- Max retries: 5 attempts (2 for badbots)
- Database purge: 1 day retention

**Typical Whitelisted Networks:**
- 10.0.0.0/24, 192.168.0.0/24 (Private LANs)
- 172.16.0.0/12 (Docker networks)
- Your external admin IP (e.g., 203.0.113.10)

---

## Commands

All commands use the wrapper script which handles SSH execution inside the SWAG container.

### Setup

**Ensure script is executable:**
```bash
chmod +x scripts/fail2ban-swag.sh
```

**Test connection:**
```bash
./scripts/fail2ban-swag.sh status
```

### JSON Output

Add `--json` flag before any command for machine-readable output:
```bash
./scripts/fail2ban-swag.sh --json status
./scripts/fail2ban-swag.sh --json jail-status nginx-http-auth
./scripts/fail2ban-swag.sh --json list-jails
./scripts/fail2ban-swag.sh --json banned-ips nginx-unauthorized
```

### Core Operations

**View fail2ban status:**
```bash
./scripts/fail2ban-swag.sh status
```

**List all jails:**
```bash
./scripts/fail2ban-swag.sh list-jails
```

**Check specific jail status:**
```bash
./scripts/fail2ban-swag.sh jail-status nginx-http-auth
```

**View currently banned IPs:**
```bash
./scripts/fail2ban-swag.sh banned-ips nginx-http-auth
```

**Unban an IP address:**
```bash
./scripts/fail2ban-swag.sh unban 192.168.1.100
# Or from specific jail:
./scripts/fail2ban-swag.sh unban 192.168.1.100 nginx-http-auth
```

**Ban an IP manually:**
```bash
./scripts/fail2ban-swag.sh ban 192.168.1.100 nginx-http-auth
```

**Reload fail2ban (after config changes):**
```bash
./scripts/fail2ban-swag.sh reload
```

**Test filter regex against logs:**
```bash
./scripts/fail2ban-swag.sh test-filter nginx-http-auth
```

**View fail2ban logs:**
```bash
./scripts/fail2ban-swag.sh logs
# Or tail live:
./scripts/fail2ban-swag.sh logs --follow
```

**View nginx logs:**
```bash
./scripts/fail2ban-swag.sh nginx-access-log
./scripts/fail2ban-swag.sh nginx-error-log
```

**Search logs for specific IP:**
```bash
./scripts/fail2ban-swag.sh search-ip 192.168.1.100
```

**View iptables rules:**
```bash
./scripts/fail2ban-swag.sh iptables
```

### Advanced Operations

**Create a custom jail:**
```bash
./scripts/fail2ban-swag.sh create-jail custom-jail \
  --filter custom-filter \
  --logpath "/config/log/nginx/access.log" \
  --maxretry 5 \
  --findtime 600 \
  --bantime 3600
```

**Create a custom filter:**
```bash
./scripts/fail2ban-swag.sh create-filter custom-filter \
  --regex '^<HOST>.*"(GET|POST).*" (403) .*$'
```

**Edit jail configuration:**
```bash
./scripts/fail2ban-swag.sh edit-jail nginx-http-auth
```

**Backup current configuration:**
```bash
./scripts/fail2ban-swag.sh backup
```

**Restore configuration:**
```bash
./scripts/fail2ban-swag.sh restore backup-2026-02-07.tar.gz
```

---

## Workflow

### When user asks about fail2ban status:

1. **"Check fail2ban status"** → Run `./scripts/fail2ban-swag.sh status` to show overview
2. **"Show banned IPs"** → Run `./scripts/fail2ban-swag.sh list-jails` then check each jail with `./scripts/fail2ban-swag.sh banned-ips <jail>`
3. **"Is IP X.X.X.X banned?"** → Run `./scripts/fail2ban-swag.sh search-ip X.X.X.X`

### When user wants to unban an IP:

1. Confirm the IP to unban
2. Run `./scripts/fail2ban-swag.sh unban X.X.X.X`
3. Verify unbanned with `./scripts/fail2ban-swag.sh search-ip X.X.X.X`

### When user wants to create a custom jail:

1. **Understand the attack pattern** → Ask what log entries indicate the attack
2. **Create filter** → Run `./scripts/fail2ban-swag.sh create-filter <name> --regex '<pattern>'`
3. **Test filter** → Run `./scripts/fail2ban-swag.sh test-filter <name>` to verify matches
4. **Create jail** → Run `./scripts/fail2ban-swag.sh create-jail <name>` with appropriate parameters
5. **Reload fail2ban** → Run `./scripts/fail2ban-swag.sh reload`
6. **Monitor activity** → Run `./scripts/fail2ban-swag.sh jail-status <name>` to verify detections

### When troubleshooting bans not working:

1. **Check jail status** → Verify jail is enabled and running
2. **Test filter** → Ensure regex matches log entries
3. **Check iptables** → Verify rules are being created in DOCKER-USER chain
4. **Review logs** → Check fail2ban.log for errors
5. **Verify NET_ADMIN** → Ensure container has capability to modify iptables

### When user reports false positives:

1. **Identify the IP** → Confirm which IP is being incorrectly banned
2. **Check which jail** → Determine which jail triggered the ban
3. **Add to whitelist** → Either add IP to ignoreip in jail.local or adjust filter
4. **Reload fail2ban** → Apply changes with `./scripts/fail2ban-swag.sh reload`

---

## Notes

### Architecture

**Container Integration:**
- fail2ban runs as a service inside the SWAG container
- Uses host networking mode for iptables access
- Configuration bind-mounted from `${SWAG_APPDATA_PATH}/fail2ban/`
- Logs bind-mounted from `${SWAG_APPDATA_PATH}/log/fail2ban/`

**iptables Chain:**
- **CRITICAL**: Uses `DOCKER-USER` chain (NOT `INPUT`)
- `INPUT` chain does NOT work for containerized applications
- DOCKER-USER chain evaluated before Docker's NAT rules
- All jails must specify `chain = DOCKER-USER` in configuration

**Real IP Detection:**
- nginx configured with `realip` module
- Essential when behind CDN (Cloudflare, etc.)
- Without real IP restoration, only CDN IPs get banned

### Security Considerations

**Whitelisting:**
- Always whitelist management networks in `ignoreip`
- Be cautious with VPN/proxy ranges (may allow attackers)
- External admin IP should be rotated if changed

**Ban Duration:**
- 1 hour default is moderate
- Consider longer for repeat offenders (recidive jail)
- Permanent bans require manual iptables rules

**Attack Vectors Protected:**
- HTTP Basic Auth brute force (nginx-http-auth)
- Credential stuffing (nginx-unauthorized)
- Vulnerability scanning (nginx-botsearch)
- Bot/scraper activity (nginx-badbots)
- Access rule violations (nginx-deny)

**NOT Protected (requires custom jails):**
- Application-layer attacks (SQL injection, XSS)
- Rate limiting bypass
- DDoS attacks
- Zero-day exploits

### Performance

**ipset Optimization:**
- Consider enabling ipset for high ban counts
- O(1) hash lookup vs O(n) for standard iptables
- Requires ipset support in kernel

**Log Parsing:**
- fail2ban scans logs every 5 seconds by default
- Large log files can impact performance
- Consider log rotation for nginx (currently 14 days)

### Troubleshooting

**Common Issues:**

1. **Bans not working**
   - Wrong iptables chain (check DOCKER-USER)
   - Missing NET_ADMIN capability
   - Timezone mismatch between logs and fail2ban
   - Whitelisted IP in ignoreip

2. **Filter not matching**
   - Regex syntax error
   - Log format changed (nginx update)
   - Multiline log entries (need special handling)

3. **High false positive rate**
   - Threshold too strict (lower maxretry)
   - Detection window too short (increase findtime)
   - Legitimate traffic patterns misidentified

4. **fail2ban not starting**
   - Configuration syntax error
   - Missing log files
   - Permission issues
   - Socket file conflicts

**Debugging Steps:**
1. Check fail2ban process: `docker exec swag ps aux | grep fail2ban`
2. Test filter regex: `./scripts/fail2ban-swag.sh test-filter <name>`
3. Verify iptables rules: `./scripts/fail2ban-swag.sh iptables`
4. Review logs: `./scripts/fail2ban-swag.sh logs --follow`
5. Validate configuration: `docker exec swag fail2ban-client -t`

---

## Reference

**Research Documentation:**
- See `../docs/research/swag-fail2ban-integration/` for detailed setup documentation and research findings

**Official Documentation:**
- [fail2ban Manual](https://fail2ban.readthedocs.io/)
- [LinuxServer.io SWAG Documentation](https://docs.linuxserver.io/images/docker-swag)
- [fail2ban Filters Reference](https://fail2ban.readthedocs.io/en/latest/filters.html)

**Additional References:**
- [references/quick-reference.md](references/quick-reference.md) - Quick command examples for common operations
- [references/filter-examples.md](references/filter-examples.md) - Pre-built filter patterns for common attack types
- [references/troubleshooting.md](references/troubleshooting.md) - Detailed troubleshooting procedures
