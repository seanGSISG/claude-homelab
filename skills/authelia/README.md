# Authelia Authentication Monitoring Skill

Monitor authentication security and user sessions via the Authelia REST API.

## What It Does

This skill lets you monitor and interact with your Authelia authentication system:

- ✅ Check system health and configuration
- ✅ Monitor user session status and authentication level
- ✅ View user information and 2FA preferences
- ✅ Track authentication state and session validity
- ✅ Get comprehensive security dashboard
- ⚠️ Update user 2FA preferences (limited write)
- ⚠️ Manage session elevation (security operations)
- ❌ Password changes (too risky for automation)
- ❌ User creation/deletion (requires admin API)

**Type:** Read-Only + Limited Write (user preferences only)
**Safety:** High - respects Authelia's security model, no authentication bypass

## Setup

### 1. Ensure Authelia is Running

This skill works with any Authelia instance (v4.38+):

```bash
# Check if Authelia is accessible
curl -k https://auth.example.com/api/health
# Should return: {"status":"UP"}
```

### 2. Add Credentials to .env

Edit `~/claude-homelab/.env` and add:

```bash
AUTHELIA_URL="https://auth.example.com"
AUTHELIA_USERNAME="admin"
AUTHELIA_PASSWORD="your-admin-password"
AUTHELIA_API_TOKEN=""  # Optional: leave empty for cookie auth
```

**Authentication Options:**

**Option 1: Cookie-Based (Recommended for Interactive)**
- Set `AUTHELIA_USERNAME` and `AUTHELIA_PASSWORD`
- Script will authenticate via `/api/firstfactor` and store cookie
- Cookie auto-renews when expired

**Option 2: Bearer Token (Recommended for Automation)**
- Generate API token in Authelia (if supported by your version)
- Set `AUTHELIA_API_TOKEN` in `.env`
- Skip username/password requirement

**Security:**
- `.env` file is gitignored (NEVER commit)
- Set permissions: `chmod 600 ~/claude-homelab/.env`
- Cookie file stored at `/tmp/authelia-cookies-$USER.txt` (0600 permissions)
- Cookies automatically cleaned up on script exit

### 3. Test Connection

```bash
cd ~/workspace/homelab/skills/authelia
./scripts/authelia-api.sh health
```

Expected output:
```json
{
  "status": "UP"
}
```

## Usage Examples

### Quick Health Check

Check if Authelia is healthy:

```bash
./scripts/authelia-api.sh health
```

### Get Authentication State

Check current authentication state and level:

```bash
./scripts/authelia-api.sh state
```

Sample output:
```json
{
  "username": "john",
  "authentication_level": 2,
  "default_redirection_url": "https://app.example.com"
}
```

**Authentication Levels:**
- `0`: Not authenticated
- `1`: First factor only (username/password)
- `2`: Two-factor authentication complete

### View User Information

Get details about the authenticated user:

```bash
./scripts/authelia-api.sh user-info
```

Sample output:
```json
{
  "display_name": "John Doe",
  "method": "totp",
  "has_totp": true,
  "has_webauthn": false,
  "has_duo": false
}
```

### Check 2FA Configuration

View user's second factor authentication setup:

```bash
./scripts/authelia-api.sh user-2fa
```

### Get System Configuration

View available authentication methods and configuration:

```bash
./scripts/authelia-api.sh config
```

### Complete Security Dashboard

Get a comprehensive overview of all security metrics:

```bash
./scripts/authelia-api.sh dashboard
```

This combines:
- System health status
- Authentication state
- User information
- 2FA configuration
- Available methods

## Workflow

### Daily Security Monitoring

```bash
# Morning security check
./scripts/authelia-api.sh dashboard

# Check if any issues
./scripts/authelia-api.sh health

# Verify user sessions
./scripts/authelia-api.sh state
```

### User Support Flow

When a user reports authentication issues:

```bash
# 1. Check system health
./scripts/authelia-api.sh health

# 2. Check their authentication state
./scripts/authelia-api.sh state

# 3. View their user info and 2FA setup
./scripts/authelia-api.sh user-info
./scripts/authelia-api.sh user-2fa

# 4. Check session validity
./scripts/authelia-api.sh session-status
```

### Integration with Monitoring

Integrate with homelab monitoring scripts:

```bash
# Add to cron for periodic health checks
0 * * * * /home/user/workspace/homelab/skills/authelia/scripts/authelia-api.sh health | jq -r '.status'
```

## Troubleshooting

