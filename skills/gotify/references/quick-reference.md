# Gotify Quick Reference

Common notification patterns for quick copy-paste usage.

## Setup

Add credentials to `~/claude-homelab/.env`:

```bash
GOTIFY_URL="https://gotify.example.com"
GOTIFY_TOKEN="your-app-token"
```

Scripts automatically load credentials from the `.env` file.

## Basic Notification Patterns

### Simple Message

```bash
curl -X POST "$GOTIFY_URL/message?token=$GOTIFY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Task completed successfully",
    "priority": 5
  }'
```

### With Title

```bash
curl -X POST "$GOTIFY_URL/message?token=$GOTIFY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Build Complete",
    "message": "All tests passed",
    "priority": 5
  }'
```

### Low Priority (Silent)

```bash
curl -X POST "$GOTIFY_URL/message?token=$GOTIFY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Background Task",
    "message": "Backup completed",
    "priority": 2
  }'
```

### High Priority (Alert)

```bash
curl -X POST "$GOTIFY_URL/message?token=$GOTIFY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "⚠️ Critical Alert",
    "message": "Service down - immediate attention required",
    "priority": 10
  }'
```

### Markdown Formatted Message

```bash
curl -X POST "$GOTIFY_URL/message?token=$GOTIFY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Deploy Summary",
    "message": "## Deployment Complete\n\n- **Status**: ✅ Success\n- **Duration**: 2m 34s\n- **Commits**: 5 new\n\n### Changed Services\n- API server\n- Worker pool",
    "priority": 5,
    "extras": {
      "client::display": {
        "contentType": "text/markdown"
      }
    }
  }'
```

## Using the Script Wrapper

### Basic Message

```bash
bash ~/workspace/homelab/skills/gotify/scripts/send.sh "Task completed"
```

### With Title and Priority

```bash
bash ~/workspace/homelab/skills/gotify/scripts/send.sh \
  -t "Build Complete" \
  -m "All tests passed" \
  -p 7
```

### Markdown Support

```bash
bash ~/workspace/homelab/skills/gotify/scripts/send.sh \
  --markdown \
  -t "Daily Report" \
  -m "
## System Status

### ✅ Healthy Services
- UniFi: 34 clients
- Sonarr: 1,175 shows
- Radarr: 2,551 movies

### 📊 Statistics
- Uptime: 621h
- Network: All OK
"
```

## Integration Patterns

### Task Completion Notification

```bash
# Notify on success
./deploy.sh && bash scripts/send.sh "Deploy finished"

# Notify on failure
./critical-task.sh || bash scripts/send.sh -t "⚠️ Failure" -m "Task failed" -p 10

# Notify regardless of result
./task.sh; bash scripts/send.sh -m "Task completed with exit code: $?"
```

### Batch Notifications

```bash
# Send multiple notifications
for service in api worker scheduler; do
  bash scripts/send.sh -t "Service Status" -m "$service: OK" -p 3
  sleep 1
done
```

### Error Alerting Pattern

```bash
#!/bin/bash
# error_handler.sh

send_alert() {
  local title="$1"
  local message="$2"
  local priority="${3:-10}"

  bash ~/workspace/homelab/skills/gotify/scripts/send.sh \
    -t "$title" \
    -m "$message" \
    -p "$priority"
}

# Usage in script
if ! systemctl is-active --quiet nginx; then
  send_alert "⚠️ Service Down" "nginx is not running" 10
fi
```

### Task Completion with Duration

```bash
#!/bin/bash
start_time=$(date +%s)

# Run your task
./long-running-task.sh

# Calculate duration
end_time=$(date +%s)
duration=$((end_time - start_time))

# Send notification with duration
bash scripts/send.sh \
  -t "Task Complete" \
  -m "Task finished in ${duration}s" \
  -p 5
```

### Monitoring Script Integration

```bash
#!/bin/bash
# check_disk_space.sh

THRESHOLD=90
USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')

if [ "$USAGE" -gt "$THRESHOLD" ]; then
  bash ~/workspace/homelab/skills/gotify/scripts/send.sh \
    -t "⚠️ Disk Space Alert" \
    -m "Root partition is ${USAGE}% full" \
    -p 10
fi
```

## Priority Level Guidelines

| Priority | Use Case | Behavior |
|----------|----------|----------|
| **0-1** | Debug/trace info | Silent, no notification |
| **2-3** | Background tasks | Silent, appears in history |
| **4-7** | Normal notifications | Standard notification (default: 5) |
| **8-9** | Important alerts | May trigger sound |
| **10** | Critical alerts | Triggers sound/vibration on most clients |

## Common Workflows

### Workflow: Deploy with Notification

```bash
#!/bin/bash
# deploy.sh

echo "Starting deployment..."

if docker compose up -d; then
  bash scripts/send.sh \
    -t "✅ Deploy Success" \
    -m "Application deployed successfully" \
    -p 5
else
  bash scripts/send.sh \
    -t "❌ Deploy Failed" \
    -m "Deployment failed - check logs" \
    -p 10
fi
```

### Workflow: Scheduled Job Notification

```bash
#!/bin/bash
# backup_and_notify.sh

backup_result=$(./backup.sh 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
  bash scripts/send.sh \
    -t "Backup Complete" \
    -m "Daily backup finished successfully" \
    -p 3
else
  bash scripts/send.sh \
    -t "⚠️ Backup Failed" \
    -m "Backup failed: $backup_result" \
    -p 10
fi
```

### Workflow: Multi-Step Process Notification

```bash
#!/bin/bash
# multi_step.sh

steps=("Pull code" "Build" "Test" "Deploy")
current_step=1
total_steps=${#steps[@]}

for step in "${steps[@]}"; do
  echo "Running: $step"

  # Run step (replace with actual command)
  sleep 2

  # Send progress notification
  bash scripts/send.sh \
    -t "Progress: $current_step/$total_steps" \
    -m "$step completed" \
    -p 3

  ((current_step++))
done

# Final notification
bash scripts/send.sh \
  -t "✅ All Steps Complete" \
  -m "All $total_steps steps finished successfully" \
  -p 5
```

## JSON Response Examples

### Success Response

```json
{
  "id": 12345,
  "appid": 1,
  "message": "Task completed successfully",
  "title": "Build Complete",
  "priority": 5,
  "date": "2026-02-02T10:30:00.000Z"
}
```

### Error Response

```json
{
  "error": "Unauthorized",
  "errorCode": 401,
  "errorDescription": "you need to provide a valid access token or user credentials to access this api"
}
```

## Testing Notifications

### Test Connection

```bash
curl -s "$GOTIFY_URL/version" | jq
```

### Test Authentication

```bash
curl -s "$GOTIFY_URL/message?token=$GOTIFY_TOKEN" \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"message":"Test notification","priority":5}' | jq
```

### Verify Message Delivery

```bash
# Send test message
response=$(curl -s "$GOTIFY_URL/message?token=$GOTIFY_TOKEN" \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"message":"Test","priority":5}')

# Check for message ID
message_id=$(echo "$response" | jq -r '.id')

if [ "$message_id" != "null" ]; then
  echo "✅ Message sent successfully: ID $message_id"
else
  echo "❌ Failed to send message"
  echo "$response" | jq
fi
```

## Credentials

All scripts automatically load credentials from `~/claude-homelab/.env`:

```bash
GOTIFY_URL="https://gotify.example.com"
GOTIFY_TOKEN="your-app-token"
```

**Security:**
- `.env` file is gitignored (never committed)
- Set permissions: `chmod 600 ~/claude-homelab/.env`
- Credentials are validated on script execution
