# Gotify Troubleshooting Guide

Common issues and solutions when working with Gotify notifications.

## Authentication Issues

### Invalid App Token Errors

**Symptom:**
```
Error: 401 Unauthorized
{"error":"Unauthorized","errorCode":401,"errorDescription":"you need to provide a valid access token"}
```

**Causes:**
1. Wrong token type (using client token instead of app token)
2. Token has been deleted in Gotify
3. Typo in token string

**Solutions:**

1. Verify you're using an **app token** (not client token):
   ```bash
   # Check your credentials
   source ~/claude-homelab/.env
   echo "GOTIFY_TOKEN: ${GOTIFY_TOKEN:0:10}..."
   ```

2. Generate a new app token:
   - Open Gotify web UI
   - Go to **Apps** tab
   - Click **Create Application**
   - Name it (e.g., "Homelab Scripts")
   - Copy the new token
   - Update your config file

3. Update the `.env` file:
   ```bash
   vi ~/claude-homelab/.env
   # Update GOTIFY_TOKEN with the new token
   ```

4. Test the new token:
   ```bash
   # Load credentials
   source ~/claude-homelab/.env

   # Test connection
   curl -s "$GOTIFY_URL/version"
   ```

### Missing Configuration

**Symptom:**
```
ERROR: GOTIFY_URL and GOTIFY_TOKEN must be set in .env
```

**Solution:**

Add credentials to `.env` file:
```bash
# Edit .env
vi ~/claude-homelab/.env

# Add these lines:
GOTIFY_URL="https://gotify.example.com"
GOTIFY_TOKEN="your-app-token-here"
```

Verify the credentials are set:
```bash
# Source .env
source ~/claude-homelab/.env

# Check variables
echo "URL: $GOTIFY_URL"
echo "Token: ${GOTIFY_TOKEN:0:10}..."  # Show first 10 chars only
```

## Connection Issues

### Connection Refused

**Symptom:**
```
curl: (7) Failed to connect to localhost port 8080: Connection refused
```

**Causes:**
1. Gotify server is not running
2. Wrong URL/port in config
3. Firewall blocking connection
4. Docker container stopped

**Solutions:**

1. Check if Gotify is running:
   ```bash
   # If using Docker
   docker ps | grep gotify

   # If systemd service
   systemctl status gotify
   ```

2. Verify the correct URL:
   ```bash
   # Test connectivity
   curl -I https://gotify.example.com

   # Or for local instance
   curl -I http://localhost:8080
   ```

3. Check Docker logs:
   ```bash
   docker logs gotify
   ```

4. Restart Gotify:
   ```bash
   # Docker
   docker restart gotify

   # Systemd
   systemctl restart gotify
   ```

### SSL Certificate Issues

**Symptom:**
```
curl: (60) SSL certificate problem: unable to get local issuer certificate
```

**Solutions:**

1. For self-signed certificates, use `-k` flag (not recommended for production):
   ```bash
   curl -k -X POST "$GOTIFY_URL/message?token=$GOTIFY_TOKEN" ...
   ```

2. Or add certificate to system trust store:
   ```bash
   # Copy certificate
   sudo cp gotify.crt /usr/local/share/ca-certificates/
   sudo update-ca-certificates
   ```

3. Use HTTP instead of HTTPS in `.env` (only for local testing):
   ```bash
   GOTIFY_URL="http://gotify.example.com"
   GOTIFY_TOKEN="your-token"
   ```

### Network Timeout

**Symptom:**
```
curl: (28) Operation timed out after 30000 milliseconds
```

**Solutions:**

1. Check network connectivity:
   ```bash
   ping gotify.example.com
   ```

2. Verify firewall rules:
   ```bash
   # Check if port is open
   nc -zv gotify.example.com 443
   ```

3. Increase timeout in script:
   ```bash
   curl --max-time 60 -X POST "$GOTIFY_URL/message?token=$GOTIFY_TOKEN" ...
   ```

