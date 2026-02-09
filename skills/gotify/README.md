# Gotify Skill

Send push notifications via Gotify from Clawdbot.

## What It Does

- **Push notifications** — send alerts to your phone/desktop
- **Priority levels** — control notification importance (0-10)
- **Markdown support** — rich formatted notifications
- **Task completion** — notify when long-running tasks finish

## Setup

### 1. Create an Application Token

1. Open your Gotify web UI
2. Go to **Apps** tab
3. Click **Create Application**
4. Copy the generated **Token**

### 2. Add Credentials to .env

Add the following to `~/claude-homelab/.env`:

```bash
GOTIFY_URL="https://gotify.example.com"
GOTIFY_TOKEN="your-app-token-here"
```

- `GOTIFY_URL`: Your Gotify server URL (no trailing slash)
- `GOTIFY_TOKEN`: Application token from Gotify

### 3. Test It

```bash
bash scripts/send.sh "Hello from Clawdbot!"
```

## Usage Examples

### Basic notification

```bash
bash scripts/send.sh "Task completed successfully"
```

### With title

```bash
bash scripts/send.sh --title "Build Complete" --message "All tests passed"
# Or shorthand:
bash scripts/send.sh -t "Build Complete" -m "All tests passed"
```

### With priority

```bash
# High priority (triggers sound/vibration)
bash scripts/send.sh -t "Critical Alert" -m "Service down" -p 10

# Low priority (silent)
bash scripts/send.sh -m "Background task done" -p 2
```

Priority levels:
- **0-3**: Low (silent)
- **4-7**: Normal (default: 5)
- **8-10**: High (may trigger sound/vibration)

### Markdown formatting

```bash
bash scripts/send.sh --markdown -t "Deploy Summary" -m "
## Deployment Complete

- **Status**: ✅ Success
- **Duration**: 2m 34s
- **Commits**: 5 new
"
```

### Integration with commands

```bash
# Notify when a command finishes
./deploy.sh && bash scripts/send.sh "Deploy finished"

# Notify on error
./critical-task.sh || bash scripts/send.sh -t "⚠️ Failure" -m "Task failed" -p 10
```

## Parameters

| Flag | Description |
|------|-------------|
| `-m, --message` | Notification message (required) |
| `-t, --title` | Notification title (optional) |
| `-p, --priority` | Priority 0-10 (default: 5) |
| `--markdown` | Enable markdown formatting |

## Credentials Management

Gotify uses centralized `.env` file at `~/claude-homelab/.env` for credential management.

**Required variables:**
```bash
GOTIFY_URL="https://gotify.example.com"
GOTIFY_TOKEN="your-app-token"
```

## API Reference

Detailed documentation is available in the `references/` directory:

- **[Quick Reference](./references/quick-reference.md)** - Common patterns and copy-paste examples
- **[API Endpoints](./references/api-endpoints.md)** - Complete endpoint reference
- **[Troubleshooting](./references/troubleshooting.md)** - Solutions for common issues

## Quick Troubleshooting

**"Gotify not configured"**
→ Check that `GOTIFY_URL` and `GOTIFY_TOKEN` are set in `~/claude-homelab/.env`

**Connection refused**
→ Verify your Gotify server URL is correct

**401 Unauthorized**
→ Your token is invalid — create a new app in Gotify

For detailed troubleshooting, see **[references/troubleshooting.md](./references/troubleshooting.md)**

## License

MIT
