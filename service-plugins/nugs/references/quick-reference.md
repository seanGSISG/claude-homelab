# Nugs CLI Quick Reference

Quick copy-paste commands for common operations.

## Download Shows

```bash
# Single show
nugs grab 23329              # Respects defaultOutputs
nugs grab 23329 both         # Both audio and video

# Multiple shows
nugs grab 23329 23790 24105

# From file
nugs shows.txt

# Artist latest
nugs grab 1125 latest        # Respects defaultOutputs
nugs grab 1125 latest video  # Videos only

# Entire artist catalog
nugs 1125 full               # Respects defaultOutputs
nugs 1125 full video         # Videos only
nugs 1125 full both          # Both formats

# Override quality
nugs grab -f 3 23329         # MQA audio
nugs grab -F 5 video-url     # 4K video
```

## Browse & Search

```bash
# List all artists
nugs list                    # With 🎵🎬📹 indicators
nugs list video              # Only artists with video
nugs list audio              # Only artists with audio

# Filter by show count
nugs list ">100"
nugs list "<=50"

# Artist's shows
nugs list 1125               # All shows with media indicators
nugs list 1125 video         # Video shows only
nugs list 1125 audio         # Audio shows only
nugs list 1125 both          # Shows with both formats

# Filter by venue
nugs list 461 "Red Rocks"
nugs list 461 video "Red Rocks"  # Video shows at Red Rocks

# Latest N shows
nugs list 1125 latest 5
```

## Catalog Management

```bash
# Update catalog
nugs update

# View cache status
nugs cache

# Show statistics
nugs stats

# Latest additions
nugs latest                  # Last 15 with media indicators
nugs latest 50               # Last 50
nugs latest video            # Latest videos only
nugs latest 25 audio         # Latest 25 audio shows
```

## Gap Detection

```bash
# Find missing shows
nugs gaps 1125               # Respects defaultOutputs
nugs gaps 1125 video         # Video gaps only
nugs gaps 1125 audio         # Audio gaps only
nugs gaps 1125 both          # Shows missing either format

# Multiple artists
nugs gaps 1125 461 1045

# IDs only
nugs gaps 1125 --ids-only
nugs gaps 1125 video --ids-only  # Video gaps only

# Auto-download gaps
nugs gaps 1125 fill          # Respects defaultOutputs
nugs gaps 1125 fill video    # Fill video gaps
nugs gaps 1125 fill both     # Fill both-format gaps

# Download first 10 gaps
nugs gaps 1125 --ids-only | head -10 | xargs -n1 nugs grab

# Download all video gaps
nugs gaps 1125 video --ids-only | xargs -n1 nugs grab video

# Parallel downloads
nugs gaps 1125 --ids-only | xargs -P 3 -n1 nugs grab
```

## Coverage Tracking

```bash
# All artists (respects defaultOutputs)
nugs coverage

# By media type
nugs coverage video          # Video coverage for all
nugs coverage audio          # Audio coverage for all

# Specific artists
nugs coverage 1125           # Respects defaultOutputs
nugs coverage 1125 video     # Video coverage only
nugs coverage 1125 audio     # Audio coverage only
nugs coverage 1125 both      # Both formats coverage

# Multiple artists
nugs coverage 1125 461 1045
```

## Auto-Refresh

```bash
# Enable
nugs refresh enable

# Disable
nugs refresh disable

# Configure
nugs refresh set
```

## JSON Output

```bash
# Any catalog command
nugs list --json standard
nugs stats --json extended
nugs gaps 1125 --json minimal

# Pipe to jq
nugs list 1125 --json standard | jq '.shows[:5]'
```

## Common Workflows

### Download All Red Rocks Shows

```bash
# Find shows
nugs list 461 "Red Rocks"

# Get IDs with jq
nugs list 461 --json standard | \
  jq -r '.shows[] | select(.venue | contains("Red Rocks")) | .containerID' | \
  xargs -n1 nugs grab
```

### Fill All Gaps for Favorite Artists

```bash
# Billy Strings
nugs gaps 1125 fill

# Grateful Dead
nugs gaps 461 fill

# Phish
nugs gaps 1045 fill
```

### Monitor Collection Progress

```bash
# Update catalog
nugs update

# Check coverage
nugs coverage 1125 461 1045

# Find gaps
nugs gaps 1125
```

### Batch Download from List

```bash
# Create list
cat > shows.txt << EOF
23329
23790
24105
EOF

# Download
nugs shows.txt
```

## Common Artist IDs

```
1125  - Billy Strings
461   - Grateful Dead
1045  - Phish
22    - Umphrey's McGee
1084  - Spafford
1299  - Dead & Company
1046  - Widespread Panic
4     - The String Cheese Incident
```

## Configuration Snippets

### Basic Config (~/.nugs/config.json)

```json
{
  "email": "your-email@example.com",
  "password": "your-password",
  "outPath": "/mnt/music/nugs",
  "format": 2,
  "videoFormat": 3,
  "defaultOutputs": "audio"
}
```

### Video-First Config

```json
{
  "email": "your-email@example.com",
  "password": "your-password",
  "outPath": "/mnt/storage/nugs",
  "format": 2,
  "videoFormat": 5,
  "defaultOutputs": "video"
}
```

### Both Formats Config

```json
{
  "email": "your-email@example.com",
  "password": "your-password",
  "outPath": "/mnt/storage/nugs",
  "format": 2,
  "videoFormat": 3,
  "defaultOutputs": "both"
}
```

### With Rclone

```json
{
  "email": "your-email@example.com",
  "password": "your-password",
  "outPath": "/mnt/music/nugs",
  "format": 2,
  "rcloneEnabled": true,
  "rcloneRemote": "gdrive",
  "rclonePath": "/Music/Nugs",
  "deleteAfterUpload": false
}
```

### With Auto-Refresh

```json
{
  "email": "your-email@example.com",
  "password": "your-password",
  "outPath": "/mnt/music/nugs",
  "format": 2,
  "catalogAutoRefresh": true,
  "catalogRefreshTime": "05:00",
  "catalogRefreshTimezone": "America/New_York",
  "catalogRefreshInterval": "daily"
}
```

## Shell Aliases

Add to your `.bashrc` or `.zshrc`:

```bash
# Nugs shortcuts
alias ng='nugs'
alias ngg='nugs grab'
alias ngl='nugs list'
alias ngu='nugs update'
alias ngc='nugs coverage'
alias ngap='nugs gaps'

# Billy Strings shortcuts
alias bs-latest='nugs grab 1125 latest'
alias bs-gaps='nugs gaps 1125'
alias bs-fill='nugs gaps 1125 fill'

# Grateful Dead shortcuts
alias gd-latest='nugs grab 461 latest'
alias gd-gaps='nugs gaps 461'
alias gd-fill='nugs gaps 461 fill'
```

## One-Liners

```bash
# Download all gaps for multiple artists
for artist in 1125 461 1045; do nugs gaps $artist fill; done

# Get total show count
nugs stats --json standard | jq '.totalShows'

# List artists with 200+ shows
nugs list --json standard | jq '.artists[] | select(.showCount >= 200) | .name'

# Download latest from top 5 artists
nugs stats --json standard | jq -r '.topArtists[:5].id' | xargs -n1 nugs grab latest

# Check coverage across all downloaded artists
nugs coverage | grep -E "[0-9]+\.[0-9]+%"
```