## Notification Delivery Issues

### Messages Not Appearing on Client

**Symptom:**
- API returns success (200 OK)
- Message appears in web UI
- No notification on mobile/desktop app

**Causes:**
1. Client not connected to server
2. Priority too low (silent notification)
3. Client app notifications disabled
4. Do Not Disturb mode enabled

**Solutions:**

1. Check client connection:
   ```bash
   # Get all clients
   curl -s "$GOTIFY_URL/client?token=$GOTIFY_TOKEN" | jq
   ```

2. Verify client app is connected:
   - Open Gotify app
   - Check connection status (should show "Connected")
   - Reconnect if necessary

3. Increase message priority:
   ```bash
   # Use priority 8-10 for important notifications
   bash scripts/send.sh -t "Test" -m "High priority test" -p 10
   ```

4. Check app notification settings:
   - Android: Settings → Apps → Gotify → Notifications → Enable
   - iOS: Settings → Notifications → Gotify → Allow Notifications

### Priority Not Affecting Notification Behavior

**Symptom:**
- All notifications have same sound/vibration
- Priority levels don't change notification behavior

**Causes:**
1. Client app doesn't support priority levels
2. System notification settings override app settings
3. Old client version

**Solutions:**

1. Update Gotify client app to latest version

2. Configure Android notification channels:
   - Settings → Apps → Gotify → Notifications
   - Configure each priority channel separately

3. Test with explicit priority values:
   ```bash
   # Silent notification
   bash scripts/send.sh -m "Low priority" -p 1

   # Normal notification
   bash scripts/send.sh -m "Normal priority" -p 5

   # Alert notification
   bash scripts/send.sh -m "High priority" -p 10
   ```

### Markdown Not Rendering

**Symptom:**
- Markdown syntax appears as plain text
- No formatting in notification

**Causes:**
1. Markdown extras not included in message
2. Old client version
3. Client doesn't support markdown

**Solutions:**

1. Include markdown extras in API call:
   ```bash
   curl -X POST "$GOTIFY_URL/message?token=$GOTIFY_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "title": "Test",
       "message": "## Heading\n\n- Item 1\n- Item 2",
       "priority": 5,
       "extras": {
         "client::display": {
           "contentType": "text/markdown"
         }
       }
     }'
   ```

2. Use script with `--markdown` flag:
   ```bash
   bash scripts/send.sh --markdown -t "Test" -m "## Heading\n\n- Item 1"
   ```

3. Update client app to version that supports markdown

4. Test markdown rendering:
   ```bash
   bash scripts/send.sh --markdown -t "Markdown Test" -m "
   # Heading 1
   ## Heading 2

   **Bold** and *italic*

   - List item 1
   - List item 2

   \`code block\`
   "
   ```

## Rate Limiting Issues

### Too Many Requests

**Symptom:**
```
Error: 429 Too Many Requests
{"error":"Rate limit exceeded"}
```

**Causes:**
1. Sending too many notifications in short time
2. Script in infinite loop
3. Multiple scripts sending simultaneously

**Solutions:**

1. Add delay between notifications:
   ```bash
   for i in {1..10}; do
     bash scripts/send.sh "Notification $i"
     sleep 1  # Wait 1 second between messages
   done
   ```

2. Batch notifications:
   ```bash
   # Instead of 10 separate messages
   bash scripts/send.sh --markdown -m "
   ## Results

   $(for i in {1..10}; do echo "- Item $i"; done)
   "
   ```

3. Check for stuck scripts:
   ```bash
   # Find processes sending notifications
   ps aux | grep send.sh

   # Kill stuck processes
   pkill -f send.sh
   ```

4. Increase Gotify rate limits (server-side):
   ```yaml
   # In Gotify config
   server:
     rateLimit:
       enabled: true
       requests: 100  # Increase if needed
       window: 60s
   ```

### Message Queue Overflow

