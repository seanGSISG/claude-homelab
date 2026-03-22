# fail2ban Troubleshooting Guide

Detailed troubleshooting procedures for common fail2ban + SWAG integration issues.

---

## Issue: Bans Not Working

### Symptoms
- Filter detects attacks in logs
- No IP addresses getting banned
- iptables rules not being created

### Diagnosis Steps

**1. Verify fail2ban is running:**
```bash
ssh $SWAG_HOST "docker exec $SWAG_CONTAINER_NAME ps aux | grep fail2ban"
```

Expected output:
```
abc      1245  fail2ban-server
```

**2. Check jail status:**
```bash
./scripts/fail2ban-swag.sh jail-status nginx-http-auth
```

Look for:
- `Currently failed: X` (should be > 0 if attacks happening)
- `Total failed: Y` (should increment over time)

**3. Verify iptables chain:**
```bash
./scripts/fail2ban-swag.sh iptables | grep DOCKER-USER
```

Expected output:
```
Chain DOCKER-USER (1 references)
Chain f2b-nginx-http-auth (1 references)
```

**If DOCKER-USER chain is missing:**
- Check container has `NET_ADMIN` capability in docker-compose.yaml
- Restart SWAG container

**4. Check jail configuration:**
```bash
ssh $SWAG_HOST "cat $SWAG_APPDATA_PATH/fail2ban/jail.local | grep -A 10 nginx-http-auth"
```

Verify:
- `enabled = true`
- `chain = DOCKER-USER` (NOT `INPUT`)
- `logpath` is correct

### Solutions

**Wrong iptables chain:**
```bash
# Edit jail.local
ssh $SWAG_HOST

# Add to each jail:
chain = DOCKER-USER

# Reload
./scripts/fail2ban-swag.sh reload
```

**Missing NET_ADMIN capability:**
```bash
# Check docker-compose.yaml
ssh $SWAG_HOST
cat $SWAG_COMPOSE_PATH/docker-compose.yaml | grep -A 5 cap_add

# Should include:
cap_add:
  - NET_ADMIN

# If missing, add and recreate container
cd $SWAG_COMPOSE_PATH
docker compose up -d --force-recreate
```

**fail2ban not starting:**
```bash
# Check container logs
ssh $SWAG_HOST "docker logs swag | grep fail2ban"

# Common errors:
# - "Config file not found" → Check bind mounts
# - "Socket already in use" → Restart container
# - "Permission denied" → Check file permissions
```

---

## Issue: Filter Not Matching Logs

### Symptoms
- Jail enabled and running
- No failures detected (`Currently failed: 0`)
- Log entries clearly show attacks

### Diagnosis Steps

**1. Test filter regex:**
```bash
./scripts/fail2ban-swag.sh test-filter nginx-http-auth
```

Expected output:
```
Lines: 12345 lines, 42 ignored, 156 matched
```

**If `matched: 0`:**
- Regex doesn't match log format
- Log file path incorrect
- Timezone mismatch

**2. View actual log entries:**
```bash
./scripts/fail2ban-swag.sh nginx-access-log | head -20
```

Compare log format with filter regex.

**3. Check log file path:**
```bash
ssh $SWAG_HOST "ls -la $SWAG_APPDATA_PATH/log/nginx/access.log"

# Verify file exists and has recent timestamps
```

### Solutions

**Regex doesn't match:**
```bash
# View sample log entry
./scripts/fail2ban-swag.sh nginx-access-log | head -1

# Example:
# 192.168.1.100 - - [07/Feb/2026:14:23:45 +0000] "GET / HTTP/1.1" 401 ...

# Test regex patterns at regex101.com (Python flavor)
# Adjust filter regex to match format

# Edit filter
ssh $SWAG_HOST
vi $SWAG_APPDATA_PATH/fail2ban/filter.d/custom.local

# Reload
./scripts/fail2ban-swag.sh reload
```

