# fail2ban Filter Examples

Pre-built filter patterns for common attack types. Use these as templates for creating custom jails.

## Understanding Filter Syntax

fail2ban filters use Python regex with special placeholder:
- `<HOST>`: Matches IPv4 or IPv6 address (automatically replaced by fail2ban)
- Standard regex: `.*` (any), `\d+` (digits), `\w+` (word chars), etc.
- Case sensitive by default

**Testing filters:**
```bash
./scripts/fail2ban-swag.sh test-filter <filter-name>
```

---

## HTTP Status Code Filters

### 401 Unauthorized (Already Included)
**Use Case:** Blocks repeated authentication failures

```ini
[Definition]
failregex = ^<HOST>.*"(GET|POST|HEAD).*" (401) .*$
ignoreregex =
```

**Jail Config:**
```bash
./scripts/fail2ban-swag.sh create-jail nginx-unauthorized \
  --filter nginx-unauthorized \
  --logpath "/config/log/nginx/access.log" \
  --maxretry 5 \
  --findtime 60 \
  --bantime 3600
```

---

### 403 Forbidden
**Use Case:** Blocks repeated access to forbidden resources

```ini
[Definition]
failregex = ^<HOST>.*"(GET|POST|HEAD).*" (403) .*$
ignoreregex =
```

**Jail Config:**
```bash
./scripts/fail2ban-swag.sh create-jail nginx-403 \
  --filter nginx-403 \
  --logpath "/config/log/nginx/access.log" \
  --maxretry 10 \
  --findtime 300 \
  --bantime 3600
```

---

### 404 Not Found (Aggressive)
**Use Case:** Blocks scanners probing for vulnerable files

```ini
[Definition]
failregex = ^<HOST>.*"(GET|POST|HEAD).*" (404) .*$
ignoreregex =
```

**Jail Config:**
```bash
./scripts/fail2ban-swag.sh create-jail nginx-404 \
  --filter nginx-404 \
  --logpath "/config/log/nginx/access.log" \
  --maxretry 20 \
  --findtime 600 \
  --bantime 1800
```

**Warning:** Be careful with 404 bans - legitimate users may trigger false positives. Set maxretry high.

---

### 429 Too Many Requests
**Use Case:** Blocks IPs that hit rate limits

```ini
[Definition]
failregex = ^<HOST>.*"(GET|POST|HEAD).*" (429) .*$
ignoreregex =
```

**Jail Config:**
```bash
./scripts/fail2ban-swag.sh create-jail nginx-429 \
  --filter nginx-429 \
  --logpath "/config/log/nginx/access.log" \
  --maxretry 3 \
  --findtime 300 \
  --bantime 3600
```

---

## Attack Pattern Filters

### SQL Injection Attempts
**Use Case:** Blocks URLs containing SQL keywords

```ini
[Definition]
failregex = ^<HOST>.*"(GET|POST).*(union|select|insert|update|delete|drop|create|exec|script|javascript|alert).*" (200|400|404) .*$
ignoreregex =
```

**Jail Config:**
```bash
./scripts/fail2ban-swag.sh create-jail sql-injection \
  --filter sql-injection \
  --logpath "/config/log/nginx/access.log" \
  --maxretry 3 \
  --findtime 600 \
  --bantime 86400
```

---

### Path Traversal
**Use Case:** Blocks attempts to access parent directories

```ini
[Definition]
failregex = ^<HOST>.*"(GET|POST).*(\.\.\/|\.\.\\|%2e%2e%2f|%2e%2e\\).*"
ignoreregex =
```

**Jail Config:**
```bash
./scripts/fail2ban-swag.sh create-jail path-traversal \
  --filter path-traversal \
  --logpath "/config/log/nginx/access.log" \
  --maxretry 2 \
  --findtime 300 \
  --bantime 86400
```

---

### Exploit Attempts (Common Payloads)
**Use Case:** Blocks known exploit patterns

```ini
[Definition]
failregex = ^<HOST>.*"(GET|POST).*(eval\(|base64_decode|system\(|shell_exec|passthru|phpinfo|wget |curl ).*"
ignoreregex =
```

