# SWAG + fail2ban Integration - Current Setup on squirts

**Host:** squirts
**Date Documented:** 2026-02-07
**Purpose:** Read-only inspection of existing SWAG reverse proxy with integrated fail2ban

---

## Executive Summary

SWAG (Secure Web Application Gateway) is running on host `squirts` as a containerized reverse proxy with fail2ban integrated **inside the container**. The container uses LinuxServer.io's SWAG image which bundles nginx, Let's Encrypt certificate management, and fail2ban in a single container.

**Key Points:**
- fail2ban runs INSIDE the SWAG container (not on the host)
- 5 jails currently active (all nginx-related)
- Uses iptables inside container with `NET_ADMIN` capability
- Logs stored persistently on host at `/mnt/appdata/swag/log/`
- Configuration managed via bind-mounted volumes

---

## Container Configuration

### Docker Compose Setup

**Location:** `/mnt/compose/swag/docker-compose.yaml`

```yaml
services:
  linuxserver:
    container_name: swag
    networks:
      jakenet:
        ipv4_address: 10.6.0.100
    image: lscr.io/linuxserver/swag
    cap_add:
      - NET_ADMIN  # Required for iptables management
    environment:
      - URL=${URL}
      - TZ=${TZ}
      - VALIDATION=${VALIDATION}
      - SUBDOMAINS=${SUBDOMAINS}
      - CERTPROVIDER=${CERTPROVIDER}
      - DNSPLUGIN=${DNSPLUGIN}
      - PROPAGATION=${PROPAGATION}
      - EMAIL=${EMAIL}
      - ONLY_SUBDOMAINS=${ONLY_SUBDOMAINS}
      - EXTRA_DOMAINS=${EXTRA_DOMAINS}
      - STAGING=${STAGING}
      - DOCKER_MODS=${DOCKER_MODS}
      - DOCKER_MODS_FORCE_REGISTRY=${DOCKER_MODS_FORCE_REGISTRY}
      - DOCKER_HOST=${DOCKER_HOST}
      - MAXMINDDB_LICENSE_KEY=${MAXMINDDB_LICENSE_KEY}
      - PUID=${PUID}
      - PGID=${PGID}
      - UMASK=${UMASK}
    ports:
      - ${SWAG_HTTPS_PORT}:443/tcp    # HTTPS
      - ${SWAG_HTTP_PORT}:80/tcp      # HTTP
      - ${SWAG_SSH_PORT}:22           # SSH (internal)
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ${APPDATA_PATH}/swag:/config:rw
      - ${APPDATA_PATH}/swag/docker-mod-cache:/modcache
    extra_hosts:
      - "tootie.tv:127.0.0.1"
    restart: unless-stopped

networks:
  jakenet:
    external: true
```

**Port Mappings (from `docker ps`):**
- `0.0.0.0:80->80/tcp` - HTTP (redirect to HTTPS)
- `0.0.0.0:443->443/tcp` - HTTPS (main proxy)
- `0.0.0.0:2002->22/tcp` - SSH (container access)

**Network Configuration:**
- **Network:** jakenet (external bridge network)
- **Subnet:** 10.6.0.0/16
- **Gateway:** 10.6.0.1
- **SWAG IP:** 10.6.0.100
- **Container Count:** 36 containers on jakenet

---

## fail2ban Configuration

### Main Configuration

**Location:** `/etc/fail2ban/fail2ban.conf` (inside container)

```conf
loglevel = INFO
logtarget = /var/log/fail2ban.log
socket = /var/run/fail2ban/fail2ban.sock
pidfile = /var/run/fail2ban/fail2ban.pid
dbfile = /var/lib/fail2ban/fail2ban.sqlite3  # Persistent ban database
dbpurgeage = 1d  # Purge bans older than 1 day
```

**Database Location:** `/config/fail2ban/fail2ban.sqlite3` (bind-mounted to host)

### Jail Configuration

**Custom Jail File:** `/config/fail2ban/jail.local` (bind-mounted from host)

**Location on Host:** `/mnt/appdata/swag/fail2ban/jail.local`

