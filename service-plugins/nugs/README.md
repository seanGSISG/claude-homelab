# Nugs CLI Skill

Download and manage your live music collection from Nugs.net with this comprehensive skill for browsing, downloading, and tracking your concert library.

## What It Does

This skill provides complete access to Nugs.net's catalog of 13,000+ live concerts through the Nugs CLI tool:

**Catalog Management:**
- ✅ Browse entire Nugs.net catalog offline (no API calls)
- ✅ Search by artist, venue, date, or show count
- ✅ View catalog statistics and latest additions
- ✅ Auto-refresh catalog on schedule (daily/weekly)

**Gap Detection & Coverage:**
- ✅ Find missing shows in your collection
- ✅ Track download progress by artist
- ✅ Auto-download all missing shows with one command
- ✅ Smart detection (checks both local storage and cloud)

**Downloads:**
- ✅ Download shows by ID or URL
- ✅ Download artist's latest shows or entire catalog
- ✅ Batch downloads from files
- ✅ Multiple formats (ALAC, FLAC, MQA, 360RA, AAC, video)
- ✅ Rclone integration for automatic cloud uploads

**Formats Supported:**
- 🎵 Audio: 16-bit/44.1kHz ALAC, FLAC, 24-bit/48kHz MQA, 360 Reality Audio, AAC
- 🎬 Video: 480p, 720p, 1080p, 1440p, 4K (with chapter markers)
- 📹 Both: Download both audio and video formats for the same show

**Media Type Features:**
- **Default Preference:** Configure `defaultOutputs` (audio/video/both)
- **Visual Indicators:** Emoji symbols (🎵 🎬 📹) show what's available
- **Smart Filtering:** All commands support audio/video/both modifiers
- **Gap Detection:** Find missing shows by format type
- **Coverage Tracking:** Monitor collection by media type

## Setup

### Step 1: Install Nugs CLI

The Nugs CLI binary is already installed at `nugs`.

You can also build from source or download releases from: https://github.com/jmagar/nugs-cli

### Step 2: Create Configuration File

Create `~/.nugs/config.json` with your Nugs.net credentials:

```json
{
  "email": "your-email@example.com",
  "password": "your-password",
  "outPath": "/path/to/downloads",
  "format": 2,
  "videoFormat": 3,
  "defaultOutputs": "audio"
}
```

**Format Options:**
- **Audio Format:**
  - `1` = 16-bit/44.1kHz ALAC
  - `2` = 16-bit/44.1kHz FLAC (recommended)
  - `3` = 24-bit/48kHz MQA
  - `4` = 360 Reality Audio
  - `5` = 150 Kbps AAC

- **Video Format:**
  - `1` = 480p
  - `2` = 720p
  - `3` = 1080p (recommended)
  - `4` = 1440p
  - `5` = 4K/best available

- **Default Outputs:**
  - `audio` = Prefer audio downloads (default)
  - `video` = Prefer video downloads
  - `both` = Download both formats when available

### Step 3: Secure Your Config

```bash
chmod 600 ~/.nugs/config.json
```

### Step 4: Initialize Catalog

Update the local catalog cache (required for browsing):

```bash
nugs update
```

This downloads the catalog metadata (~7-8 MB) for offline browsing. The catalog contains 13,000+ shows and updates automatically (configurable).

### Optional: Rclone Integration

For automatic cloud uploads after downloads, add to your config:

```json
{
  "rcloneEnabled": true,
  "rcloneRemote": "gdrive",
  "rclonePath": "/Music/Nugs",
  "deleteAfterUpload": false,
  "rcloneTransfers": 4
}
```

First, set up rclone with your cloud provider:

```bash
# Install rclone
curl https://rclone.org/install.sh | sudo bash

# Configure a remote (follow prompts)
rclone config
```

## Usage Examples

### Example 1: Download Billy Strings Shows

**Download latest shows:**
```bash
nugs grab 1125 latest        # Respects defaultOutputs
nugs grab 1125 latest video  # Videos only
```

**Download specific show:**
```bash
nugs grab 23329       # Single format (respects defaultOutputs)
nugs grab 23329 both  # Both audio and video
```

**Download entire catalog (430+ shows):**
```bash
nugs 1125 full        # All shows (respects defaultOutputs)
nugs 1125 full video  # All videos only
```

### Example 2: Find Missing Shows

**Check what you're missing:**
```bash
nugs gaps 1125              # Respects defaultOutputs
nugs gaps 1125 video        # Video gaps only
nugs gaps 1125 both         # Shows missing either format
```

Output:
```
Missing Shows: Billy Strings - Video (12 shows)

  ID       Date         Title                                Media
  ──────────────────────────────────────────────────────────────
  46385    12/14/25     12/14/25 ACL Live Austin, TX       🎬
  46380    12/13/25     12/13/25 The Criterion Oklahoma... 🎬
  ...
```

**Download all missing shows:**
```bash
nugs gaps 1125 fill           # Fill gaps (respects defaultOutputs)
nugs gaps 1125 fill video     # Fill video gaps
```