### "401 Unauthorized" Error

**Problem:** API returns 401 status code

**Solutions:**
1. Check credentials in `.env` file
2. Verify `AUTHELIA_URL` is correct
3. Test manual login: `curl -X POST https://auth.example.com/api/firstfactor -d '{"username":"admin","password":"pass"}'`
4. Check if user has necessary permissions

### "Connection Refused" Error

**Problem:** Cannot connect to Authelia server

**Solutions:**
1. Verify Authelia is running: `docker ps | grep authelia`
2. Check `AUTHELIA_URL` is accessible: `curl -k $AUTHELIA_URL/api/health`
3. Check firewall rules allow connection
4. Verify DNS resolution if using hostname

### "Invalid Session" Error

**Problem:** Session cookie expired or invalid

**Solutions:**
1. Delete cookie file: `rm /tmp/authelia-cookies-$USER.txt`
2. Re-run command (script will re-authenticate automatically)
3. Check system clock is synchronized (NTP)

### SSL Certificate Errors

**Problem:** SSL verification fails with self-signed certificates

**Solutions:**
1. Use `-k` flag for curl (insecure mode) - already handled in script
2. Add certificate to system trust store (recommended for production)
3. Use `AUTHELIA_URL` with IP instead of hostname

## Advanced Usage

### JSON Filtering with jq

Get specific fields from responses:

```bash
# Get just the username
./scripts/authelia-api.sh state | jq -r '.username'

# Check if user has TOTP enabled
./scripts/authelia-api.sh user-info | jq -r '.has_totp'

# Get authentication level
./scripts/authelia-api.sh state | jq -r '.authentication_level'
```

### Integration with Gotify

Send alerts when health check fails:

```bash
#!/bin/bash
HEALTH=$(./scripts/authelia-api.sh health | jq -r '.status')
if [[ "$HEALTH" != "UP" ]]; then
    # Use Gotify skill to send alert
    cd ../gotify
    ./scripts/push.sh "Authelia Health Alert" "Authelia status: $HEALTH" 8
fi
```

### Dashboard Monitoring Script

Create a monitoring script:

```bash
#!/bin/bash
# authelia-monitor.sh - Continuous monitoring

while true; do
    clear
    echo "=== Authelia Security Dashboard ==="
    echo "Generated: $(date)"
    echo
    ./scripts/authelia-api.sh dashboard | jq .
    sleep 300  # Update every 5 minutes
done
```

## Security Notes

### What This Skill CAN Do

✅ Monitor authentication status (read-only)
✅ Check system health (read-only)
✅ View user session information (read-only)
✅ Check 2FA status (read-only)
✅ Update user 2FA preferences (limited write)
✅ Manage session elevation (security operations)

### What This Skill CANNOT Do

❌ Change passwords (requires elevated privileges + too risky)
❌ Create/delete users (requires admin API access)
❌ Modify access control rules (config file changes)
❌ Bypass authentication (security violation)
❌ View other users' sessions (privacy protection)
❌ Direct authentication logs (use Authelia's logging system)

### Best Practices

1. **Credential Security:**
   - Never commit `.env` file
   - Use strong passwords for `AUTHELIA_PASSWORD`
   - Rotate credentials regularly
   - Use bearer tokens instead of passwords when possible

2. **API Usage:**
   - Monitor for unusual authentication patterns
   - Check health regularly (automated monitoring)
   - Review 2FA adoption rates
   - Track authentication levels

3. **Session Management:**
   - Cookie files are temporary and user-specific
   - Cookies auto-expire based on Authelia config
   - Script handles re-authentication automatically
   - Don't share cookie files between users

4. **Operational Security:**
   - Run skill from secure systems only
   - Use HTTPS for `AUTHELIA_URL` (never HTTP)
   - Verify SSL certificates in production
   - Limit API access to monitoring accounts

## Notes

- All operations require authentication (cookie or token)
- Some endpoints may require session elevation (email verification)
- API responses follow Authelia's standard JSON format
- Error messages include HTTP status codes for debugging
- Cookie-based auth creates temporary file at `/tmp/authelia-cookies-$USER.txt`
- Script automatically cleans up cookies on exit

## Reference

- [API Endpoints](references/api-endpoints.md) - Complete API documentation
- [Quick Reference](references/quick-reference.md) - Copy-paste command examples
- [Troubleshooting](references/troubleshooting.md) - Common issues and solutions
- [Authelia Documentation](https://www.authelia.com) - Official docs