```conf
[DEFAULT]
# Whitelisted IP ranges (LAN subnets + external IP)
ignoreip = 10.1.0.0/24 10.0.0.0/24 172.18.0.0/24 172.17.0.0/24 98.25.240.21

# Ban action (changed from iptables-multiport to iptables-allports)
banaction = iptables-allports

# Ban duration: 3600 seconds (1 hour)
bantime  = 3600

# Detection window: 60 seconds
findtime  = 60

# Max retry attempts before ban: 5
maxretry = 5

# ===== ACTIVE JAILS =====

[sshd]
enabled = false  # SSH jail disabled

[nginx-http-auth]
enabled  = true
filter   = nginx-http-auth
port     = http,https
logpath  = /config/log/nginx/error.log

[nginx-badbots]
enabled  = true
port     = http,https
filter   = nginx-badbots
logpath  = /config/log/nginx/access.log
maxretry = 2  # Stricter for bad bots

[nginx-botsearch]
enabled  = true
port     = http,https
filter   = nginx-botsearch
logpath  = /config/log/nginx/access.log

[nginx-deny]
enabled  = true
port     = http,https
filter   = nginx-deny
logpath  = /config/log/nginx/error.log

[nginx-unauthorized]
enabled  = true
port     = http,https
filter   = nginx-unauthorized
logpath  = /config/log/nginx/access.log
```

### Active Jails Status

**Command:** `docker exec swag fail2ban-client status`

```
Status
|- Number of jail:	5
`- Jail list:	nginx-badbots, nginx-botsearch, nginx-deny, nginx-http-auth, nginx-unauthorized
```

**Example Jail Details (nginx-http-auth):**

```
Status for the jail: nginx-http-auth
|- Filter
|  |- Currently failed:	0
|  |- Total failed:	0
|  `- File list:	/config/log/nginx/error.log
`- Actions
   |- Currently banned:	0
   |- Total banned:	0
   `- Banned IP list:
```

---

## Filter Configurations

### 1. nginx-http-auth

**Location:** `/config/fail2ban/filter.d/nginx-http-auth.conf`

**Purpose:** Blocks HTTP basic auth failures and SSL handshake errors

**Regex Pattern:**
```conf
mode = normal

_ertp-auth = error
mdre-auth = ^%(__prefix_line)suser "(?:[^"]+|.*?)":? (?:password mismatch|was not found in "[^\"]*"), client: <HOST>, server: \S*, request: "\S+ \S+ HTTP/\d+\.\d+", host: "\S+"(?:, referrer: "\S+")?\s*$

_ertp-fallback = crit
mdre-fallback = ^%(__prefix_line)sSSL_do_handshake\(\) failed \(SSL: error:\S+(?: \S+){1,3} too (?:long|short)\)[^,]*, client: <HOST>

failregex = <mdre-<mode>>
```

**Matches:**
- Password mismatches in HTTP basic auth
- SSL handshake failures (TLS_FALLBACK_SCSV attacks)

**Log Source:** `/config/log/nginx/error.log`

---

### 2. nginx-badbots

**Location:** `/config/fail2ban/filter.d/nginx-badbots.conf`

**Purpose:** Blocks known malicious user-agents and email scrapers

**Pattern:**
```conf
badbotscustom = EmailCollector|WebEMailExtrac|TrackBack/1\.02|sogou music spider

badbots = Atomic_Email_Hunter/4\.0|atSpider/1\.0|autoemailspider|bwh3_user_agent|
          China Local Browse 2\.6|ContactBot/0\.2|ContentSmartz|DataCha0s/2\.0|
          [... extensive list of ~100+ known bad bots ...]

failregex = ^<HOST> -.*"(GET|POST|HEAD).*HTTP.*"(?:%(badbots)s|%(badbotscustom)s)"$
```

**Matches:** User-Agent strings in access logs from known scrapers/bots

**Log Source:** `/config/log/nginx/access.log`

---

### 3. nginx-botsearch

**Location:** `/config/fail2ban/filter.d/nginx-botsearch.conf`

**Purpose:** Blocks bots searching for common vulnerable URLs

**Pattern:**
```conf
failregex = ^<HOST> \- \S+ \[\] \"(GET|POST|HEAD) \/<block> \S+\" 404 .+$
            ^ \[error\] \d+#\d+: \*\d+ (\S+ )?\"\S+\" (failed|is not found) \(2\: No such file or directory\), client\: <HOST>\, server\: \S*\, request: \"(GET|POST|HEAD) \/<block> \S+\"\, .*?$
```

**Includes:** `botsearch-common.conf` with list of vulnerable paths:
- `/admin`, `/wp-admin`, `/phpmyadmin`
- `/manager`, `/.env`, `/xmlrpc.php`

**Log Source:** `/config/log/nginx/access.log` and `/error.log`

---

### 4. nginx-deny

**Location:** `/config/fail2ban/filter.d/nginx-deny.conf`

**Purpose:** Blocks IPs triggering nginx "access forbidden by rule" errors

