# fail2ban + SWAG Quick Reference

Quick command examples for common operations.

## Daily Operations

### Check Overall Status
```bash
./scripts/fail2ban-swag.sh status
```

### View All Banned IPs
```bash
# List all jails
./scripts/fail2ban-swag.sh list-jails

# Check each jail for banned IPs
./scripts/fail2ban-swag.sh banned-ips nginx-http-auth
./scripts/fail2ban-swag.sh banned-ips nginx-unauthorized
./scripts/fail2ban-swag.sh banned-ips nginx-badbots
```

### Unban Someone Who Got Locked Out
```bash
# Unban from all jails
./scripts/fail2ban-swag.sh unban 192.168.1.100

# Unban from specific jail
./scripts/fail2ban-swag.sh unban 192.168.1.100 nginx-http-auth
```

### Monitor Activity Live
```bash
# Watch fail2ban log
./scripts/fail2ban-swag.sh logs --follow

# Watch nginx access log
./scripts/fail2ban-swag.sh nginx-access-log --follow

# Watch nginx error log
./scripts/fail2ban-swag.sh nginx-error-log --follow
```

## Troubleshooting

### Investigate Specific IP
```bash
# Search all logs for an IP
./scripts/fail2ban-swag.sh search-ip 192.168.1.100
```

### Check if Bans Are Working
```bash
# View iptables rules (should see f2b chains)
./scripts/fail2ban-swag.sh iptables

# Check jail status
./scripts/fail2ban-swag.sh jail-status nginx-unauthorized
```

### Test Filter Regex
```bash
# Test if filter matches log entries
./scripts/fail2ban-swag.sh test-filter nginx-http-auth
```

## Creating Custom Protection

### Example 1: Block Repeated 403 Forbidden
```bash
# Create filter
./scripts/fail2ban-swag.sh create-filter custom-403 \
  --regex '^<HOST>.*"(GET|POST).*" (403) .*$'

# Test filter
./scripts/fail2ban-swag.sh test-filter custom-403

# Create jail
./scripts/fail2ban-swag.sh create-jail custom-403 \
  --filter custom-403 \
  --logpath "/config/log/nginx/access.log" \
  --maxretry 10 \
  --findtime 300 \
  --bantime 3600

# Reload fail2ban
./scripts/fail2ban-swag.sh reload

# Verify jail is active
./scripts/fail2ban-swag.sh jail-status custom-403
```

### Example 2: Block SQL Injection Attempts
```bash
# Create filter for SQL keywords in URLs
./scripts/fail2ban-swag.sh create-filter sql-injection \
  --regex '^<HOST>.*"(GET|POST).*(union|select|insert|update|delete|drop|create).*" (200|400|404) .*$'

# Create jail with strict policy
./scripts/fail2ban-swag.sh create-jail sql-injection \
  --filter sql-injection \
  --logpath "/config/log/nginx/access.log" \
  --maxretry 3 \
  --findtime 600 \
  --bantime 86400

# Reload and verify
./scripts/fail2ban-swag.sh reload
./scripts/fail2ban-swag.sh jail-status sql-injection
```

### Example 3: Rate Limit Aggressive Crawlers
```bash
# Create filter for excessive requests
./scripts/fail2ban-swag.sh create-filter aggressive-crawler \
  --regex '^<HOST>.*"(GET|POST).*" (200|301|302) .*$'

# Create jail with high threshold
./scripts/fail2ban-swag.sh create-jail aggressive-crawler \
  --filter aggressive-crawler \
  --logpath "/config/log/nginx/access.log" \
  --maxretry 100 \
  --findtime 60 \
  --bantime 1800

# Reload
./scripts/fail2ban-swag.sh reload
```

## Maintenance

### Backup Configuration
```bash
./scripts/fail2ban-swag.sh backup
# Creates: fail2ban-backup-2026-02-07.tar.gz
```

### Restore Configuration
```bash
./scripts/fail2ban-swag.sh restore fail2ban-backup-2026-02-07.tar.gz
./scripts/fail2ban-swag.sh reload
```

### Reload After Config Changes
```bash
# Always reload after editing jail.local or filters
./scripts/fail2ban-swag.sh reload
```

## Emergency Procedures

### Container Restart Required
```bash
# SSH to SWAG host
ssh $SWAG_HOST

# Restart SWAG container
cd $SWAG_COMPOSE_PATH
docker compose restart

# Verify fail2ban started
docker exec $SWAG_CONTAINER_NAME ps aux | grep fail2ban
```

### Manual Unban via iptables
```bash
# SSH to SWAG host
ssh $SWAG_HOST

# View iptables rules
docker exec $SWAG_CONTAINER_NAME iptables -L DOCKER-USER -n --line-numbers

# Delete specific rule (by line number)
docker exec $SWAG_CONTAINER_NAME iptables -D DOCKER-USER <line-number>
```

### Reset All Bans
```bash
# SSH to SWAG host
ssh $SWAG_HOST

# Flush fail2ban chains
docker exec $SWAG_CONTAINER_NAME iptables -F f2b-nginx-http-auth
docker exec $SWAG_CONTAINER_NAME iptables -F f2b-nginx-badbots
docker exec $SWAG_CONTAINER_NAME iptables -F f2b-nginx-botsearch
docker exec $SWAG_CONTAINER_NAME iptables -F f2b-nginx-deny
docker exec $SWAG_CONTAINER_NAME iptables -F f2b-nginx-unauthorized

# Or reload fail2ban
docker exec $SWAG_CONTAINER_NAME fail2ban-client reload
```

## Monitoring Patterns

### Daily Check
```bash
# Quick status check (add to cron)
./scripts/fail2ban-swag.sh status
./scripts/fail2ban-swag.sh logs | tail -20
```

### Weekly Review
```bash
# Review ban counts
for jail in nginx-http-auth nginx-badbots nginx-botsearch nginx-deny nginx-unauthorized; do
    echo "=== $jail ==="
    ./scripts/fail2ban-swag.sh jail-status "$jail"
done

# Review recent bans in logs
./scripts/fail2ban-swag.sh logs | grep "Ban " | tail -50
```

### Incident Response
```bash
# Attacker IP: 203.0.113.42

# 1. Check current status
./scripts/fail2ban-swag.sh search-ip 203.0.113.42

# 2. Check which jails detected it
./scripts/fail2ban-swag.sh logs | grep 203.0.113.42

# 3. Manual ban if needed
./scripts/fail2ban-swag.sh ban 203.0.113.42 nginx-unauthorized

# 4. Verify ban
./scripts/fail2ban-swag.sh iptables | grep 203.0.113.42
```
