# Glances Troubleshooting Guide

Common issues and solutions when working with Glances monitoring.

## Connection Issues

### Problem: Connection Refused

**Symptoms:**
```bash
curl: (7) Failed to connect to localhost port 61208: Connection refused
```

**Causes & Solutions:**

1. **Glances server not running:**
   ```bash
   # Check if glances is running
   ps aux | grep glances

   # Start glances in server mode
   glances -w

   # Start without web UI (API only)
   glances -w --disable-webui
   ```

2. **Wrong port number:**
   ```bash
   # Default port is 61208, check actual port
   netstat -tuln | grep glances
   # or
   ss -tuln | grep 61208

   # Start on specific port
   glances -w --port 61209
   ```

3. **Firewall blocking connection:**
   ```bash
   # Check firewall (Ubuntu/Debian)
   sudo ufw status
   sudo ufw allow 61208/tcp

   # Check firewall (RHEL/CentOS)
   sudo firewall-cmd --list-ports
   sudo firewall-cmd --add-port=61208/tcp --permanent
   sudo firewall-cmd --reload
   ```

4. **Binding to wrong interface:**
   ```bash
   # Bind to all interfaces (accessible remotely)
   glances -w --bind 0.0.0.0

   # Bind to specific interface
   glances -w --bind 192.168.1.100

   # Localhost only (default)
   glances -w --bind 127.0.0.1
   ```

### Problem: Connection Timeout

**Symptoms:**
```bash
curl: (28) Failed to connect to server.local port 61208 after 60000 ms: Operation timed out
```

**Solutions:**

1. **Check network connectivity:**
   ```bash
   # Ping the server
   ping server.local

   # Check port with netcat
   nc -zv server.local 61208

   # Check with telnet
   telnet server.local 61208
   ```

2. **Check DNS resolution:**
   ```bash
   # Try IP instead of hostname
   curl -s http://192.168.1.100:61208/api/4/status

   # Check DNS
   nslookup server.local
   ```

3. **Increase timeout:**
   ```bash
   # Add timeout to curl
   curl --max-time 30 -s "$GLANCES_URL/api/4/cpu"
   ```

## Authentication Issues

### Problem: Authentication Failed (401)

**Symptoms:**
```bash
HTTP/1.1 401 Unauthorized
```

**Solutions:**

1. **Check credentials:**
   ```bash
   # Test with explicit credentials
   curl -u username:password -s http://localhost:61208/api/4/cpu

   # Verify .env file contains GLANCES_URL, GLANCES_USERNAME, GLANCES_PASSWORD
   grep -E '^GLANCES_' ~/.homelab-skills/.env
   ```

2. **Glances started without authentication:**
   ```bash
   # Start glances with auth
   glances -w --username admin --password secret

   # Or use password file
   echo "secret" > /tmp/glances.pwd
   glances -w --username admin --password-file /tmp/glances.pwd
   ```

3. **URL encoding issues with special characters:**
   ```bash
   # Special characters in password need URL encoding
   # Example: password "p@ss:word" becomes "p%40ss%3Aword"
   curl -u "admin:p%40ss%3Aword" -s http://localhost:61208/api/4/cpu
   ```

### Problem: Forbidden (403)

**Symptoms:**
```bash
HTTP/1.1 403 Forbidden
```

**Solutions:**

1. **Check API key restrictions:**
   ```bash
   # Glances may have IP whitelist
   # Check glances config: ~/.config/glances/glances.conf

   # Restart without restrictions
   glances -w --disable-check-update
   ```

## Plugin Issues

### Problem: Plugin Not Available

**Symptoms:**
```json
{
  "error": "Plugin not available"
}
```

**Solutions:**

1. **List available plugins:**
   ```bash
   # Check what's actually available
   curl -s "$GLANCES_URL/api/4/pluginslist" | jq
   ```

2. **Plugin requires dependencies:**
   ```bash
   # Docker plugin needs Docker installed
   which docker

   # GPU plugin needs nvidia-smi or rocm-smi
   which nvidia-smi

   # SMART plugin needs smartctl
   which smartctl
   sudo apt install smartmontools  # Ubuntu/Debian
   sudo yum install smartmontools  # RHEL/CentOS
   ```