**Timezone mismatch:**
```bash
# Check container timezone
ssh $SWAG_HOST "docker exec $SWAG_CONTAINER_NAME date"

# Check log timestamp
./scripts/fail2ban-swag.sh nginx-access-log | head -1

# If different, set TZ environment variable in docker-compose.yaml:
environment:
  - TZ=America/New_York

# Recreate container
cd $SWAG_COMPOSE_PATH
docker compose up -d --force-recreate
```

**Wrong log path:**
```bash
# Verify path in jail configuration
ssh $SWAG_HOST "cat $SWAG_APPDATA_PATH/fail2ban/jail.local | grep logpath"

# Should be:
logpath = /config/log/nginx/access.log  # Inside container
# NOT: $SWAG_APPDATA_PATH/log/nginx/access.log  # Host path
```

---

## Issue: High False Positive Rate

### Symptoms
- Legitimate users getting banned
- Own IP address banned
- CDN IPs banned (Cloudflare, etc.)

### Diagnosis Steps

**1. Check who's getting banned:**
```bash
./scripts/fail2ban-swag.sh logs | grep "Ban " | tail -20
```

**2. Search for specific IP:**
```bash
./scripts/fail2ban-swag.sh search-ip 192.168.1.100
```

**3. Review filter matches:**
```bash
./scripts/fail2ban-swag.sh test-filter nginx-http-auth
```

### Solutions

**Whitelist legitimate IPs:**
```bash
# Edit jail.local
ssh $SWAG_HOST
vi $SWAG_APPDATA_PATH/fail2ban/jail.local

# Add to [DEFAULT] section:
ignoreip = 10.0.0.0/24 192.168.0.0/24 <your-admin-ip>

# Reload
./scripts/fail2ban-swag.sh reload
```

**CDN/Proxy IPs getting banned:**

