# Nugs CLI Troubleshooting

Common issues and solutions for Nugs CLI.

## Installation & Setup Issues

### Binary Not Found

**Error:**
```
bash: nugs: command not found
```

**Cause:** Nugs CLI not in PATH or not executable.

**Solution:**
```bash
# Check if binary exists
ls -la /home/jmagar/workspace/nugs/nugs

# Make executable
chmod +x /home/jmagar/workspace/nugs/nugs

# Use full path
/home/jmagar/workspace/nugs/nugs --help

# Or add to PATH (add to ~/.bashrc or ~/.zshrc)
export PATH="$PATH:/home/jmagar/workspace/nugs"
```

### Config File Not Found

**Error:**
```
Config file not found. Create config.json at:
- ./config.json
- ~/.nugs/config.json
- ~/.config/nugs/config.json
```

**Cause:** No configuration file exists.

**Solution:**
```bash
# Create directory
mkdir -p ~/.nugs

# Create config
cat > ~/.nugs/config.json << EOF
{
  "email": "your-email@example.com",
  "password": "your-password",
  "outPath": "/path/to/downloads",
  "format": 2
}
EOF

# Secure permissions
chmod 600 ~/.nugs/config.json
```

### Config File Permissions Warning

**Warning:**
```
Warning: config.json has insecure permissions (0644)
Recommended: chmod 600 config.json
```

**Cause:** Config file is readable by other users (contains credentials).

**Solution:**
```bash
chmod 600 ~/.nugs/config.json
```

## Catalog Issues

### No Cache Found

**Error:**
```
No cache found - run 'nugs update' first
```

**Cause:** Catalog cache hasn't been initialized.

**Solution:**
```bash
# Update catalog (first time setup)
nugs update

# Verify cache exists
nugs cache

# Check cache files
ls -lh ~/.cache/nugs/
```

### Catalog Update Fails

**Error:**
```
Failed to fetch catalog: connection timeout
```

**Cause:** Network issue or Nugs.net servers down.

**Solution:**
```bash
# Check internet connection
ping nugs.net

# Try again later
nugs update

# Check Nugs.net status
curl -I https://play.nugs.net
```

### Stale Catalog Data

**Symptom:** Missing new releases or outdated show counts.

**Cause:** Catalog cache not updated recently.

**Solution:**
```bash
# Check cache age
nugs cache

# Update catalog
nugs update

# Enable auto-refresh
nugs refresh enable
```

### Cache Corruption

**Error:**
```
Failed to parse catalog: invalid JSON
```

**Cause:** Corrupted cache file.

**Solution:**
```bash
# Remove corrupt cache
rm -rf ~/.cache/nugs/

# Re-fetch catalog
nugs update
```

## Authentication Issues

### Invalid Credentials

**Error:**
```
Authentication failed: invalid email or password
```

**Cause:** Incorrect credentials in config.json.

**Solution:**
```bash
# Verify credentials
cat ~/.nugs/config.json | grep -E '(email|password)'

# Update credentials
nano ~/.nugs/config.json

# Test login
nugs update
```

### Token Authentication (Apple/Google)

**Error:**
```
Authentication failed: OAuth accounts not supported with password
```

**Cause:** Using password auth with Apple/Google account.

**Solution:**
Use token authentication instead. See: https://github.com/jmagar/nugs-cli/blob/main/token.md

```json
{
  "token": "your-auth-token-here",
  "outPath": "/path/to/downloads",
  "format": 2
}
```

### Session Expired

**Error:**
```
401 Unauthorized: session expired
```

**Cause:** Auth token expired (if using token auth).

**Solution:**
```bash
# Re-authenticate (will prompt for credentials)
nugs update

# Or regenerate token (if using token auth)
# See token.md for instructions
```

## Download Issues

### FFmpeg Not Found

**Error:**
```
FFmpeg not found in PATH or script directory
Required for video downloads and HLS audio
```

**Cause:** FFmpeg not installed or not in PATH.

**Solution (Linux):**
```bash
# Install FFmpeg
sudo apt install ffmpeg

# Verify installation
ffmpeg -version
```

