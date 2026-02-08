# NotebookLM Research Findings: SWAG + fail2ban Integration

## Research Summary

- **Notebook ID**: 6fdf5272-bdd4-44eb-b71f-67383d703c12
- **Deep Research Mode**: Deep (15-30+ minutes)
- **Sources Added**: 107 total (44 manual + 63 from deep research)
- **Q&A Questions Asked**: 20 comprehensive questions with citations
- **Deep Research Status**: Completed successfully
- **Research Duration**: ~4 minutes for deep research completion

## Deep Research Results

The deep research discovered 64 high-quality sources focused on SWAG reverse proxy and fail2ban integration, with 56 successfully imported.

### Key Sources Discovered:
- Securing SWAG - LinuxServer.io official blog
- SWAG fail2ban configuration GitHub Gist
- LinuxServer fail2ban configurations repository
- Unraid forums SWAG support threads
- LinuxServer.io discourse troubleshooting discussions
- nginx security documentation
- fail2ban architecture references

### Key Themes Identified:
1. Docker networking challenges (DOCKER-USER chain critical)
2. Log parsing and filter creation patterns
3. Security hardening best practices
4. Performance optimization for high-traffic sites
5. Container vs host deployment strategies

## Executive Summary

This comprehensive research covers SWAG (Secure Web Application Gateway) integration with fail2ban for reverse proxy security. Key findings:

**Critical Success Factors:**
- **DOCKER-USER chain** is mandatory for protecting containerized applications (using INPUT chain will fail)
- **NET_ADMIN capability** required for fail2ban to modify iptables from within containers
- **Real IP restoration** essential when behind CDNs/proxies (Cloudflare, load balancers)
- **ipset** recommended for high-performance banning with large IP lists (O(1) vs O(n) lookup)

**Common Pitfalls:**
- Wrong iptables chain (using INPUT instead of DOCKER-USER for containers)
- Timezone mismatches between logs and fail2ban
- Whitelisting proxy IPs instead of configuring real IP restoration
- Not testing regex patterns before deployment

**Best Practices:**
- Start with short ban times and lenient thresholds during testing
- Use incremental banning or recidive jail for repeat offenders
- Implement multi-layer defense (nginx rate limiting + fail2ban)
- Monitor false positive rates and adjust filters accordingly
- Always whitelist management networks in ignoreip

## Detailed Q&A Findings

### 1. SWAG Architecture and fail2ban Integration