**Or download selectively:**
```bash
# Get IDs only
nugs gaps 1125 video --ids-only

# Download first 10 video gaps
nugs gaps 1125 video --ids-only | head -10 | xargs -n1 nugs grab video

# Download in parallel (3 at once)
nugs gaps 1125 --ids-only | xargs -P 3 -n1 nugs grab
```

### Example 3: Search by Venue

**Find all Grateful Dead shows at Red Rocks:**
```bash
nugs list 461 "Red Rocks"        # All formats with 🎵🎬📹
nugs list 461 video "Red Rocks"  # Video shows only
```

**Filter shows by venue (case-insensitive):**
```bash
# Any artist at Ryman Auditorium
nugs list 1125 "ryman"       # All formats
nugs list 1125 video "ryman" # Video shows only
```

### Example 4: Check Collection Progress

**View download coverage for artists:**
```bash
nugs coverage 1125 461 1045        # Respects defaultOutputs
nugs coverage 1125 video           # Video coverage only
nugs coverage 1125 both            # Both formats coverage
```

Output:
```
Download Coverage Statistics (Video)

  Artist ID    Artist Name          Downloaded    Total    Coverage    Media
  ────────────────────────────────────────────────────────────────────────
       1125    Billy Strings               12      156       7.7%      🎬
        461    Grateful Dead               45      234      19.2%      🎬
       1045    Phish                       78      445      17.5%      🎬
```

### Example 5: Browse Catalog

**List all artists:**
```bash
nugs list            # All artists with 🎵🎬📹 indicators
nugs list video      # Only artists with video content
nugs list audio      # Only artists with audio content
```

**Filter by show count:**
```bash
# Artists with more than 100 shows
nugs list ">100"

# Artists with 50 or fewer shows
nugs list "<=50"
```

**View artist's shows:**
```bash
# All shows with media indicators
nugs list 1125

# Video shows only
nugs list 1125 video

# Latest 5 shows
nugs list 1125 latest 5
```

### Example 6: View Latest Additions

**See what's new on Nugs.net:**
```bash
# Last 15 shows (default) with media indicators
nugs latest

# Last 50 shows
nugs latest 50

# Latest video releases only
nugs latest video

# Latest 25 video releases
nugs latest 25 video
```

### Example 7: Batch Downloads

**Create a file with show IDs:**
```bash
cat > shows.txt << EOF
23329
23790
24105
EOF
```

**Download all:**
```bash
nugs shows.txt
```

### Example 8: Video-First Workflows

**Configure for video preference:**
```json
{
  "defaultOutputs": "video",
  "videoFormat": 5,
  "outPath": "/mnt/storage/nugs"
}
```

**Browse and download videos:**
```bash
# Find artists with video content
nugs list video

# View Billy Strings videos
nugs list 1125 video

# Download latest videos
nugs grab 1125 latest video

# Fill all video gaps
nugs gaps 1125 video fill

# Check video coverage
nugs coverage 1125 video
```

### Example 9: Both Formats Collection

**Download both audio and video:**
```bash
# Single show - both formats
nugs grab 46201 both

# Artist's latest - both formats
nugs grab 1125 latest both

# Fill gaps for both formats (shows where you have one but not the other)
nugs gaps 1125 both fill
```

**Check comprehensive coverage:**
```bash
# Audio coverage
nugs coverage 1125 audio

# Video coverage
nugs coverage 1125 video

# Shows with both formats
nugs coverage 1125 both
```

### Example 10: Advanced Filtering with JSON

**Get JSON output and filter with jq:**
```bash
# All shows at Red Rocks, download them
nugs list 1125 --json standard | \
  jq -r '.shows[] | select(.venue | contains("Red Rocks")) | .containerID' | \
  xargs -n1 nugs grab

# All video shows at Red Rocks
nugs list 1125 video --json standard | \
  jq -r '.shows[] | select(.venue | contains("Red Rocks")) | .containerID' | \
  xargs -n1 nugs grab video
```

## Workflow

### Common Scenarios

**Scenario 1: "I want to download all Billy Strings shows"**

1. Check how many shows exist:
   ```bash
   nugs list 1125
   ```

2. Download entire catalog:
   ```bash
   nugs 1125 full
   ```

3. Monitor progress and check coverage:
   ```bash
   nugs coverage 1125
   ```

**Scenario 2: "Find new shows since my last download"**

1. Update catalog:
   ```bash
   nugs update
   ```

2. Check latest additions:
   ```bash
   nugs latest
   ```

3. Find gaps in your collection:
   ```bash
   nugs gaps 1125
   ```

4. Download missing shows:
   ```bash
   nugs gaps 1125 fill
   ```

**Scenario 3: "Download specific venue's shows"**

1. Search by venue:
   ```bash
   nugs list 461 "Red Rocks"
   ```

2. Note the show IDs you want

3. Download them:
   ```bash
   nugs grab 23329 23790 24105
   ```