**Solution (macOS):**
```bash
# Install via Homebrew
brew install ffmpeg

# Verify installation
ffmpeg -version
```

**Alternative Solution:**
```bash
# Download FFmpeg binary
# Place in same directory as nugs
cp /path/to/ffmpeg /home/jmagar/workspace/nugs/

# Update config to use local FFmpeg
{
  "useFfmpegEnvVar": false
}
```

### No Audio Available

**Error:**
```
No audio available for this release
```

**Cause:**
- Show is video-only
- Show not available on your subscription tier
- Show hasn't been encoded yet (very new releases)

**Solution:**
```bash
# Try forcing video
nugs grab --force-video <show_id>

# Check subscription level on Nugs.net
# Wait a few days if show is brand new
```

### Download Stalls

**Symptom:** Download starts but hangs at 0% or partway through.

**Causes:**
- Network connectivity issue
- Nugs.net server issue
- Firewall blocking download

**Solution:**
```bash
# Cancel download (Ctrl+C)
^C

# Check connectivity
ping play.nugs.net

# Try again
nugs grab <show_id>

# Check firewall rules
sudo iptables -L

# Try different network (if possible)
```

### Partial Downloads

**Symptom:** Download completes but files are incomplete or corrupted.

**Cause:** Network interruption during download.

**Solution:**
```bash
# Remove incomplete files
rm -rf "/path/to/incomplete/download"

# Re-download
nugs grab <show_id>

# Verify file integrity after download
file /path/to/download/*.flac
```

### Disk Space Full

**Error:**
```
Error writing file: no space left on device
```

**Cause:** Not enough disk space for download.

**Solution:**
```bash
# Check disk space
df -h /path/to/outPath

# Free up space
du -sh /path/to/outPath/* | sort -h

# Or change output path
nugs grab -o /mnt/other-drive <show_id>
```

## Gap Detection Issues

### Wrong Gap Results

**Symptom:** Gap detection shows shows you already have, or misses shows you don't have.

**Cause:** `outPath` doesn't match actual download location.

**Solution:**
```bash
# Check config
cat ~/.nugs/config.json | grep outPath

# Verify downloads are actually at that path
ls -la /path/from/config

# Update config if needed
nano ~/.nugs/config.json

# Re-run gap detection
nugs gaps <artist_id>
```

### Gaps Include Old/Deleted Shows

**Symptom:** Gap detection shows files you manually deleted.

**Cause:** Files were moved or deleted outside of nugs tool.

**Solution:**
Gap detection is always computed fresh based on current filesystem state. If it shows gaps, those files don't exist at the configured `outPath`.

```bash
# Verify actual file location
find /path/to/outPath -name "*artist*"

# Ensure outPath in config matches where files are
cat ~/.nugs/config.json | grep outPath
```

### Gap Detection Slow

**Symptom:** Gap detection takes a long time.

**Cause:** Large download directory or slow filesystem.

**Solution:**
```bash
# Use faster storage (SSD over HDD)
# Or be patient - it's scanning entire directory tree

# Consider organizing downloads by artist
outPath="/mnt/music/nugs"  # Better than deeply nested paths
```

## Rclone Issues

### Rclone Not Found

**Error:**
```
Rclone not found in PATH
Required when rcloneEnabled: true
```

**Cause:** Rclone not installed.

**Solution:**
```bash
# Install rclone
curl https://rclone.org/install.sh | sudo bash

# Verify installation
rclone version

# Configure remote
rclone config
```

### Upload Fails

**Error:**
```
Rclone upload failed: remote not found
```

**Cause:** Rclone remote not configured or wrong name in config.

**Solution:**
```bash
# List configured remotes
rclone listremotes

# Verify remote name in config matches
cat ~/.nugs/config.json | grep rcloneRemote

# Test remote
rclone ls remotename:

# Reconfigure if needed
rclone config
```

### Uploads Slow

**Symptom:** Uploads taking very long time.

**Cause:** Low bandwidth, server throttling, or too few transfers.

**Solution:**
```bash
# Increase parallel transfers in config
{
  "rcloneTransfers": 8
}

# Check bandwidth
rclone bandwidth remotename:

# Test transfer speed
rclone test remotename:
```