**Jail Config:**
```bash
./scripts/fail2ban-swag.sh create-jail exploit-attempts \
  --filter exploit-attempts \
  --logpath "/config/log/nginx/access.log" \
  --maxretry 1 \
  --findtime 600 \
  --bantime 86400
```

---

### WordPress Exploits
**Use Case:** Blocks WordPress-specific attacks

```ini
[Definition]
failregex = ^<HOST>.*"(GET|POST).*(wp-admin|wp-login|xmlrpc\.php|wp-content/plugins/.*/.*\.php\?|wp-includes/.*\.php\?).*" (200|301|302|404) .*$
ignoreregex =
```

**Jail Config:**
```bash
./scripts/fail2ban-swag.sh create-jail wordpress-exploit \
  --filter wordpress-exploit \
  --logpath "/config/log/nginx/access.log" \
  --maxretry 5 \
  --findtime 300 \
  --bantime 3600
```

**Note:** Only use if you're NOT running WordPress. Otherwise, add exceptions.

---

## Behavioral Filters

### Request Flooding
**Use Case:** Blocks excessive requests from single IP

```ini
[Definition]
failregex = ^<HOST>.*"(GET|POST|HEAD).*" (200|201|204|301|302|304) .*$
ignoreregex =
```

**Jail Config:**
```bash
./scripts/fail2ban-swag.sh create-jail request-flood \
  --filter request-flood \
  --logpath "/config/log/nginx/access.log" \
  --maxretry 100 \
  --findtime 60 \
  --bantime 1800
```

---

### Slow HTTP Attack (Slowloris)
**Use Case:** Detects incomplete requests (requires nginx error log monitoring)

```ini
[Definition]
failregex = ^\[error\].*client.*?<HOST>.*?(request.*?timeout|upstream.*?timed out)
ignoreregex =
```

**Jail Config:**
```bash
./scripts/fail2ban-swag.sh create-jail slowloris \
  --filter slowloris \
  --logpath "/config/log/nginx/error.log" \
  --maxretry 3 \
  --findtime 300 \
  --bantime 3600
```

---

### Large POST Abuse
**Use Case:** Blocks large POST request abuse

```ini
[Definition]
failregex = ^<HOST>.*"POST.*" (413) .*$
ignoreregex =
```

**Jail Config:**
```bash
./scripts/fail2ban-swag.sh create-jail large-post \
  --filter large-post \
  --logpath "/config/log/nginx/access.log" \
  --maxretry 5 \
  --findtime 300 \
  --bantime 3600
```

---

## Application-Specific Filters