3. **Plugin disabled in config:**
   ```bash
   # Check glances config
   cat ~/.config/glances/glances.conf

   # Enable plugin (remove 'disable=True')
   # Then restart glances
   ```

4. **Permissions issue:**
   ```bash
   # Some plugins need root (e.g., SMART)
   sudo glances -w

   # Or add user to necessary groups
   sudo usermod -aG docker $USER    # For docker plugin
   sudo usermod -aG disk $USER      # For smart plugin
   ```

### Problem: Sensor Data Missing

**Symptoms:**
```json
[]
```

**Solutions:**

1. **Install sensor libraries:**
   ```bash
   # Ubuntu/Debian
   sudo apt install lm-sensors
   sudo sensors-detect  # Run sensor detection

   # RHEL/CentOS
   sudo yum install lm_sensors
   sudo sensors-detect
   ```

2. **Load kernel modules:**
   ```bash
   # List detected sensors
   sensors

   # If empty, load modules manually
   sudo modprobe coretemp  # Intel CPU temps
   sudo modprobe k10temp   # AMD CPU temps
   ```

3. **Virtual machine limitations:**
   ```bash
   # VMs often don't expose sensors
   # Check if running in VM
   systemd-detect-virt

   # Some hypervisors expose limited sensors
   # Try installing guest tools
   ```

4. **Permission to read sensors:**
   ```bash
   # Check sensor permissions
   ls -la /sys/class/hwmon/

   # May need root access
   sudo glances -w
   ```

## Performance Issues

### Problem: High CPU Usage from Glances

**Symptoms:**
- Glances process using > 20% CPU
- System feels sluggish

**Solutions:**

1. **Reduce refresh rate:**
   ```bash
   # Default is 2 seconds, increase to 5
   glances -w --time 5

   # Or 10 seconds for lighter load
   glances -w --time 10
   ```

2. **Disable expensive plugins:**
   ```bash
   # Disable specific plugins
   glances -w --disable-plugin docker,processlist,sensors

   # Enable only what you need
   glances -w --enable-plugin cpu,mem,network
   ```

3. **Limit process list:**
   ```bash
   # Default shows all processes, limit to top 25
   glances -w --process-short-name --max-processes 25
   ```

4. **Disable web UI:**
   ```bash
   # API-only mode (lighter)
   glances -w --disable-webui
   ```

### Problem: Slow API Responses

**Symptoms:**
- API calls take > 5 seconds
- Timeouts on queries

**Solutions:**

1. **Check server load:**
   ```bash
   # See if server is overloaded
   curl -s "$GLANCES_URL/api/4/load" | jq

   # Check glances CPU usage
   curl -s "$GLANCES_URL/api/4/processlist" | jq '.[] | select(.name | contains("glances"))'
   ```

2. **Query specific fields only:**
   ```bash
   # Instead of full plugin data
   curl -s "$GLANCES_URL/api/4/cpu"  # Slower

   # Get just what you need
   curl -s "$GLANCES_URL/api/4/cpu/total"  # Faster
   ```

3. **Avoid processlist with large process counts:**
   ```bash
   # Use processcount instead when possible
   curl -s "$GLANCES_URL/api/4/processcount"  # Fast

   # vs
   curl -s "$GLANCES_URL/api/4/processlist"  # Slow with 300+ processes
   ```

## Data Quality Issues

### Problem: Network Interface Not Showing

**Symptoms:**
- Expected interface missing from `/api/4/network`
- Only shows `lo` (loopback)

**Solutions:**

1. **Check interface exists:**
   ```bash
   # List all interfaces
   ip link show

   # Check if interface is up
   ip link show eth0
   ```

2. **Virtual interfaces may be filtered:**
   ```bash
   # Glances hides some virtual interfaces by default
   # Check glances config to show all

   # Or query specific interface
   curl -s "$GLANCES_URL/api/4/network" | jq '.[] | select(.interface_name == "eth0")'
   ```

3. **Permission to read network stats:**
   ```bash
   # Some systems need root for detailed network stats
   sudo glances -w
   ```

### Problem: Container Stats All Zero