### Files Not Deleted After Upload

**Symptom:** Local files remain after successful upload (when `deleteAfterUpload: true`).

**Cause:** Upload actually failed (silently) or permission issue.

**Solution:**
```bash
# Check rclone logs
# Verify files on remote
rclone ls remotename:/path

# Manual cleanup (if verified on remote)
rm -rf /path/to/local/files

# Or disable auto-delete
{
  "deleteAfterUpload": false
}
```

## Performance Issues

### Slow Catalog Operations

**Symptom:** `nugs list` or `nugs stats` takes seconds.

**Cause:** Large catalog file on slow storage.

**Solution:**
```bash
# Move cache to faster storage (SSD)
mv ~/.cache/nugs /path/to/ssd/nugs-cache
ln -s /path/to/ssd/nugs-cache ~/.cache/nugs

# Or just wait - catalog is large (7-8MB)
```

### Slow Downloads

**Symptom:** Download speeds are very slow.

**Causes:**
- ISP throttling
- Nugs.net server congestion
- Poor network connection

**Solution:**
```bash
# Test network speed
speedtest-cli

# Try different time of day
# Check for ISP throttling
# Use VPN if throttled

# Parallel downloads not supported
# Downloads are sequential
```

## Auto-Refresh Issues

### Auto-Refresh Not Triggering

**Symptom:** Catalog not updating automatically.

**Cause:** Auto-refresh disabled or time not reached yet.

**Solution:**
```bash
# Check auto-refresh status
cat ~/.nugs/config.json | grep -A 4 catalogAutoRefresh

# Enable if disabled
nugs refresh enable

# Check when next refresh will run
nugs cache

# Manually trigger
nugs update
```

### Wrong Timezone

**Symptom:** Auto-refresh triggering at wrong time.

**Cause:** Timezone mismatch between config and system.

**Solution:**
```bash
# Check current timezone
cat ~/.nugs/config.json | grep catalogRefreshTimezone

# Reconfigure
nugs refresh set

# Or manually edit
{
  "catalogRefreshTimezone": "America/New_York"
}
```

## General Issues

### Command Not Recognized

**Error:**
```
Unknown command: <command>
```

**Cause:** Typo or invalid command.

**Solution:**
```bash
# Check available commands
nugs --help

# Common typos:
# "download" → "grab"
# "search" → "list"
# "refresh" → "update"
```

### JSON Parse Error

**Error:**
```
Failed to parse JSON output
```

**Cause:** Malformed JSON in response.

**Solution:**
```bash
# Report as bug with command that failed
# Try without --json flag
nugs list 1125

# Check catalog integrity
nugs update
```

### Unexpected Behavior

**Symptom:** Command does something unexpected.

**Solution:**
```bash
# Check version
nugs --version

# Update to latest
cd /home/jmagar/workspace/nugs
git pull
make build

# Clear cache and retry
rm -rf ~/.cache/nugs/
nugs update
```

## Getting Help

If you're still stuck after trying solutions above:

1. **Check the README:**
   - https://github.com/jmagar/nugs-cli/blob/main/README.md

2. **Check existing issues:**
   - https://github.com/jmagar/nugs-cli/issues

3. **Open a new issue:**
   Include:
   - Your OS and Go version
   - Full command you ran
   - Complete error message
   - Relevant config (redact credentials!)
   - Output of `nugs --version`

**Example Issue Report:**
```
**Environment:**
- OS: Ubuntu 22.04
- Go: 1.21
- Nugs CLI: v1.0.0

**Command:**
nugs grab 23329

**Error:**
FFmpeg not found in PATH or script directory

**Config:**
{
  "format": 2,
  "outPath": "/mnt/music",
  "useFfmpegEnvVar": true
}

**Expected:**
Download should work

**Actual:**
Fails with FFmpeg error
```

## Debug Mode

Enable debug output for troubleshooting:

```bash
# Set DEBUG environment variable
DEBUG=1 nugs grab 23329

# Or in config
{
  "debug": true
}
```

This will show detailed logs including:
- API requests/responses
- File operations
- Network activity
- Cache operations