### API Abuse (Excessive Failures)
**Use Case:** Blocks failed API calls (assuming /api/* endpoints)

```ini
[Definition]
failregex = ^<HOST>.*"(GET|POST|PUT|DELETE) /api/.*" (400|401|403|404|422|429|500) .*$
ignoreregex =
```

**Jail Config:**
```bash
./scripts/fail2ban-swag.sh create-jail api-abuse \
  --filter api-abuse \
  --logpath "/config/log/nginx/access.log" \
  --maxretry 20 \
  --findtime 300 \
  --bantime 3600
```

---

### Authelia Brute Force
**Use Case:** Protects Authelia SSO authentication

```ini
[Definition]
failregex = ^<HOST>.*"POST /api/firstfactor.*" (401|403) .*$
ignoreregex =
```

**Jail Config:**
```bash
./scripts/fail2ban-swag.sh create-jail authelia-brute \
  --filter authelia-brute \
  --logpath "/config/log/nginx/access.log" \
  --maxretry 5 \
  --findtime 300 \
  --bantime 7200
```

---

### GitLab/GitHub Webhooks Abuse
**Use Case:** Blocks unauthorized webhook attempts

```ini
[Definition]
failregex = ^<HOST>.*"POST /webhooks/.*" (401|403) .*$
ignoreregex =
```

**Jail Config:**
```bash
./scripts/fail2ban-swag.sh create-jail webhook-abuse \
  --filter webhook-abuse \
  --logpath "/config/log/nginx/access.log" \
  --maxretry 3 \
  --findtime 600 \
  --bantime 3600
```

---

## Advanced Patterns

### User-Agent Spoofing
**Use Case:** Blocks suspicious User-Agent strings

```ini
[Definition]
failregex = ^<HOST>.*"(curl|wget|python-requests|Go-http-client|Java).*"$
ignoreregex =
```

**Jail Config:**
```bash
./scripts/fail2ban-swag.sh create-jail user-agent-spoof \
  --filter user-agent-spoof \
  --logpath "/config/log/nginx/access.log" \
  --maxretry 10 \
  --findtime 60 \
  --bantime 3600
```

**Warning:** May block legitimate API clients. Use with caution.

---

### Empty or Missing User-Agent
**Use Case:** Blocks requests without User-Agent header

```ini
[Definition]
failregex = ^<HOST>.*"(GET|POST|HEAD).*" (200|301|302|400|404) .*"-" "-"$
ignoreregex =
```

**Jail Config:**
```bash
./scripts/fail2ban-swag.sh create-jail no-user-agent \
  --filter no-user-agent \
  --logpath "/config/log/nginx/access.log" \
  --maxretry 10 \
  --findtime 60 \
  --bantime 1800
```

---

### HTTP Method Abuse (Uncommon Methods)
**Use Case:** Blocks unusual HTTP methods (TRACE, OPTIONS abuse)

```ini
[Definition]
failregex = ^<HOST>.*"(TRACE|TRACK|CONNECT|OPTIONS) .*"
ignoreregex =
```

**Jail Config:**
```bash
./scripts/fail2ban-swag.sh create-jail http-method-abuse \
  --filter http-method-abuse \
  --logpath "/config/log/nginx/access.log" \
  --maxretry 3 \
  --findtime 300 \
  --bantime 3600
```

---

## Combining Filters

### Multi-Stage Attack Detection
**Use Case:** Requires multiple different attack patterns before ban

Create multiple filters and combine in jail:

```ini
[multi-stage-attack]
enabled  = true
filter   = sql-injection
           path-traversal
           exploit-attempts
port     = http,https
logpath  = /config/log/nginx/access.log
maxretry = 1  # Ban after ANY match
findtime = 3600
bantime  = 86400
chain    = DOCKER-USER
```

---

## Testing Your Filters

**Always test filters before deploying:**

```bash
# Create filter
./scripts/fail2ban-swag.sh create-filter my-custom-filter \
  --regex '^<HOST>.*pattern.*$'

# Test against actual logs
./scripts/fail2ban-swag.sh test-filter my-custom-filter

# Look for lines like:
# "Lines: 12345 matches: 42"
# If matches: 0, your regex needs adjustment
```

**Debugging regex:**
1. View actual log entries: `./scripts/fail2ban-swag.sh nginx-access-log | head -20`
2. Identify the pattern you want to match
3. Test regex online: https://regex101.com/ (use Python flavor)
4. Remember `<HOST>` placeholder for IP address
5. Test in fail2ban-regex before deploying

---

## Best Practices

1. **Start lenient, then tighten**
   - Begin with high maxretry (10-20)
   - Monitor for false positives
   - Gradually reduce threshold

2. **Use appropriate findtime**
   - Brute force attacks: 60-300 seconds
   - Slow attacks: 600-3600 seconds
   - Application abuse: 300-600 seconds

3. **Set reasonable bantime**
   - First offense: 1-3 hours
   - Repeat offenders: 24 hours
   - Severe attacks: 7 days or permanent

4. **Whitelist important IPs**
   - Add to `ignoreip` in jail.local
   - Include monitoring systems, CI/CD, trusted admins

5. **Monitor for false positives**
   - Review logs daily: `./scripts/fail2ban-swag.sh logs | grep Ban`
   - Check banned IPs against legitimate users
   - Adjust filters if needed

6. **Use DOCKER-USER chain**
   - Always set `chain = DOCKER-USER` for containerized apps
   - INPUT chain will NOT work