**Symptom:**
- Old messages not appearing
- Only recent messages visible

**Causes:**
1. Too many messages stored
2. Storage limit reached

**Solutions:**

1. Delete old messages:
   ```bash
   # Delete all messages
   curl -X DELETE "$GOTIFY_URL/message?token=$GOTIFY_TOKEN"

   # Delete messages from specific app
   curl -X DELETE "$GOTIFY_URL/application/{APP_ID}/message?token=$GOTIFY_TOKEN"
   ```

2. Reduce message retention:
   ```bash
   # Configure in Gotify settings
   # Settings → General → Message Limit
   ```

## Script Errors

### jq Not Found

**Symptom:**
```
bash: jq: command not found
```

**Solution:**

Install jq:
```bash
# Ubuntu/Debian
sudo apt-get install jq

# CentOS/RHEL
sudo yum install jq

# macOS
brew install jq
```

### curl Not Found

**Symptom:**
```
bash: curl: command not found
```

**Solution:**

Install curl:
```bash
# Ubuntu/Debian
sudo apt-get install curl

# CentOS/RHEL
sudo yum install curl

# macOS (usually pre-installed)
brew install curl
```

### Permission Denied

**Symptom:**
```
bash: ./send.sh: Permission denied
```

**Solution:**

Make script executable:
```bash
chmod +x ~/claude-homelab/skills/gotify/scripts/send.sh
```

## Debugging Tips

### Enable Verbose Output

```bash
# Add -v flag to curl
curl -v -X POST "$GOTIFY_URL/message?token=$GOTIFY_TOKEN" ...
```

### Check Gotify Logs

```bash
# Docker
docker logs -f gotify

# Systemd
journalctl -u gotify -f
```

### Test with Minimal Example

```bash
# Simplest possible notification
curl -X POST "$GOTIFY_URL/message?token=$GOTIFY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"message":"test"}'
```

### Verify JSON Syntax

```bash
# Test your JSON payload
echo '{"message":"test","priority":5}' | jq
```

### Test Network Path

```bash
# Trace route to Gotify server
traceroute gotify.example.com

# Check DNS resolution
nslookup gotify.example.com

# Test HTTPS connection
openssl s_client -connect gotify.example.com:443
```

## Common Mistakes

### Using Client Token Instead of App Token

**Wrong:**
```bash
# This is a client token (for receiving messages)
GOTIFY_TOKEN="CMwu3nIasI.sldIw"
```

**Correct:**
```bash
# This is an app token (for sending messages)
GOTIFY_TOKEN="APoqQ2T0.RI3tOu"
```

**How to tell the difference:**
- App tokens: Used to **send** messages (POST /message)
- Client tokens: Used to **receive** messages (GET /stream)
- Create app tokens in: Gotify UI → **Apps** tab
- Create client tokens in: Gotify UI → **Clients** tab

### Trailing Slash in URL

**Wrong:**
```bash
GOTIFY_URL="https://gotify.example.com/"  # Trailing slash
```

**Correct:**
```bash
GOTIFY_URL="https://gotify.example.com"  # No trailing slash
```

### Incorrect Message Format

**Wrong:**
```bash
# Missing Content-Type header
curl -X POST "$GOTIFY_URL/message?token=$GOTIFY_TOKEN" \
  -d '{"message":"test"}'
```

**Correct:**
```bash
# With Content-Type header
curl -X POST "$GOTIFY_URL/message?token=$GOTIFY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"message":"test"}'
```

## Getting Help

If you're still experiencing issues:

1. Check Gotify server logs
2. Test with minimal curl example
3. Verify token permissions
4. Update client apps to latest version
5. Review Gotify documentation: https://gotify.net/docs/

## Known Limitations

- Maximum message size: ~65KB
- Maximum messages stored: Configurable (default: 10,000 per app)
- WebSocket connections: Limited by server settings
- Markdown support: Requires modern client (Android v2.0+, iOS v1.0+)