**Symptoms:**
```json
{
  "cpu_percent": 0,
  "memory_usage": 0,
  "network_rx": 0
}
```

**Solutions:**

1. **Container just started:**
   ```bash
   # Wait a few seconds for stats to accumulate
   sleep 5
   curl -s "$GLANCES_URL/api/4/containers"
   ```

2. **Docker API version mismatch:**
   ```bash
   # Check Docker version
   docker version

   # Glances may need newer Docker
   # Update Docker or use older Glances
   ```

3. **Glances can't access Docker socket:**
   ```bash
   # Check socket permissions
   ls -la /var/run/docker.sock

   # Add glances user to docker group
   sudo usermod -aG docker glances

   # Or run as root
   sudo glances -w
   ```

### Problem: Disk I/O Shows Zero

**Symptoms:**
- `diskio` endpoint returns empty or zeros
- No read/write rates

**Solutions:**

1. **Check if disks are active:**
   ```bash
   # Manual disk I/O check
   iostat -x 1 5

   # If iostat shows activity but glances doesn't, restart glances
   ```

2. **Need sysstat package:**
   ```bash
   # Ubuntu/Debian
   sudo apt install sysstat

   # RHEL/CentOS
   sudo yum install sysstat

   # Restart glances
   ```

3. **Virtual disk limitations:**
   ```bash
   # Some VMs don't expose detailed I/O stats
   # Check hypervisor capabilities
   ```

## API Version Issues

### Problem: Endpoint Not Found (404)

**Symptoms:**
```bash
HTTP/1.1 404 Not Found
```

**Solutions:**

1. **Check API version:**
   ```bash
   # Try API v4 (current)
   curl -s http://localhost:61208/api/4/cpu

   # Try API v3 (older glances)
   curl -s http://localhost:61208/api/3/cpu

   # Check glances version
   glances --version
   ```

2. **Update glances:**
   ```bash
   # Ubuntu/Debian
   sudo apt update && sudo apt upgrade glances

   # Python pip
   pip install --upgrade glances

   # From source
   pip install --upgrade git+https://github.com/nicolargo/glances.git@develop
   ```

3. **Plugin not available in your version:**
   ```bash
   # Check what's available in your version
   curl -s http://localhost:61208/api/4/pluginslist | jq
   ```

## Common Configuration Issues

### Problem: Glances Won't Start in Server Mode

**Symptoms:**
```bash
glances: error: unrecognized arguments: -w
```

**Solutions:**

1. **Old glances version:**
   ```bash
   # Check version
   glances --version

   # Update to 3.x or newer
   pip install --upgrade glances
   ```

2. **Wrong glances binary:**
   ```bash
   # Check which glances is being used
   which glances

   # May have multiple installed
   /usr/bin/glances --version
   /usr/local/bin/glances --version

   # Use full path to correct one
   /usr/local/bin/glances -w
   ```

### Problem: Config File Not Loaded

**Symptoms:**
- Custom settings ignored
- Plugins still disabled despite config

**Solutions:**

1. **Check config location:**
   ```bash
   # Default locations (in order checked):
   # 1. ./glances.conf
   # 2. ~/.config/glances/glances.conf
   # 3. /etc/glances/glances.conf

   # Verify config syntax
   glances --config ~/.config/glances/glances.conf --test
   ```

2. **Specify config explicitly:**
   ```bash
   glances -w --config /path/to/glances.conf
   ```

3. **Config syntax errors:**
   ```bash
   # Check for typos in config
   # Common issues:
   # - Wrong section names [CPU] vs [cpu]
   # - Missing equals signs
   # - Invalid boolean values (use True/False, not true/false)
   ```

## Debugging Tips

### Enable Debug Mode

```bash
# Run glances with debug output
glances -w --debug

# Check logs
tail -f /var/log/glances.log

# Or use journalctl if running as service
journalctl -u glances -f
```

### Test API Manually

```bash
# Verbose curl for debugging
curl -v "$GLANCES_URL/api/4/status"

# Check response headers
curl -I "$GLANCES_URL/api/4/status"

# Save full response
curl -v "$GLANCES_URL/api/4/cpu" 2>&1 | tee /tmp/glances-debug.txt
```

