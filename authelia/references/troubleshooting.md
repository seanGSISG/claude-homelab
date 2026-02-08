# Authelia Troubleshooting Guide

Common issues and solutions when using the Authelia monitoring skill.

## Table of Contents

- [Connection Issues](#connection-issues)
- [Authentication Errors](#authentication-errors)
- [Session Problems](#session-problems)
- [SSL/TLS Issues](#ssltls-issues)
- [API Errors](#api-errors)
- [Configuration Issues](#configuration-issues)
- [Performance Issues](#performance-issues)

---

## Connection Issues

### Error: "Connection Refused"

**Symptoms:**
```
curl: (7) Failed to connect to auth.example.com port 443: Connection refused
```

**Causes:**
- Authelia is not running
- Wrong URL in `.env`
- Firewall blocking connection
- Network connectivity issues

**Solutions:**

1. **Check if Authelia is running:**
   ```bash
   # If using Docker
   docker ps | grep authelia

   # If using systemd
   systemctl status authelia
   ```

2. **Verify URL is correct:**
   ```bash
   grep AUTHELIA_URL ~/workspace/homelab/.env
   ```

3. **Test connectivity manually:**
   ```bash
   curl -k "https://auth.example.com/api/health"
   ```

4. **Check firewall rules:**
   ```bash
   # Allow HTTPS traffic
   sudo ufw allow 443/tcp
   ```

5. **Verify DNS resolution:**
   ```bash
   ping auth.example.com
   ```

---

### Error: "Could Not Resolve Host"

**Symptoms:**
```
curl: (6) Could not resolve host: auth.example.com
```

**Causes:**
- Hostname doesn't exist
- DNS configuration issues
- `/etc/hosts` missing entry (for local development)

**Solutions:**

1. **Check DNS resolution:**
   ```bash
   nslookup auth.example.com
   ```

2. **Add to `/etc/hosts` (local development):**
   ```bash
   echo "192.168.1.100 auth.example.com" | sudo tee -a /etc/hosts
   ```

3. **Use IP address instead:**
   ```bash
   # In .env
   AUTHELIA_URL="https://192.168.1.100"
   ```

---

### Error: "Operation Timed Out"

**Symptoms:**
```
curl: (28) Operation timed out after 30000 milliseconds
```

**Causes:**
- Network latency
- Authelia server overloaded
- Firewall dropping packets

**Solutions:**

1. **Increase timeout in script:**
   ```bash
   # Edit authelia-api.sh
   # Change: curl -sk ...
   # To: curl -sk --max-time 60 ...
   ```

2. **Check server load:**
   ```bash
   # If you have SSH access to Authelia server
   ssh authelia-server 'top -bn1 | head -20'
   ```

3. **Test network latency:**
   ```bash
   ping -c 5 auth.example.com
   ```

---

## Authentication Errors

### Error: "401 Unauthorized"

**Symptoms:**
```json
{
  "status": "KO",
  "message": "Incorrect username or password."
}
```

**Causes:**
- Invalid credentials in `.env`
- Account locked due to failed attempts
- Password expired
- Session cookie expired

**Solutions:**

1. **Verify credentials:**
   ```bash
   # Check .env file
   cat ~/workspace/homelab/.env | grep AUTHELIA_

   # Test login manually
   curl -sk -X POST "https://auth.example.com/api/firstfactor" \
     -H "Content-Type: application/json" \
     -d '{"username":"admin","password":"pass","keepMeLoggedIn":false}'
   ```

2. **Clear stale cookies:**
   ```bash
   rm -f /tmp/authelia-cookies-$USER.txt
   ```

3. **Check account status:**
   - Review Authelia logs for "locked" messages
   - Wait 5 minutes if rate limited
   - Contact admin if account is disabled

4. **Reset password:**
   - Use Authelia's password reset flow
   - Update `.env` with new password

---

### Error: "Authentication Failed with HTTP 401"

**Symptoms:**
```
ERROR: Authentication failed with HTTP 401
Response: {"status":"KO","message":"Authentication failed."}
```

**Causes:**
- Credentials incorrect
- Session expired
- Account locked

**Solutions:**

1. **Test credentials directly:**
   ```bash
   cd ~/workspace/homelab/skills/authelia
   source ~/workspace/homelab/.env

   curl -sk -X POST "$AUTHELIA_URL/api/firstfactor" \
     -H "Content-Type: application/json" \
     -d "{\"username\":\"$AUTHELIA_USERNAME\",\"password\":\"$AUTHELIA_PASSWORD\",\"keepMeLoggedIn\":false}" \
     | jq .
   ```

2. **Check Authelia logs:**
   ```bash
   # Docker logs
   docker logs authelia --tail 50

   # Systemd logs
   journalctl -u authelia -n 50
   ```

3. **Verify user exists:**
   - Check Authelia configuration for user database
   - Verify user is not disabled

---

### Error: "429 Too Many Requests"

**Symptoms:**
```json
{
  "status": "KO",
  "message": "Too many authentication attempts, please try again later."
}
```

**Causes:**
- Rate limit exceeded
- Multiple failed login attempts
- Brute force protection triggered

**Solutions:**

1. **Wait for rate limit to reset:**
   - First factor: Wait 5 minutes
   - Second factor: Wait 5 minutes
   - Password reset: Wait 1 hour

2. **Check if IP is blocked:**
   ```bash
   # Check Authelia logs
   docker logs authelia | grep "rate limit"
   ```

3. **Clear rate limit (admin only):**
   - Restart Authelia (clears in-memory rate limits)
   - Configure longer rate limit windows in Authelia config

---

## Session Problems

### Error: "Session Invalid or Expired"

**Symptoms:**
```json
{
  "session_valid": false,
  "error": "Session invalid or expired"
}
```

**Causes:**
- Session cookie expired
- Cookie file corrupted
- Session terminated by server
- Clock skew between client/server

**Solutions:**

1. **Clear cookie file:**
   ```bash
   rm -f /tmp/authelia-cookies-$USER.txt
   ./scripts/authelia-api.sh health
   ```

2. **Check system time:**
   ```bash
   # Ensure clocks are synchronized
   timedatectl status
   sudo timedatectl set-ntp true
   ```

3. **Re-authenticate:**
   ```bash
   # Will automatically re-authenticate
   ./scripts/authelia-api.sh user-info
   ```

---

### Error: "User Has Been Inactive Too Long"

**Symptoms:**
```
Error: User john has been inactive for too long
```

**Causes:**
- Session inactivity timeout reached
- User didn't use "Remember Me" option
- Session configuration set to short timeout

**Solutions:**

1. **Re-authenticate:**
   ```bash
   rm -f /tmp/authelia-cookies-$USER.txt
   ./scripts/authelia-api.sh dashboard
   ```

2. **Adjust session timeout (Authelia config):**
   ```yaml
   # In Authelia configuration.yml
   session:
     inactivity: 5m  # Increase this value
   ```

3. **Use Remember Me (manual login):**
   - When logging in via browser, check "Remember Me"
   - Session will last longer

---

## SSL/TLS Issues

### Error: "SSL Certificate Verification Failed"

**Symptoms:**
```
curl: (60) SSL certificate problem: self signed certificate
```

**Causes:**
- Self-signed certificate
- Invalid certificate chain
- Certificate expired

**Solutions:**

1. **Bypass verification (testing only):**
   ```bash
   # Already handled by script with -k flag
   curl -k https://auth.example.com/api/health
   ```

2. **Add certificate to trust store (recommended):**
   ```bash
   # Copy certificate
   sudo cp authelia-cert.crt /usr/local/share/ca-certificates/

   # Update trust store
   sudo update-ca-certificates
   ```

3. **Use IP address:**
   ```bash
   # In .env
   AUTHELIA_URL="https://192.168.1.100"
   ```

---

### Error: "SSL Protocol Error"

**Symptoms:**
```
curl: (35) error:1408F10B:SSL routines:ssl3_get_record:wrong version number
```

**Causes:**
- HTTP URL when HTTPS expected
- Reverse proxy configuration issue
- SSL/TLS version mismatch

**Solutions:**

1. **Verify URL scheme:**
   ```bash
   # Check .env
   grep AUTHELIA_URL ~/workspace/homelab/.env
   # Should be https:// not http://
   ```

2. **Test direct connection:**
   ```bash
   curl -k https://auth.example.com/api/health
   ```

3. **Check Authelia TLS configuration:**
   - Verify `server.tls` section in configuration
   - Ensure certificates are valid

---

## API Errors

### Error: "404 Not Found"

**Symptoms:**
```json
{
  "status": "KO",
  "message": "Resource not found"
}
```

**Causes:**
- Wrong endpoint path
- API version mismatch
- Authelia not fully started

**Solutions:**

1. **Verify endpoint path:**
   ```bash
   # Test health endpoint (always available)
   curl -k https://auth.example.com/api/health
   ```

2. **Check Authelia version:**
   ```bash
   docker logs authelia | grep "version"
   ```

3. **Wait for Authelia to start:**
   ```bash
   # Wait for health endpoint to respond
   until curl -sk https://auth.example.com/api/health | grep -q "UP"; do
     sleep 2
   done
   ```

---

### Error: "500 Internal Server Error"

**Symptoms:**
```json
{
  "status": "KO",
  "message": "Operation failed."
}
```

**Causes:**
- Authelia configuration error
- Database connection failure
- SMTP server unavailable (for elevation codes)
- Backend service failure

**Solutions:**

1. **Check Authelia logs:**
   ```bash
   docker logs authelia --tail 100 | grep ERROR
   ```

2. **Verify database connection:**
   ```bash
   # Check if database is accessible
   docker ps | grep postgres  # or mysql
   ```

3. **Test SMTP (if using elevation):**
   ```bash
   # Check Authelia SMTP configuration
   # Verify email server is accessible
   ```

4. **Restart Authelia:**
   ```bash
   docker restart authelia
   ```

---

### Error: "503 Service Unavailable"

**Symptoms:**
```json
{
  "status": "DOWN"
}
```

**Causes:**
- Authelia starting up
- Database unavailable
- Configuration error
- System overload

**Solutions:**

1. **Wait for startup:**
   ```bash
   # Monitor health until available
   watch -n 2 'curl -sk https://auth.example.com/api/health'
   ```

2. **Check dependencies:**
   ```bash
   # Verify database is running
   docker ps | grep postgres

   # Verify Redis is running (if used)
   docker ps | grep redis
   ```

3. **Review logs:**
   ```bash
   docker logs authelia -f
   ```

---

## Configuration Issues

### Error: "AUTHELIA_URL must be set in .env"

**Symptoms:**
```
ERROR: AUTHELIA_URL must be set in .env
```

**Causes:**
- `.env` file missing
- Variable not set in `.env`
- Typo in variable name

**Solutions:**

1. **Create `.env` file:**
   ```bash
   cat > ~/workspace/homelab/.env <<EOF
   AUTHELIA_URL="https://auth.example.com"
   AUTHELIA_USERNAME="admin"
   AUTHELIA_PASSWORD="secure-password"
   EOF

   chmod 600 ~/workspace/homelab/.env
   ```

2. **Verify variable is set:**
   ```bash
   grep AUTHELIA_URL ~/workspace/homelab/.env
   ```

3. **Check for typos:**
   ```bash
   # Variable names are case-sensitive
   # Must be: AUTHELIA_URL (not authelia_url or Authelia_URL)
   ```

---

### Error: ".env file not found"

**Symptoms:**
```
ERROR: .env file not found at /home/user/workspace/homelab/.env
```

**Causes:**
- Wrong path in script
- File doesn't exist
- File in wrong location

**Solutions:**

1. **Create `.env` at correct location:**
   ```bash
   # Must be at repository root
   touch ~/workspace/homelab/.env
   chmod 600 ~/workspace/homelab/.env
   ```

2. **Verify path:**
   ```bash
   ls -la ~/workspace/homelab/.env
   ```

---

## Performance Issues

### Slow API Responses

**Symptoms:**
- Commands take > 5 seconds
- Timeouts occur frequently

**Causes:**
- Network latency
- Authelia server overloaded
- Database slow
- Large configuration

**Solutions:**

1. **Check server load:**
   ```bash
   # Monitor Authelia container
   docker stats authelia --no-stream
   ```

2. **Check database performance:**
   ```bash
   # If using Docker
   docker stats postgres --no-stream
   ```

3. **Optimize Authelia configuration:**
   - Reduce logging verbosity
   - Enable caching
   - Tune database connection pool

4. **Use local network:**
   ```bash
   # Use local IP instead of domain name
   AUTHELIA_URL="https://192.168.1.100"
   ```

---

### Cookie File Growing Large

**Symptoms:**
- `/tmp/authelia-cookies-$USER.txt` is large
- Multiple cookies stored

**Causes:**
- Multiple authentication attempts
- Cookie not being reused
- Old cookies not cleaned up

**Solutions:**

1. **Clear cookie file:**
   ```bash
   rm -f /tmp/authelia-cookies-$USER.txt
   ```

2. **Review cookie file:**
   ```bash
   cat /tmp/authelia-cookies-$USER.txt
   ```

3. **Ensure cookies are reused:**
   - Script automatically reuses cookies within 1 hour
   - Verify cookie file exists between calls

---

## Debug Mode

### Enable Verbose Logging

**Temporary (one command):**
```bash
# Add -v to curl in script
# Edit authelia-api.sh, find:
curl -sk ...

# Change to:
curl -sk -v ...
```

**View Authelia Logs:**
```bash
# Docker
docker logs authelia -f

# Systemd
journalctl -u authelia -f

# File-based
tail -f /var/log/authelia/authelia.log
```

---

## Getting Help

### Collect Debug Information

When reporting issues, include:

```bash
# 1. Environment info
echo "=== Environment ==="
uname -a
curl --version

# 2. Configuration (sanitized)
echo -e "\n=== Configuration ==="
grep AUTHELIA_URL ~/workspace/homelab/.env
# DO NOT include passwords!

# 3. Test connectivity
echo -e "\n=== Connectivity ==="
curl -k -v https://auth.example.com/api/health

# 4. Recent logs
echo -e "\n=== Authelia Logs ==="
docker logs authelia --tail 50

# 5. Cookie file status
echo -e "\n=== Cookie Status ==="
ls -la /tmp/authelia-cookies-$USER.txt
```

### Common Log Messages

**"User not found in session"**
- Session expired, re-authenticate

**"Invalid credentials"**
- Check username/password in `.env`

**"SMTP error"**
- Email server issue (affects session elevation)

**"Database connection failed"**
- Check database service is running

---

## Prevention

### Best Practices

1. **Regular Health Checks:**
   ```bash
   # Add to cron
   */5 * * * * /path/to/authelia-api.sh health
   ```

2. **Monitor Logs:**
   ```bash
   # Watch for errors
   docker logs authelia -f | grep ERROR
   ```

3. **Keep Credentials Updated:**
   ```bash
   # Update .env when passwords change
   # Verify after update:
   ./scripts/authelia-api.sh health
   ```

4. **Use HTTPS:**
   - Always use `https://` in `AUTHELIA_URL`
   - Never use `http://` in production

5. **Secure Cookie File:**
   ```bash
   # Verify permissions
   ls -la /tmp/authelia-cookies-$USER.txt
   # Should be: -rw------- (600)
   ```

---

## Still Having Issues?

1. **Check Authelia Documentation:**
   - https://www.authelia.com/

2. **Review Recent Changes:**
   - Check git log: `git log --oneline -10`
   - Review Authelia changelog

3. **Test with Minimal Setup:**
   ```bash
   # Test with curl directly
   curl -k https://auth.example.com/api/health
   ```

4. **Ask for Help:**
   - Include debug information (see above)
   - Sanitize all credentials before sharing
   - Describe expected vs actual behavior