**Pattern:**
```conf
failregex = ^ \[error\] \d+#\d+: \*\d+ (access forbidden by rule), client: <HOST>, server: \S*, request: "\S+ \S+ HTTP\/\d+\.\d+", host: "\S+"(?:, referrer: "\S+")?\s*$
```

**Log Source:** `/config/log/nginx/error.log`

---

### 5. nginx-unauthorized

**Location:** `/config/fail2ban/filter.d/nginx-unauthorized.conf`

**Purpose:** Blocks repeated HTTP 401 Unauthorized attempts

**Pattern:**
```conf
failregex = ^<HOST>.*"(GET|POST|HEAD).*" (401) .*$
```

**Log Source:** `/config/log/nginx/access.log`

**Note:** This jail shows the highest activity in logs (monitoring auth-protected services)

---

## iptables Integration

### Current iptables Rules

**Command:** `docker exec swag iptables -L -n -v`

```
Chain INPUT (policy ACCEPT 10M packets, 4759M bytes)
 pkts bytes target     prot opt in     out     source               destination
9944K 4748M f2b-nginx-unauthorized  tcp  --  *      *       0.0.0.0/0            0.0.0.0/0

Chain FORWARD (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination

Chain OUTPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination

Chain f2b-nginx-unauthorized (1 references)
 pkts bytes target     prot opt in     out     source               destination
9944K 4748M RETURN     all  --  *      *       0.0.0.0/0            0.0.0.0/0
```

**Analysis:**
- fail2ban creates custom iptables chains (e.g., `f2b-nginx-unauthorized`)
- All traffic jumps to fail2ban chains for inspection
- Banned IPs get DROP rules inserted at top of chain
- RETURN rule at bottom allows non-banned traffic
- Container requires `NET_ADMIN` capability to modify iptables

---

## Log Structure

### Log Locations (on host)

**Base Path:** `/mnt/appdata/swag/log/`

```
log/
├── fail2ban/
│   ├── fail2ban.log        (current, 223KB)
│   ├── fail2ban.log.1      (rotated)
│   └── fail2ban.log.*.gz   (compressed old logs, 7 days retention)
├── nginx/
│   ├── access.log          (current, 106MB)
│   ├── access.log.1        (rotated)
│   ├── access.log.*.gz     (14 days retention)
│   ├── error.log           (current, 884KB)
│   ├── error.log.1         (rotated)
│   └── error.log.*.gz      (14 days retention)
├── letsencrypt/            (certificate renewal logs)
├── php/                    (PHP-FPM logs)
└── logrotate.status
```

### Log Rotation

- **nginx logs:** Rotated daily, 14 backups retained
- **fail2ban logs:** Rotated weekly, 7 backups retained
- **Compression:** Rotated logs gzipped to save space

### Sample fail2ban Log Entries

```
2026-02-07 00:52:35,129 fail2ban.filter [1245]: INFO [nginx-unauthorized] Found 69.155.6.42 - 2026-02-07 00:52:34
2026-02-06 22:23:05,933 fail2ban.filter [1245]: INFO [nginx-unauthorized] Found 45.133.172.215 - 2026-02-06 22:23:05
2026-02-06 14:10:42,208 fail2ban.filter [1245]: INFO [nginx-botsearch] Found 20.110.243.199 - 2026-02-06 14:10:42
```

**Format:** `timestamp level module [pid]: level [jail] Found <IP> - timestamp`

**Note:** Logs show detection events, not ban actions (bans only logged when maxretry exceeded)

---

## nginx Configuration

### Main Config

**Location:** `/config/nginx/nginx.conf`

**Key Settings:**
```nginx
user abc;
worker_processes auto;
error_log /config/log/nginx/error.log;
access_log /config/log/nginx/access.log;

http {
    server_tokens off;              # Hide nginx version
    client_max_body_size 0;         # Unlimited upload size
    server_names_hash_bucket_size 128;

    # Enable HTTP/2 by default
    http2 on;

    # WebSocket support
    map $http_upgrade $connection_upgrade {
        default upgrade;
        '' close;
    }

    # Include site configurations
    include /etc/nginx/http.d/*.conf;
    include /config/nginx/site-confs/*.conf;
}
```

### Proxy Configurations

**Location:** `/mnt/appdata/swag/nginx/proxy-confs/`

**Count:** 400+ proxy configuration files (mostly `.sample` templates)

**Active Configs (non-.sample files):**
- `overseerr.subdomain.conf`
- `plex.subdomain.conf`
- `gotify.subdomain.conf`
- `authelia.subdomain.conf`
- `bytestash.subdomain.conf`
- `firecrawl.subdomain.conf`
- `paperless.subdomain.conf`
- [many more...]