**WRONG APPROACH (don't do this):**
```bash
# DO NOT whitelist CDN IPs!
ignoreip = 172.64.0.0/13 # Cloudflare range
```

**CORRECT APPROACH:**
```bash
# Configure nginx realip module
ssh $SWAG_HOST
vi $SWAG_APPDATA_PATH/nginx/nginx.conf

# Add to http block:
set_real_ip_from 172.64.0.0/13;  # Cloudflare
set_real_ip_from 2400:cb00::/32;  # Cloudflare IPv6
real_ip_header CF-Connecting-IP;

# Reload nginx
ssh $SWAG_HOST "docker exec $SWAG_CONTAINER_NAME nginx -s reload"
```

**Threshold too strict:**
```bash
# Edit jail for specific service
ssh $SWAG_HOST
vi $SWAG_APPDATA_PATH/fail2ban/jail.local

# Increase maxretry:
maxretry = 10  # Was: 5

# Increase findtime:
findtime = 300  # Was: 60

# Reload
./scripts/fail2ban-swag.sh reload
```

**Filter too broad:**
```bash
# Example: 404 filter catching legitimate users
# Option 1: Increase maxretry
maxretry = 50  # Allow more 404s

# Option 2: Add ignoreregex for known patterns
ssh $SWAG_HOST
vi $SWAG_APPDATA_PATH/fail2ban/filter.d/nginx-botsearch.conf

# Add:
ignoreregex = favicon\.ico
              robots\.txt
```

---

## Issue: fail2ban Not Starting

### Symptoms
- Container running but fail2ban service not active
- No fail2ban process in container

### Diagnosis Steps

**1. Check container logs:**
```bash
ssh $SWAG_HOST "docker logs swag | grep -i fail2ban"
```

**2. Check fail2ban logs:**
```bash
./scripts/fail2ban-swag.sh logs | tail -50
```

**3. Validate configuration:**
```bash
ssh $SWAG_HOST "docker exec $SWAG_CONTAINER_NAME fail2ban-client -t"
```

### Solutions

**Configuration syntax error:**
```bash
# Test configuration
ssh $SWAG_HOST "docker exec $SWAG_CONTAINER_NAME fail2ban-client -t"

# If errors, fix in jail.local:
ssh $SWAG_HOST
vi $SWAG_APPDATA_PATH/fail2ban/jail.local

# Common errors:
# - Missing closing bracket
# - Typo in parameter name
# - Invalid regex in filter

# Restart container
cd $SWAG_COMPOSE_PATH
docker compose restart
```

**Socket file conflict:**
```bash
# Remove stale socket
ssh $SWAG_HOST "docker exec $SWAG_CONTAINER_NAME rm -f /var/run/fail2ban/fail2ban.sock"

# Restart fail2ban
ssh $SWAG_HOST "docker exec $SWAG_CONTAINER_NAME s6-svc -r /var/run/s6/services/fail2ban"
```

**Missing log files:**
```bash
# Create log files if missing
ssh $SWAG_HOST "docker exec $SWAG_CONTAINER_NAME touch /config/log/nginx/access.log"
ssh $SWAG_HOST "docker exec $SWAG_CONTAINER_NAME touch /config/log/nginx/error.log"

# Restart fail2ban
ssh $SWAG_HOST "docker exec $SWAG_CONTAINER_NAME s6-svc -r /var/run/s6/services/fail2ban"
```

---

## Issue: Bans Expiring Too Soon

### Symptoms
- Same IPs getting banned repeatedly
- Bans only lasting 1 hour (default)
- Repeat offenders not getting longer bans

### Solutions

**Increase ban duration:**
```bash
# Edit jail.local
ssh $SWAG_HOST
vi $SWAG_APPDATA_PATH/fail2ban/jail.local

# Increase bantime:
bantime = 86400  # 24 hours (was: 3600)

# Reload
./scripts/fail2ban-swag.sh reload
```

**Implement recidive jail (repeat offender protection):**
```bash
# Add to jail.local
ssh $SWAG_HOST
vi $SWAG_APPDATA_PATH/fail2ban/jail.local

# Add:
[recidive]
enabled  = true
filter   = recidive
logpath  = /config/log/fail2ban/fail2ban.log
bantime  = 604800  # 7 days
findtime = 86400   # 24 hours
maxretry = 3       # 3 bans within 24h = 7 day ban
chain    = DOCKER-USER

# Reload
./scripts/fail2ban-swag.sh reload
```

**Use incremental banning (fail2ban v0.11+):**
```bash
# Edit jail.local
ssh $SWAG_HOST
vi $SWAG_APPDATA_PATH/fail2ban/jail.local

# Add to [DEFAULT]:
bantime.increment = true
bantime.factor = 2
bantime.maxtime = 604800  # Max 7 days

# This doubles ban time on each repeat offense
```

---

## Issue: Database Corruption

### Symptoms
- `fail2ban-client status` hangs
- Error: "database is locked"
- Bans not persisting across restarts

### Solutions

**Reset database:**
```bash
# Stop fail2ban
ssh $SWAG_HOST "docker exec $SWAG_CONTAINER_NAME fail2ban-client stop"

# Backup old database
ssh $SWAG_HOST "cp $SWAG_APPDATA_PATH/fail2ban/fail2ban.sqlite3 $SWAG_APPDATA_PATH/fail2ban/fail2ban.sqlite3.bak"

# Remove database
ssh $SWAG_HOST "rm $SWAG_APPDATA_PATH/fail2ban/fail2ban.sqlite3"

# Restart container (creates new database)
ssh $SWAG_HOST "cd $SWAG_COMPOSE_PATH && docker compose restart"

# Verify
./scripts/fail2ban-swag.sh status
```

**Prevent future corruption:**
```bash
# Add to jail.local
ssh $SWAG_HOST
vi $SWAG_APPDATA_PATH/fail2ban/jail.local

# Add to [DEFAULT]:
dbpurgeage = 86400  # Purge old bans daily

# Reload
./scripts/fail2ban-swag.sh reload
```

---

## Issue: Performance Degradation

### Symptoms
- fail2ban consuming high CPU
- Log parsing slow
- Container sluggish

### Diagnosis

**1. Check CPU usage:**
```bash
ssh $SWAG_HOST "docker stats swag --no-stream"
```

**2. Check log file sizes:**
```bash
ssh $SWAG_HOST "du -sh $SWAG_APPDATA_PATH/log/nginx/*"
```

**3. Check number of banned IPs:**
```bash
./scripts/fail2ban-swag.sh iptables | wc -l
```

### Solutions

**Rotate logs more frequently:**
```bash
# Edit logrotate config
ssh $SWAG_HOST
vi $SWAG_APPDATA_PATH/logrotate.conf

# Change:
daily  # Was: weekly
rotate 7  # Was: 14

# Force rotation
ssh $SWAG_HOST "docker exec $SWAG_CONTAINER_NAME logrotate -f /etc/logrotate.conf"
```

**Use ipset for large ban lists:**
```bash
# Install ipset in container
ssh $SWAG_HOST "docker exec $SWAG_CONTAINER_NAME apk add ipset"

# Edit jail.local
ssh $SWAG_HOST
vi $SWAG_APPDATA_PATH/fail2ban/jail.local

# Change banaction:
banaction = iptables-ipset-proto6-allports

# Reload
./scripts/fail2ban-swag.sh reload
```

**Optimize filter regex:**
```bash
# Avoid greedy quantifiers: .* → .*?
# Use specific patterns instead of broad matches
# Example:

# BAD (slow):
failregex = ^<HOST>.*$

# GOOD (fast):
failregex = ^<HOST> -.*"(GET|POST) .* HTTP/1\.1" (401|403) .*$
```

---

## Issue: Container Restart Clears Bans

### Symptoms
- All bans cleared on container restart
- Need to re-ban IPs manually

### Solutions

**Enable persistent bans:**
```bash
# Edit jail.local
ssh $SWAG_HOST
vi $SWAG_APPDATA_PATH/fail2ban/jail.local

# Ensure dbfile is configured:
dbfile = /config/fail2ban/fail2ban.sqlite3

# Verify bind mount in docker-compose.yaml:
volumes:
  - ${SWAG_APPDATA_PATH}:/config:rw

# Restart container
cd $SWAG_COMPOSE_PATH
docker compose restart
```

---

## Emergency Procedures

### Someone Locked Themselves Out

```bash
# Quick unban
./scripts/fail2ban-swag.sh unban 192.168.1.100

# If script unavailable, SSH directly:
ssh $SWAG_HOST "docker exec $SWAG_CONTAINER_NAME fail2ban-client unban 192.168.1.100"
```

### fail2ban Completely Broken

```bash
# Stop fail2ban
ssh $SWAG_HOST "docker exec $SWAG_CONTAINER_NAME fail2ban-client stop"

# Access services normally (no banning)
# Fix configuration offline

# Restart fail2ban
ssh $SWAG_HOST "docker exec $SWAG_CONTAINER_NAME fail2ban-client start"
```

### Clear All Bans Immediately

```bash
# Reload fail2ban (flushes bans)
./scripts/fail2ban-swag.sh reload

# Or manually flush iptables:
ssh $SWAG_HOST "docker exec $SWAG_CONTAINER_NAME iptables -F DOCKER-USER"
```

---

## Getting Help

**Collect diagnostic information:**
```bash
# Run all diagnostic commands and save output
{
  echo "=== fail2ban status ==="
  ./scripts/fail2ban-swag.sh status

  echo ""
  echo "=== iptables rules ==="
  ./scripts/fail2ban-swag.sh iptables

  echo ""
  echo "=== Recent logs ==="
  ./scripts/fail2ban-swag.sh logs | tail -50

  echo ""
  echo "=== Container info ==="
  ssh $SWAG_HOST "docker inspect swag | jq '.[0].Config.Env, .[0].HostConfig.CapAdd'"
} > fail2ban-diagnostics.txt

# Share fail2ban-diagnostics.txt when asking for help
```

**Useful resources:**
- [fail2ban Manual](https://fail2ban.readthedocs.io/)
- [LinuxServer.io Discord](https://discord.gg/YWrKVTn)
- [Reddit /r/fail2ban](https://www.reddit.com/r/fail2ban/)