SWAG (Secure Web Application Gateway) is a LinuxServer.io Docker image combining:
- nginx (web server/reverse proxy)
- PHP (server-side scripting)
- Certbot (automated SSL/TLS from Let's Encrypt/ZeroSSL)
- fail2ban (intrusion prevention)

**Architecture:**
- fail2ban runs **inside** SWAG container alongside nginx
- Requires `--cap-add=NET_ADMIN` capability for iptables modification
- SWAG sits at network edge, making it ideal for perimeter security
- Monitors logs in `/config/log/nginx/` (access.log and error.log)

**Integration Details:**
- fail2ban uses regex to parse nginx logs
- Detects attack patterns (brute force, bots, exploits)
- Bans IPs by inserting iptables rules
- Time synchronization critical for accurate log parsing

---

### 2. Default SWAG fail2ban Jails

SWAG includes 5 pre-configured jails:

1. **nginx-http-auth**: Detects failed HTTP Basic Authentication
   - Monitors: error.log
   - Triggers: "password mismatch", "user not found"

2. **nginx-badbots**: Blocks malicious bots by User-Agent
   - Monitors: access.log
   - Blocks: scrapers, harvesters, malicious tools

3. **nginx-botsearch**: Catches vulnerability scanners
   - Monitors: access.log
   - Triggers: Repeated 404s on sensitive paths (wp-login.php, admin/, etc.)

4. **nginx-deny**: Detects access rule violations
   - Monitors: error.log
   - Triggers: "access forbidden by rule"

5. **nginx-unauthorized**: Backend auth failures
   - Monitors: access.log
   - Triggers: HTTP 401 responses

---

### 3. Custom Filter Creation

**Process:**
1. Create filter file: `/config/fail2ban/filter.d/custom.local`
2. Define regex in `[Definition]` section with `failregex`
3. Test with `fail2ban-regex` command
4. Activate in `jail.local`

**Example Patterns:**

Credential Stuffing:
```ini
failregex = ^<HOST>.*"(GET|POST|HEAD).*" (401) .*$
```

SQL Injection via Error Codes:
```ini
failregex = ^<HOST>.*"(GET|POST).*" (400|403|404|444) .*$
```

Path Traversal:
```ini
failregex = ^<HOST> -.*GET.*(\.php|\.asp|\.exe|\.pl|\.cgi|\.scgi)
```

**Testing:**
```bash
docker exec swag fail2ban-regex /config/log/nginx/access.log /config/fail2ban/filter.d/custom.local
```

---

### 4. Docker Networking and iptables

**The Critical Problem:**
- Standard fail2ban uses `INPUT` chain
- Docker containers use `FORWARD` chain (NAT routing)
- Bans in INPUT chain do NOT block Docker traffic

**The Solution: DOCKER-USER Chain:**
- Docker-specific chain evaluated BEFORE Docker's rules
- User-defined rules applied to ALL containers
- **Must configure**: `chain = DOCKER-USER` in jail.local

**Configuration:**
```ini
[nginx-http-auth]
chain = DOCKER-USER  # Critical for containers
```

For host services (SSH on host):
```ini
[sshd]
chain = INPUT
```

**Verification:**
```bash
sudo iptables -n -L DOCKER-USER | grep f2b
```

---

### 5. Ban Configuration Best Practices

**Core Parameters:**
- `findtime`: Window to count failures
- `maxretry`: Failures allowed before ban
- `bantime`: Ban duration

**Recommended Settings by Attack Type:**

**Brute Force (SSH/FTP):**
```ini
findtime = 10m
maxretry = 3-5
bantime = 1h-1d
```

**Low and Slow Attacks:**
```ini
findtime = 1d
maxretry = 3-5
bantime = 24h
```

**Web Scanners:**
```ini
findtime = 5m
maxretry = 10-15
bantime = 1d-1w
```

**Incremental Banning (v0.11+):**
```ini
[DEFAULT]
bantime.increment = true
bantime = 1h
bantime.factor = 24
bantime.maxtime = 5w
findtime = 24h
```
Result: 1st = 1h, 2nd = 24h, 3rd = 24d, 4th = 5w

---

### 6. Whitelisting and False Positive Prevention

**Permanent Whitelisting:**
```ini
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1 203.0.113.5 192.168.1.0/24
```

**Best Practices:**
1. Always whitelist localhost (127.0.0.1/8, ::1)
2. Whitelist entire management subnets (not individual IPs)
3. DO NOT whitelist CDN IPs (configure real IP restoration instead)
4. Avoid DNS hostnames (DNS failures = potential lockout)
5. Keep whitelist minimal for security

**Temporary Whitelist:**
```bash
sudo fail2ban-client set sshd addignoreip 192.0.0.1
```

---

### 7. fail2ban Action Types

**Local Firewall:**
- `iptables-multiport`: Standard, blocks specific ports
- `iptables-allports`: Blocks all ports from IP
- `iptables-ipset`: High-performance (O(1) lookup), recommended for large ban lists
- `nftables-multiport`: Modern replacement for iptables

**Cloud/CDN:**
- `cloudflare`: Updates Cloudflare firewall
- `cloudflare-apiv4`: Modern Cloudflare API integration

**Notifications:**
- `sendmail-whois-lines`: Email with WHOIS + logs
- `discord-webhook`: Discord notifications
- `telegram`: Telegram bot messages

**Reporting:**
- `abuseipdb`: Community threat intelligence
- `badips`: IP reputation database

**Stacking Actions:**
```ini
action = %(action_)s
         cloudflare[cfuser="email", cftoken="token"]
         discord-webhook[webhook="url"]
         abuseipdb[abuseipdb_apikey="key"]
```

---

### 8. Monitoring and Debugging

**Status Commands:**
```bash
# Overall status
sudo fail2ban-client status

# Specific jail
sudo fail2ban-client status nginx-http-auth

# All banned IPs
sudo fail2ban-client banned

# Verify firewall
sudo iptables -n -L | grep f2b
```

**Debugging:**
```bash
# Test regex
sudo fail2ban-regex /var/log/auth.log /etc/fail2ban/filter.d/sshd.conf

# Show missed lines
sudo fail2ban-regex ... --print-all-missed

# Check logs
sudo tail -f /var/log/fail2ban.log

# Manual ban/unban
sudo fail2ban-client set nginx-http-auth banip 203.0.113.5
sudo fail2ban-client set nginx-http-auth unbanip 203.0.113.5
```

---

### 9. nginx Log Formats for fail2ban

**Enhanced Security Format:**
```nginx
log_format security '$remote_addr - $remote_user [$time_local] '
                    '"$request" $status $body_bytes_sent '
                    '"$http_referer" "$http_user_agent" '
                    '"$http_x_forwarded_for" $request_time';
```

**Critical for Proxies: Real IP Restoration**
```nginx
http {
    set_real_ip_from 103.21.244.0/22;  # Cloudflare IPs
    real_ip_header X-Forwarded-For;
    real_ip_recursive on;
}
```

**Log Rotation:**
```nginx
# /etc/logrotate.d/nginx
/var/log/nginx/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data adm
}
```

---

### 10. Common Attack Vectors and Protection

**Bot Attacks:**
- Detection: nginx-badbots, nginx-botsearch jails
- Protection: Block bad User-Agents, 404s on sensitive paths

**DDoS/DoS:**
- Detection: nginx rate limiting + nginx-limit-req jail
- Protection: limit_req module, connection limiting

**Authentication Bypass:**
- Detection: nginx-http-auth, nginx-unauthorized jails
- Protection: Monitor 401 responses, failed auth logs

**Path Traversal:**
- Detection: Custom filters for `../` patterns
- Protection: nginx deny directives + nginx-deny jail

**SQL Injection/XSS:**
- Detection: Monitor 403/444 error codes
- Protection: nginx blocks known patterns, fail2ban bans persistent attempts

---

### 11. Rate Limiting Integration

**Relationship:**
1. nginx throttles requests immediately (limit_req module)
2. fail2ban monitors error log for rate limit violations
3. Persistent offenders get firewall-level bans

**nginx Configuration:**
```nginx
http {
    limit_req_zone $binary_remote_addr zone=login:10m rate=1r/m;

    server {
        location /login {
            limit_req zone=login burst=5;
        }
    }
}
```

**fail2ban Configuration:**
```ini
[nginx-limit-req]
enabled = true
filter = nginx-limit-req
logpath = /var/log/nginx/error.log
maxretry = 2
bantime = 3600
chain = DOCKER-USER
```

**Filter:**
```ini
[Definition]
failregex = limiting requests, excess:.* by zone.*client: <HOST>
```

---

### 12. Production Security Hardening

**SSL/TLS:**
- Use DNS validation for wildcard certs
- Configure HSTS with appropriate max-age
- Enable OCSP stapling

**Headers:**
```nginx
add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-Robots-Tag "noindex, nofollow" always;
```

**GeoIP Blocking:**
```nginx
geoip2 /config/geoip2db/GeoLite2-Country.mmdb {
    $geoip2_data_country_code country iso_code;
}

map $geoip2_data_country_code $allowed_country {
    default no;
    US yes;
    CA yes;
}

if ($allowed_country = no) {
    return 444;
}
```

**fail2ban:**
- Enable all recommended jails
- Configure recidive for repeat offenders
- Setup notifications (email/webhook)
- Whitelist management IPs

---

### 13. Troubleshooting Common Issues

**Systematic Approach:**

1. **Check Jail Status:**
   ```bash
   sudo fail2ban-client status <jail>
   ```

2. **Test Regex:**
   ```bash
   sudo fail2ban-regex /var/log/auth.log /etc/fail2ban/filter.d/sshd.conf --print-all-missed
   ```

3. **Verify Firewall:**
   ```bash
   sudo iptables -L DOCKER-USER -n -v
   ```

**Common Errors:**
- Wrong chain (INPUT vs DOCKER-USER)
- Timezone mismatch
- Incorrect log path
- Regex doesn't match log format
- IP whitelisted
- Behind CDN without real IP config
- Corrupted database
- Permission issues

**Quick Fixes:**
- Add `chain = DOCKER-USER` for containers
- Use fail2ban-regex to test patterns
- Verify logpath points to correct file
- Configure realip module for proxies
- Check ignoreip parameter
- Delete/vacuum database if huge

---

### 14. Recidive and Escalating Bans

**Recidive Jail:**
```ini
[recidive]
enabled = true
logpath = /var/log/fail2ban.log
banaction = iptables-allports
bantime = 1w
findtime = 1d
maxretry = 5
```

**Incremental Banning (Modern):**
```ini
[DEFAULT]
bantime.increment = true
bantime = 1h
bantime.factor = 24
bantime.maxtime = 5w
findtime = 24h
```

**Permanent Banning:**
```ini
bantime = -1  # Never expires
```

**Best Practice: Use Both**
- Incremental for per-jail escalation
- Recidive for cross-jail repeat offenders

---

### 15. Notifications and Alerting

**Email:**
```ini
[DEFAULT]
destemail = admin@example.com
sender = fail2ban@example.com
action = %(action_mwl)s  # WHOIS + logs
```

**Webhooks:**
```ini
action = %(action_)s
         discord-webhook[webhook="URL"]
         telegram[token="TOKEN", chat_id="ID"]
```

**Reporting:**
```ini
action = %(action_)s
         abuseipdb[abuseipdb_apikey="KEY", abuseipdb_category="18,22"]
```

**Custom Scripts:**
```ini
[Definition]
actionban = /usr/local/bin/notify.sh ban <ip> <name> <failures>
actionunban = /usr/local/bin/notify.sh unban <ip> <name>
```

---

### 16. Advanced Threat Detection

**Behavioral Patterns:**

**Web Shells:**
```ini
failregex = ^<HOST> -.*GET.*(\.php|\.asp|\.exe|\.pl|\.cgi|\.scgi)
```

**Exploit Probing:**
```ini
failregex = ^<HOST>.*"(GET|POST).*" (400|403|404|444) .*$
```

**Suspicious Patterns:**
```ini
# Unusual HTTP methods
failregex = ^<HOST>.*"(TRACE|TRACK|DEBUG|OPTIONS|CONNECT) /

# Large request headers
failregex = ^<HOST>.*"GET /.{1000,}
```

**Low and Slow APT:**
```ini
findtime = 1w
maxretry = 5
bantime = 1m
```

**Application-Specific:**
- Nextcloud: Login failures + trusted domain errors
- WordPress: wp-login.php POST attempts
- GitLab: Failed login patterns

---

### 17. Threat Intelligence Integration

**Outbound Reporting:**
```ini
action = abuseipdb[abuseipdb_apikey="KEY", abuseipdb_category="18,22"]
```

**Inbound Blocklists:**

**Method 1: nginx Ultimate Bad Bot Blocker**
- Downloads bad bot/IP lists
- nginx returns 444 for matches
- fail2ban monitors 444s and bans

**Method 2: ipset with External Lists**
```bash
ipset create blocklist hash:net
wget -qO- URL | grep -v '^#' | while read IP; do
    ipset add blocklist "$IP"
done
iptables -I DOCKER-USER -m set --match-set blocklist src -j DROP
```

**Method 3: GeoIP Blocking**
- Download GeoLite2 database
- Configure nginx geo module
- Return 444 for blocked countries

**Maintenance:**
- Update lists daily/weekly
- Monitor false positives
- Use ipset for performance
- Document update procedures

---

### 18. Performance Optimization

**Database:**
```ini
dbpurgeage = 1d  # Keep bans for 1 day only
```

**Efficient Banning (ipset):**
```ini
banaction = iptables-ipset-proto6
```
Performance: O(1) vs O(n) for standard iptables

**Log Parsing Backend:**
```ini
backend = systemd  # Recommended
# or
backend = pyinotify
```

**Filter Optimization:**
- Anchor regex to start of line (^)
- Avoid catastrophic backtracking
- Use ignoreregex for health checks

**Reduce Log Volume:**
```nginx
location /health {
    access_log off;
}

location ~* \.(jpg|png|css|js)$ {
    access_log off;
}
```

**Checklist:**
- Use ipset for large ban lists
- Enable systemd/pyinotify backend
- Set usedns = no
- Optimize regex patterns
- Reduce log volume
- Set appropriate dbpurgeage
- Disable unused jails

---

### 19. Container Deployment Strategies

**Option 1: fail2ban Inside Container (SWAG)**
```yaml
services:
  swag:
    cap_add: [NET_ADMIN]
    chain = DOCKER-USER
```
Pros: All-in-one, easy deployment
Cons: Elevated privileges, single container only

**Option 2: fail2ban on Host**
```yaml
services:
  app:
    volumes:
      - /var/log/app:/app/logs
```
Pros: Centralized, multiple containers
Cons: Complex log management

**Option 3: Dedicated fail2ban Container**
```yaml
services:
  fail2ban:
    image: crazymax/fail2ban
    network_mode: host
    cap_add: [NET_ADMIN, NET_RAW]
```
Pros: Containerized but centralized
Cons: Host network mode required

**Critical:** Always use `chain = DOCKER-USER` for containers

**Testing:**
1. Verify DOCKER-USER chain exists
2. Trigger ban
3. Check fail2ban status
4. Verify firewall rule
5. Test connectivity (should fail)

---

### 20. Testing and Safe Deployment

**Pre-Deployment:**
1. Test regex with fail2ban-regex
2. Whitelist management IPs
3. Use dummy action first
4. Set short ban times initially

**Safe Testing:**
```ini
[test-jail]
banaction = dummy  # Only logs
bantime = 60  # Quick recovery
```

**Staged Rollout:**
1. Monitor only (dummy action + email)
2. Short bans with lenient thresholds
3. Production settings after validation

**Emergency Unban:**
```bash
# Method 1: Console access
sudo fail2ban-client set <jail> unbanip <ip>

# Method 2: Direct iptables
sudo iptables -D f2b-<jail> <rule_number>

# Method 3: Stop service
sudo systemctl stop fail2ban
```

**Validation Checklist:**
- Tested regex with sample logs
- Whitelisted management networks
- Set reasonable initial ban times
- Configured notifications
- Created configuration backup
- Tested actual ban from test IP
- Verified firewall rules
- Monitored for 24 hours

**Continuous Testing:**
- Weekly ban statistics review
- Monthly false positive audit
- A/B testing of aggressive vs standard settings

## Key Insights

1. **DOCKER-USER is Critical**: Using INPUT chain for containers is the #1 failure mode
2. **Real IP Restoration Essential**: Behind proxies/CDNs, configure nginx realip module
3. **Performance Matters**: Use ipset for >100 banned IPs (O(1) vs O(n) lookup)
4. **Test Before Deploy**: fail2ban-regex is mandatory for validating filters
5. **Whitelist Carefully**: Always include localhost, management networks
6. **Incremental Banning**: Modern approach superior to manual recidive configuration
7. **Multi-Layer Defense**: Combine nginx rate limiting with fail2ban
8. **Monitor False Positives**: Regular audits prevent legitimate user bans
9. **Document Everything**: Emergency procedures critical for lockout recovery
10. **Start Conservative**: Short bans and lenient thresholds during testing

## Cross-Source Analysis

### Areas of Agreement:
- DOCKER-USER chain is universally required for container protection
- ipset recommended for performance with large ban lists
- fail2ban-regex testing is mandatory before deployment
- Whitelisting localhost and management IPs is critical
- Real IP restoration essential for CDN/proxy setups

### Areas of Variation:
- Ban times: Conservative (10m-1h) vs aggressive (1d-1w)
- Recidive vs incremental banning preferences
- systemd vs pyinotify backend recommendations
- Host vs container deployment strategies

### Contradictions:
- Some sources recommend permanent bans (-1), others suggest time-limited
- Debate over fail2ban inside containers vs on host
- GeoIP blocking effectiveness (some view as essential, others as optional)

## Citation Map

**Most Cited Sources:**
1. LinuxServer.io SWAG Documentation (architecture, configuration)
2. fail2ban Official Manual (filter syntax, jail configuration)
3. GitHub docker-swag Repository (default configurations, examples)
4. DigitalOcean Tutorials (step-by-step guides)
5. Unraid Forums (real-world troubleshooting)
6. nginx Documentation (log formats, modules)

**Topics by Source Type:**
- **Official Docs**: Architecture, API references, configuration syntax
- **Community Forums**: Troubleshooting, real-world issues, workarounds
- **GitHub Issues**: Bug reports, feature requests, edge cases
- **Tutorials**: Step-by-step setup, best practices
- **Blogs**: Advanced patterns, optimization techniques

## Gaps and Limitations

**Questions Couldn't Fully Answer:**
1. Specific fail2ban performance benchmarks with large IP sets (>10K)
2. Machine learning integration patterns (conceptual only)
3. Crowdsec vs fail2ban detailed comparison
4. Zero-day detection effectiveness metrics
5. False positive rates in production deployments

**Topics with Limited Coverage:**
1. fail2ban with IPv6 (mentioned but not detailed)
2. fail2ban in Kubernetes environments (Docker-focused)
3. Integration with commercial WAFs
4. Automated threat intel feed updates
5. Legal compliance considerations (GDPR, logging)

**Areas Needing More Research:**
- Performance metrics for high-traffic sites (>1M requests/day)
- Production failure modes and recovery procedures
- Integration with SIEM platforms
- Cost-benefit analysis of different approaches
- Long-term maintenance and operational overhead

## Recommendations

### Immediate Actions:
1. Configure DOCKER-USER chain in all container jails
2. Implement ipset for performance (if >100 banned IPs)
3. Setup real IP restoration if behind CDN/proxy
4. Test all filters with fail2ban-regex
5. Whitelist management networks

### Short-term Improvements:
1. Enable incremental banning for repeat offenders
2. Configure notifications (Discord/email)
3. Implement nginx rate limiting + fail2ban integration
4. Setup GeoIP blocking (if applicable)
5. Regular false positive audits

### Long-term Strategy:
1. Integrate threat intelligence feeds
2. Implement behavioral detection patterns
3. Setup centralized logging and monitoring
4. Document runbooks for common scenarios
5. Regular security audits and configuration reviews

### Monitoring and Maintenance:
1. Weekly ban statistics review
2. Monthly database pruning (if >100MB)
3. Quarterly security audit
4. Annual configuration review and optimization
5. Continuous testing of new attack patterns

## Conclusion

SWAG + fail2ban integration provides robust reverse proxy security when properly configured. Success depends on:

1. **Correct iptables chain configuration** (DOCKER-USER for containers)
2. **Real IP restoration** for accurate threat detection behind proxies
3. **Performance optimization** (ipset, efficient backends)
4. **Comprehensive testing** before production deployment
5. **Continuous monitoring** and adjustment

The research demonstrates that fail2ban remains highly effective for perimeter security when combined with modern best practices. Key to success is understanding Docker networking nuances, implementing multi-layer defense, and maintaining vigilant monitoring for false positives.

For production deployments, recommend starting with conservative settings, thorough testing, and gradual rollout. The combination of SWAG's integrated approach with fail2ban's flexibility provides enterprise-grade security for self-hosted infrastructure.