**Pattern:** Each service gets a subdomain configuration file with nginx location blocks

---

## Action Configurations

### Available Actions

**Location:** `/config/fail2ban/action.d/`

**Key Actions:**
- `iptables-allports.conf` - Current ban action (blocks all ports)
- `iptables-common.conf` - Shared iptables configuration
- `cloudflare.conf` - Ban at Cloudflare level
- `abuseipdb.conf` - Report to AbuseIPDB
- `mail.conf` - Email notifications
- `nginx-block-map.conf` - Add to nginx deny map

**Default Action:** `iptables-allports` (configured in jail.local)

---

## Security Considerations

### Whitelisted Networks

**From jail.local:**
```
ignoreip = 10.1.0.0/24 10.0.0.0/24 172.18.0.0/24 172.17.0.0/24 98.25.240.21
```

- **10.1.0.0/24, 10.0.0.0/24:** Local LAN subnets
- **172.18.0.0/24, 172.17.0.0/24:** Docker bridge networks
- **98.25.240.21:** External static IP (likely admin's home/office)

### Ban Policy

- **Ban Duration:** 1 hour (3600 seconds)
- **Detection Window:** 60 seconds
- **Max Retries:** 5 attempts (2 for badbots jail)
- **Database Purge:** Bans older than 1 day removed from DB

### Container Capabilities

- **NET_ADMIN:** Required for iptables manipulation
- **Risk:** Container has elevated privileges to modify network rules
- **Mitigation:** Container runs as unprivileged user (abc) for application layer

---

## Proxy Service Architecture

### SWAG as Central Gateway

**Role:** All external traffic flows through SWAG before reaching backend services

```
Internet → SWAG (10.6.0.100) → jakenet → Backend Services
   ↓
fail2ban monitors nginx logs
   ↓
Bans applied via iptables in SWAG container
   ↓
Banned IPs blocked at reverse proxy layer
```

**Backend Services (sample from jakenet):**
- overseerr: 10.6.0.25
- authelia: 10.6.0.26 (authentication gateway)
- gotify: 10.6.0.9
- paperless: 10.6.0.33
- bytestash: 10.6.0.27
- [33 more services...]

### Authentication Flow

**Authelia Integration:**
- Authelia (10.6.0.26) provides SSO authentication
- Protected endpoints require Authelia auth before proxying
- fail2ban detects repeated 401s from failed auth attempts
- Authelia has its own backend (MariaDB 10.6.0.17, Redis 10.6.0.6)

---

## Monitoring & Observability

### fail2ban Status Commands

```bash
# Check overall status
docker exec swag fail2ban-client status

# Check specific jail
docker exec swag fail2ban-client status nginx-http-auth

# Get currently banned IPs
docker exec swag fail2ban-client get nginx-http-auth banip

# Unban an IP
docker exec swag fail2ban-client unban <IP>
```

### Log Inspection

```bash
# Live tail fail2ban log
tail -f /mnt/appdata/swag/log/fail2ban/fail2ban.log

# Live tail nginx access log
tail -f /mnt/appdata/swag/log/nginx/access.log

# Search for specific IP in logs
grep "192.168.1.100" /mnt/appdata/swag/log/nginx/access.log
```

### Database Queries

```bash
# Access fail2ban SQLite database
docker exec -it swag sqlite3 /config/fail2ban/fail2ban.sqlite3

# View bans table
SELECT * FROM bans;

# View jail table
SELECT * FROM jails;
```

---

## Maintenance & Updates

### Container Updates

```bash
# Pull latest SWAG image
docker pull lscr.io/linuxserver/swag

# Recreate container with new image
cd /mnt/compose/swag
docker compose up -d --force-recreate
```

**Note:** Configuration persists via bind mounts

### Configuration Backup

**Critical Files to Backup:**
- `/mnt/appdata/swag/fail2ban/jail.local` - Custom jail config
- `/mnt/appdata/swag/fail2ban/filter.d/` - Custom filters
- `/mnt/appdata/swag/nginx/proxy-confs/*.conf` - Proxy configs (non-.sample)
- `/mnt/appdata/swag/keys/` - SSL certificates

### Log Cleanup

Logs auto-rotate, but manual cleanup:

```bash
# Remove old compressed logs
find /mnt/appdata/swag/log/ -name "*.gz" -mtime +30 -delete

# Clear fail2ban database (resets ban history)
docker exec swag fail2ban-client reload
```

---

## Troubleshooting

### Common Issues

**1. fail2ban not starting:**
```bash
# Check container logs
docker logs swag | grep fail2ban

# Verify fail2ban process
docker exec swag ps aux | grep fail2ban
```

**2. Jails not activating:**
```bash
# Test filter regex
docker exec swag fail2ban-regex /config/log/nginx/access.log /config/fail2ban/filter.d/nginx-unauthorized.conf
```

**3. Bans not working:**
```bash
# Check iptables rules
docker exec swag iptables -L -n -v

# Verify ban action
docker exec swag cat /etc/fail2ban/action.d/iptables-allports.conf
```

**4. False positives (legitimate IPs banned):**
```bash
# Add to ignoreip in jail.local
# Reload fail2ban
docker exec swag fail2ban-client reload
```

---

## Performance Metrics

### Current Activity (as of 2026-02-07)

- **Container Uptime:** 12 days
- **Total Packets Processed:** 10M packets (4.7GB)
- **nginx Access Log Size:** 106MB (current)
- **fail2ban Log Size:** 223KB (current)
- **Active Jails:** 5
- **Currently Banned IPs:** 0 (at time of inspection)

### Detection Rate (from logs)

**Most Active Jail:** `nginx-unauthorized`
- Hundreds of detections daily
- Primarily from IPv6 addresses (e.g., `2600:1702:ad0:ed40::29`)
- Also scanning from cloud providers (AWS, GCP, Azure ranges)

**Moderate Activity:**
- `nginx-botsearch`: 2-3 detections per day
- Other jails: Minimal activity

---

## Recommendations

### Security Hardening

1. **Consider lowering maxretry** for nginx-unauthorized (currently 5, could be 3)
2. **Enable email notifications** on bans (configure `mail` action)
3. **Add Cloudflare action** to ban at CDN level (if using Cloudflare)
4. **Implement rate limiting** in nginx for auth endpoints
5. **Review ignoreip list** - ensure only trusted networks whitelisted

### Monitoring Improvements

1. **Set up metrics export** from fail2ban database
2. **Create Grafana dashboard** for ban trends
3. **Alert on high ban rates** (potential attack)
4. **Correlate fail2ban logs** with nginx access patterns

### Operational Improvements

1. **Document ban unban procedures** for incident response
2. **Create backup/restore scripts** for jail configurations
3. **Test disaster recovery** (container recreation, config restore)
4. **Review and tune detection windows** based on false positive rate

---

## Appendix: File Paths Reference

### Container Paths

| Purpose | Container Path | Host Path |
|---------|---------------|-----------|
| fail2ban config | `/config/fail2ban/` | `/mnt/appdata/swag/fail2ban/` |
| fail2ban logs | `/config/log/fail2ban/` | `/mnt/appdata/swag/log/fail2ban/` |
| nginx config | `/config/nginx/` | `/mnt/appdata/swag/nginx/` |
| nginx logs | `/config/log/nginx/` | `/mnt/appdata/swag/log/nginx/` |
| Proxy configs | `/config/nginx/proxy-confs/` | `/mnt/appdata/swag/nginx/proxy-confs/` |
| SSL certificates | `/config/keys/` | `/mnt/appdata/swag/keys/` |
| fail2ban DB | `/config/fail2ban/fail2ban.sqlite3` | `/mnt/appdata/swag/fail2ban/fail2ban.sqlite3` |

### System Paths (in container)

| Purpose | Path |
|---------|------|
| fail2ban binary | `/usr/bin/fail2ban-client` |
| Default jail config | `/etc/fail2ban/jail.conf` |
| Default fail2ban config | `/etc/fail2ban/fail2ban.conf` |
| Default filters | `/etc/fail2ban/filter.d/` |
| Default actions | `/etc/fail2ban/action.d/` |
| fail2ban socket | `/var/run/fail2ban/fail2ban.sock` |
| fail2ban PID | `/var/run/fail2ban/fail2ban.pid` |

---

## Conclusion

SWAG provides a well-integrated solution for reverse proxying with built-in security via fail2ban. The LinuxServer.io image bundles everything needed for a secure web gateway:

✅ **Strengths:**
- Single container deployment (simple management)
- Persistent configuration via bind mounts
- Comprehensive logging
- Active detection of common attack patterns
- iptables-based blocking at network layer

⚠️ **Considerations:**
- Requires NET_ADMIN capability (elevated privileges)
- fail2ban limited to single container (can't protect other hosts)
- No centralized ban coordination (each SWAG instance isolated)
- Manual intervention needed for advanced scenarios

**Overall:** Solid setup for a home lab environment. Provides essential security without complexity of distributed systems like Cloudflare or dedicated WAFs.

---

**Documentation Version:** 1.0
**Last Updated:** 2026-02-07
**Maintained By:** Automated inspection from squirts host