**Scenario 4: "Keep my collection up-to-date automatically"**

1. Enable auto-refresh (updates catalog daily):
   ```bash
   nugs refresh enable
   ```

2. Configure schedule (optional):
   ```bash
   nugs refresh set
   # Enter: 05:00 (time)
   # Enter: America/New_York (timezone)
   # Enter: daily (interval)
   ```

3. Use gap detection to find new shows:
   ```bash
   nugs gaps 1125
   ```

4. Download new shows automatically:
   ```bash
   nugs gaps 1125 fill
   ```

## Common Artist IDs

Quick reference for popular artists:

| Artist ID | Name | Show Count |
|-----------|------|------------|
| 1125 | Billy Strings | 430+ |
| 461 | Grateful Dead | 730+ |
| 1045 | Phish | 890+ |
| 22 | Umphrey's McGee | 415+ |
| 1084 | Spafford | 410+ |
| 1299 | Dead & Company | 180+ |
| 1046 | Widespread Panic | 890+ |
| 4 | The String Cheese Incident | 450+ |

Find more with:
```bash
nugs list --json standard | jq '.artists[] | {id, name, showCount}'
```

## Troubleshooting

### "No cache found - run 'nugs update' first"

**Cause:** Catalog cache hasn't been initialized.

**Solution:**
```bash
nugs update
```

### FFmpeg Not Found

**Cause:** FFmpeg not installed or not in PATH.

**Solution (Linux):**
```bash
sudo apt install ffmpeg
```

**Solution (macOS):**
```bash
brew install ffmpeg
```

**Alternative:** Download FFmpeg binary and place in same directory as `nugs`, then set in config:
```json
{
  "useFfmpegEnvVar": false
}
```

### Authentication Failed

**Cause:** Invalid credentials in config.

**Solution:**
1. Check email/password in `~/.nugs/config.json`
2. For Apple/Google accounts, use token authentication: https://github.com/jmagar/nugs-cli/blob/main/token.md

### "No audio available"

**Causes:**
- Show might be video-only
- Show not available on your subscription tier

**Solution:**
- Try with `--force-video` flag
- Check your Nugs.net subscription level

### Gap Detection Shows Wrong Results

**Solutions:**
1. Verify `outPath` in config matches your actual download location
2. Update catalog: `nugs update`
3. Check that files haven't been manually moved or renamed

### Rclone Upload Fails

**Solutions:**
1. Verify rclone is installed: `rclone version`
2. Test your remote: `rclone ls <remote_name>:`
3. Check remote name and path in config.json
4. Verify rclone remote is properly configured: `rclone config`

## Notes

**Catalog Auto-Refresh:**
- Enabled by default (runs at 5am EST daily)
- Keeps your catalog up-to-date with new releases
- Configurable: time, timezone, interval (daily/weekly)
- Runs at startup if refresh time has passed

**Download Behavior:**
- Existing files are skipped (no re-downloads)
- Failed downloads can be retried safely
- Downloads are sequential (no parallel downloads)
- Progress bars show download status

**Gap Detection:**
- Checks both local storage and rclone remote
- Based on `outPath` configuration
- Updates as you download (dynamic tracking)
- Works with multi-artist queries

**Storage Considerations:**
- FLAC shows: ~500-800 MB per show
- Video shows: 2-10 GB per show (depends on quality/length)
- Catalog cache: ~7-8 MB
- Use rclone to offload to cloud storage

**Performance:**
- Catalog operations: Instant (local cache)
- Downloads: Depends on internet speed
- Large catalogs (500+ shows): Hours to download
- Batch processing: Sequential, not parallel

**Permissions:**
- Requires active Nugs.net subscription
- Some shows require higher subscription tiers
- Only download content you have legal access to
- Respect copyright and terms of service

**Security:**
- Config file contains plaintext credentials
- Always use `chmod 600 ~/.nugs/config.json`
- Never commit config to version control
- Consider using token authentication for OAuth accounts

## Reference

**Official Documentation:**
- GitHub: https://github.com/jmagar/nugs-cli
- README: Complete user guide with examples
- CLAUDE.md: Development guide and architecture

**Binary Location:**
- Installed at: `nugs`
- Also available as: `~/.local/bin/nugs` (if installed via Make)

**Configuration:**
- Primary: `~/.nugs/config.json` (recommended)
- Alternative 1: `./config.json` (current directory)
- Alternative 2: `~/.config/nugs/config.json` (XDG standard)

**Cache Location:**
- Directory: `~/.cache/nugs/`
- Files: `catalog.json`, `by-artist.json`, `by-date.json`, `catalog-meta.json`
- Size: ~7-8 MB
- Contents: 13,000+ show metadata

**Shell Completions:**
- Available for bash, zsh, fish, powershell
- Install with: `nugs completion <shell>`
- See README for detailed setup instructions

**Support:**
- Issues: https://github.com/jmagar/nugs-cli/issues
- Discussions: Ask questions in repository discussions
- Documentation: Check README and CLAUDE.md first
