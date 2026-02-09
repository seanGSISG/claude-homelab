# Authelia Quick Reference

Copy-paste ready commands for common Authelia monitoring tasks.

## Table of Contents

- [Health Checks](#health-checks)
- [Authentication Status](#authentication-status)
- [User Information](#user-information)
- [Session Management](#session-management)
- [Dashboard Views](#dashboard-views)
- [JSON Filtering](#json-filtering)
- [Integration Examples](#integration-examples)

---

## Health Checks

### Basic Health Check
```bash
./scripts/authelia-api.sh health
```

### Health Check with Status Code
```bash
./scripts/authelia-api.sh health | jq -r '.status'
```

### Continuous Health Monitoring
```bash
watch -n 30 './scripts/authelia-api.sh health | jq -r .status'
```

---

## Authentication Status

### Get Current Authentication State
```bash
./scripts/authelia-api.sh state
```

### Check Authentication Level
```bash
./scripts/authelia-api.sh state | jq -r '.authentication_level'
```

**Authentication Levels:**
- `0` = Not authenticated
- `1` = First factor only (password)
- `2` = Two-factor complete

### Get Username if Authenticated
```bash
./scripts/authelia-api.sh state | jq -r '.username // "Not authenticated"'
```

### Check Default Redirection URL
```bash
./scripts/authelia-api.sh state | jq -r '.default_redirection_url'
```

---

## User Information

### Get Full User Information
```bash
./scripts/authelia-api.sh user-info
```

### Get User Display Name
```bash
./scripts/authelia-api.sh user-info | jq -r '.display_name'
```

### Check Preferred 2FA Method
```bash
./scripts/authelia-api.sh user-info | jq -r '.method'
```

### Check if TOTP is Configured
```bash
./scripts/authelia-api.sh user-info | jq -r '.has_totp'
```

### Check if WebAuthn is Configured
```bash
./scripts/authelia-api.sh user-info | jq -r '.has_webauthn'
```

### List All Configured 2FA Methods
```bash
./scripts/authelia-api.sh user-info | jq -r 'to_entries | map(select(.key | startswith("has_"))) | map(.key + ": " + (.value|tostring)) | .[]'
```

---

## Session Management

### Check Session Validity
```bash
./scripts/authelia-api.sh session-status
```

### Check if Session is Valid (Boolean)
```bash
./scripts/authelia-api.sh session-status | jq -r '.session_valid'
```

### Check Session Elevation Status
```bash
./scripts/authelia-api.sh elevation
```

### Check if Session is Elevated
```bash
./scripts/authelia-api.sh elevation | jq -r '.elevated // false'
```

---

## Dashboard Views

### Complete Security Dashboard
```bash
./scripts/authelia-api.sh dashboard
```

### Dashboard with Pretty Printing
```bash
./scripts/authelia-api.sh dashboard | jq .
```

### Dashboard - Health Only
```bash
./scripts/authelia-api.sh dashboard | jq '.health'
```

### Dashboard - State Only
```bash
./scripts/authelia-api.sh dashboard | jq '.state'
```

### Dashboard - User Info Only
```bash
./scripts/authelia-api.sh dashboard | jq '.user_info'
```

### Dashboard - Configuration Only
```bash
./scripts/authelia-api.sh dashboard | jq '.configuration'
```

---

## JSON Filtering

### Get Specific Fields from State
```bash
# Username
./scripts/authelia-api.sh state | jq -r '.username'

# Auth level
./scripts/authelia-api.sh state | jq -r '.authentication_level'

# Redirect URL
./scripts/authelia-api.sh state | jq -r '.default_redirection_url'
```

### Get Specific Fields from User Info
```bash
# Display name
./scripts/authelia-api.sh user-info | jq -r '.display_name'

# 2FA method
./scripts/authelia-api.sh user-info | jq -r '.method'

# All 2FA methods
./scripts/authelia-api.sh user-info | jq '{totp: .has_totp, webauthn: .has_webauthn, duo: .has_duo}'
```

### Check Multiple Conditions
```bash
# Is user authenticated with 2FA?
./scripts/authelia-api.sh state | jq 'if .authentication_level == 2 then "2FA Complete" else "2FA Incomplete" end'

# Does user have any 2FA configured?
./scripts/authelia-api.sh user-info | jq 'if (.has_totp or .has_webauthn or .has_duo) then "2FA Configured" else "No 2FA" end'
```

---

## Integration Examples

### Monitoring Script
```bash
#!/bin/bash
# authelia-monitor.sh - Monitor Authelia health

while true; do
    STATUS=$(./scripts/authelia-api.sh health | jq -r '.status')
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

    if [[ "$STATUS" == "UP" ]]; then
        echo "[$TIMESTAMP] Authelia is healthy"
    else
        echo "[$TIMESTAMP] ⚠️  Authelia health check failed: $STATUS"
        # Trigger alert here
    fi

    sleep 60
done
```

### User Session Report
```bash
#!/bin/bash
# session-report.sh - Generate user session report

echo "=== Authelia Session Report ==="
echo "Generated: $(date)"
echo

# Get state
STATE=$(./scripts/authelia-api.sh state)
USERNAME=$(echo "$STATE" | jq -r '.username // "Not authenticated"')
AUTH_LEVEL=$(echo "$STATE" | jq -r '.authentication_level')

echo "Username: $USERNAME"
echo "Auth Level: $AUTH_LEVEL"

if [[ "$AUTH_LEVEL" == "2" ]]; then
    echo "Status: ✅ Fully authenticated"

    # Get user info
    USER_INFO=$(./scripts/authelia-api.sh user-info)
    echo "Display Name: $(echo "$USER_INFO" | jq -r '.display_name')"
    echo "2FA Method: $(echo "$USER_INFO" | jq -r '.method')"
    echo "TOTP: $(echo "$USER_INFO" | jq -r '.has_totp')"
    echo "WebAuthn: $(echo "$USER_INFO" | jq -r '.has_webauthn')"
else
    echo "Status: ⚠️  Not fully authenticated"
fi
```

### Gotify Integration
```bash
#!/bin/bash
# authelia-alert.sh - Send Gotify alert on health failure

HEALTH=$(./scripts/authelia-api.sh health | jq -r '.status')

if [[ "$HEALTH" != "UP" ]]; then
    # Use Gotify skill to send alert
    cd ../gotify
    ./scripts/push.sh "Authelia Alert" "Health status: $HEALTH" 8
fi
```

### Cron Integration
```bash
# Add to crontab: crontab -e

# Check health every 5 minutes
*/5 * * * * cd ~/claude-homelab/skills/authelia && ./scripts/authelia-api.sh health >> /tmp/authelia-health.log 2>&1

# Daily session report at 9 AM
0 9 * * * cd ~/claude-homelab/skills/authelia && ./scripts/authelia-api.sh dashboard > /tmp/authelia-report-$(date +\%Y\%m\%d).json

# Alert on health failure (every 5 minutes)
*/5 * * * * cd ~/claude-homelab/skills/authelia && [[ $(./scripts/authelia-api.sh health | jq -r .status) != "UP" ]] && /usr/local/bin/send-alert "Authelia down"
```

---

## Troubleshooting Quick Fixes

### Clear Stale Cookies
```bash
rm -f /tmp/authelia-cookies-$USER.txt
./scripts/authelia-api.sh health
```

### Test Authentication
```bash
# Will trigger re-authentication if cookie is stale
./scripts/authelia-api.sh user-info
```

### Verify Connection
```bash
# Check if Authelia is accessible
curl -k "$(grep AUTHELIA_URL ~/claude-homelab/.env | cut -d= -f2 | tr -d '"')/api/health"
```

### Debug Mode
```bash
# Add -v to curl in script for verbose output
# Edit authelia-api.sh temporarily:
# Change: curl -sk ...
# To: curl -sk -v ...
```

---

## Common Workflows

### Morning Security Check
```bash
cd ~/claude-homelab/skills/authelia

# 1. Check health
echo "=== Health Status ==="
./scripts/authelia-api.sh health | jq .

# 2. Get dashboard
echo -e "\n=== Full Dashboard ==="
./scripts/authelia-api.sh dashboard | jq .

# 3. Check session
echo -e "\n=== Session Status ==="
./scripts/authelia-api.sh session-status | jq .
```

### User Support Flow
```bash
# User reports: "I can't log in"

# 1. Check system health
./scripts/authelia-api.sh health

# 2. Get authentication state
./scripts/authelia-api.sh state

# 3. Check user's 2FA setup
./scripts/authelia-api.sh user-info

# 4. Verify session
./scripts/authelia-api.sh session-status
```

### 2FA Audit
```bash
# Check 2FA adoption

USER_INFO=$(./scripts/authelia-api.sh user-info)

echo "2FA Methods Configured:"
echo "- TOTP: $(echo "$USER_INFO" | jq -r '.has_totp')"
echo "- WebAuthn: $(echo "$USER_INFO" | jq -r '.has_webauthn')"
echo "- Duo: $(echo "$USER_INFO" | jq -r '.has_duo')"
echo
echo "Preferred Method: $(echo "$USER_INFO" | jq -r '.method')"
```

---

## Performance Tips

### Cache Dashboard Results
```bash
# Cache dashboard for 5 minutes
CACHE_FILE="/tmp/authelia-dashboard-cache.json"
CACHE_AGE=$(($(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)))

if [[ $CACHE_AGE -gt 300 ]]; then
    ./scripts/authelia-api.sh dashboard > "$CACHE_FILE"
fi

cat "$CACHE_FILE"
```

### Parallel Checks
```bash
# Run multiple checks in parallel
{
    ./scripts/authelia-api.sh health &
    ./scripts/authelia-api.sh state &
    ./scripts/authelia-api.sh user-info &
    wait
} | jq -s '.'
```

---

## Environment Variables

### Quick Environment Setup
```bash
# Test different Authelia instances
export AUTHELIA_URL="https://auth.example.com"
export AUTHELIA_USERNAME="admin"
export AUTHELIA_PASSWORD="secure-pass"

./scripts/authelia-api.sh health
```

### Multi-Instance Monitoring
```bash
# Monitor multiple Authelia servers
for URL in "https://auth1.example.com" "https://auth2.example.com"; do
    export AUTHELIA_URL="$URL"
    echo "Checking $URL..."
    ./scripts/authelia-api.sh health | jq -r ".status"
done
```

---

## Notes

- All commands assume you're in the `~/claude-homelab/skills/authelia/` directory
- Cookie file is stored at `/tmp/authelia-cookies-$USER.txt`
- Cookies auto-renew when expired (seamless re-authentication)
- Use `jq -r` for raw output (no quotes)
- Use `jq .` for pretty-printed JSON
- All timestamps in JSON are UTC (ISO 8601 format)