### Check Glances Logs

```bash
# System logs
sudo journalctl -u glances.service -n 50

# Glances log file (if configured)
tail -f ~/.config/glances/glances.log

# System messages
dmesg | grep -i glances
```

### Validate JSON Responses

```bash
# Check if response is valid JSON
curl -s "$GLANCES_URL/api/4/cpu" | jq empty

# Pretty print to debug structure
curl -s "$GLANCES_URL/api/4/cpu" | jq . | less
```

## Platform-Specific Issues

### Docker Container Running Glances

**Problem: Container can't see host system:**

```bash
# Run with host network mode
docker run -it --net=host nicolargo/glances -w

# Or with host PID namespace
docker run -it --pid=host --net=host nicolargo/glances -w

# Mount docker socket to see containers
docker run -it --pid=host --net=host \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  nicolargo/glances -w
```

### systemd Service Issues

**Problem: Service won't start:**

```bash
# Check service status
sudo systemctl status glances

# View logs
sudo journalctl -u glances -xe

# Restart service
sudo systemctl restart glances

# Enable at boot
sudo systemctl enable glances
```

**Common systemd unit file:**
```ini
[Unit]
Description=Glances
After=network.target

[Service]
ExecStart=/usr/local/bin/glances -w --time 5 --disable-webui
Restart=on-failure
User=glances
Group=glances

[Install]
WantedBy=multi-user.target
```

### Remote Server Monitoring

**Problem: Can't connect to remote glances:**

```bash
# Check if port is open remotely
nmap -p 61208 server.local

# Test with SSH tunnel if firewall blocks
ssh -L 61208:localhost:61208 user@server.local
# Then connect to localhost:61208

# Or use glances client mode
glances -c server.local
```

## Getting Help

### Gather System Info for Bug Reports

```bash
# Glances version
glances --version

# System info
uname -a

# Python version
python3 --version

# Psutil version
python3 -c "import psutil; print(psutil.__version__)"

# Available plugins
curl -s "$GLANCES_URL/api/4/pluginslist" | jq

# Test specific endpoint
curl -v "$GLANCES_URL/api/4/problem-endpoint" 2>&1
```

### Useful Resources

- **Official Docs**: https://glances.readthedocs.io/
- **API Reference**: https://github.com/nicolargo/glances/wiki/The-Glances-RESTFULL-JSON-API
- **Issue Tracker**: https://github.com/nicolargo/glances/issues
- **Discussions**: https://github.com/nicolargo/glances/discussions

### Quick Diagnostic Script

```bash
#!/bin/bash
# Glances diagnostics script

GLANCES_URL="${GLANCES_URL:-http://localhost:61208}"

echo "=== Glances Diagnostics ==="
echo ""

echo "1. Check if glances is running:"
ps aux | grep -v grep | grep glances || echo "NOT RUNNING"
echo ""

echo "2. Check listening port:"
ss -tuln | grep 61208 || echo "NOT LISTENING"
echo ""

echo "3. Test API connection:"
curl -s --max-time 5 "$GLANCES_URL/api/4/status" && echo "API OK" || echo "API FAILED"
echo ""

echo "4. List available plugins:"
curl -s "$GLANCES_URL/api/4/pluginslist" | jq -r '.[]' 2>/dev/null || echo "FAILED"
echo ""

echo "5. Check glances version:"
glances --version 2>/dev/null || echo "glances command not found"
echo ""

echo "6. Test quick metrics:"
curl -s "$GLANCES_URL/api/4/quicklook" | jq . || echo "FAILED"
```

## Performance Tuning Recommendations

### Optimal Settings for Different Use Cases

**Low-resource systems:**
```bash
glances -w --time 10 \
  --disable-plugin docker,folders,raid,smart,sensors,gpu \
  --max-processes 10 \
  --disable-webui
```

**Production monitoring:**
```bash
glances -w --time 3 \
  --disable-webui \
  --quiet \
  --export json
```

**Development testing:**
```bash
glances -w --time 1 \
  --disable-check-update
```

**Container-focused:**
```bash
glances -w --time 5 \
  --enable-plugin cpu,mem,containers \
  --disable-webui
```
