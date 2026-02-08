# Nugs CLI Command Reference

Complete reference for all Nugs CLI commands, flags, and arguments.

## Binary Location

Primary: `/home/jmagar/workspace/nugs/nugs`
Alternative: `~/.local/bin/nugs` (if installed via Make)

For convenience, examples below use `nugs` assuming it's in your PATH.

## Global Flags

These flags can be used with any command:

```bash
--format, -f <1-5>          Override audio format (1=ALAC, 2=FLAC, 3=MQA, 4=360RA, 5=AAC)
--videoformat, -F <1-5>     Override video format (1=480p, 2=720p, 3=1080p, 4=1440p, 5=4K)
--outpath, -o <path>        Override output directory
--force-video               Force video when audio+video available
--skip-videos               Skip videos in downloads
--skip-chapters             Skip chapter markers for videos
--json <level>              JSON output (minimal, standard, extended, raw)
--help, -h                  Show help message
```

## Media Type Modifiers

All catalog commands support media type modifiers as positional arguments:

```bash
audio                       Filter to audio-only shows
video                       Filter to video-only shows
both                        Filter to shows with both formats (or download both)
```

**Examples:**
```bash
nugs list video             # Artists with video content
nugs gaps 1125 video        # Video gaps for Billy Strings
nugs latest audio           # Latest audio releases
nugs coverage 1125 both     # Both-format coverage
```

## Download Commands

### Single Show Download

Download a show by ID or URL.

**Syntax:**
```bash
nugs grab <id|url>
nugs <id|url>
```

**Examples:**
```bash
# By ID
nugs grab 23329

# By URL
nugs grab https://play.nugs.net/release/23329

# Override format
nugs grab -f 3 23329              # MQA quality
nugs grab -F 5 video-url          # 4K video
nugs grab -o /mnt/music 23329     # Custom output
```

**Response:**
- Progress bars showing download status
- File paths where shows are saved
- Any errors or warnings

### Multiple Shows Download

Download multiple shows in one command.

**Syntax:**
```bash
nugs grab <id1> <id2> <id3> ...
```

**Examples:**
```bash
# Multiple shows
nugs grab 23329 23790 24105

# With format override
nugs grab -f 2 23329 23790 24105
```

### Batch Download from File

Download shows listed in a text file (one ID per line).

**Syntax:**
```bash
nugs <file_path>
```

**Examples:**
```bash
# Create file
cat > shows.txt << EOF
23329
23790
24105
EOF

# Download all
nugs shows.txt

# With overrides
nugs -f 3 -o /mnt/music shows.txt
```

### Artist Latest Shows

Download artist's most recent shows.

**Syntax:**
```bash
nugs grab <artist_id> latest
```

**Examples:**
```bash
# Billy Strings latest
nugs grab 1125 latest

# Grateful Dead latest
nugs grab 461 latest
```

**Response:**
- Downloads all shows marked as "latest" for that artist
- Typically 5-20 shows depending on artist
- Shows progress for each download

### Artist Full Catalog

Download entire artist catalog (all available shows).

**Syntax:**
```bash
nugs <artist_id> full
```

**Examples:**
```bash
# Billy Strings (430+ shows)
nugs 1125 full

# Grateful Dead (730+ shows)
nugs 461 full

# Skip videos
nugs --skip-videos 1125 full
```

**Response:**
- Progress through entire catalog
- May take hours for large catalogs
- Skips already downloaded shows

## List Commands

### List All Artists

Display all artists in the catalog with media type indicators.

**Syntax:**
```bash
nugs list [audio|video|both] [--json <level>]
```

**Examples:**
```bash
# All artists with media indicators
nugs list

# Only artists with video content
nugs list video

# Only artists with audio content
nugs list audio

# JSON output
nugs list --json standard
nugs list video --json extended
```

**Response:**
```
Total Artists: 335

  ID       Artist Name                           Show Count    Media
  ────────────────────────────────────────────────────────────────
  1125     Billy Strings                         430           🎵🎬📹
  22       Umphrey's McGee                       415           🎵
  1084     Spafford                              411           🎵🎬
  ...
```

**Media Indicators:**
- 🎵 Audio only
- 🎬 Video only
- 📹 Both audio and video available

### Filter Artists by Show Count

Filter artists using comparison operators.

**Syntax:**
```bash
nugs list <operator><count>
```

**Operators:**
- `>` - Greater than
- `<` - Less than
- `>=` - Greater than or equal
- `<=` - Less than or equal
- `=` - Equal to

**Examples:**
```bash
# More than 100 shows
nugs list ">100"

# 50 or fewer shows
nugs list "<=50"

# Exactly 25 shows
nugs list "=25"

# Between 100-200 shows (combine with jq)
nugs list --json standard | jq '.artists[] | select(.showCount >= 100 and .showCount <= 200)'
```

### List Artist Shows

Display all shows for a specific artist.

**Syntax:**
```bash
nugs list <artist_id> [--json <level>]
```

**Examples:**
```bash
# All Billy Strings shows
nugs list 1125

# JSON output
nugs list 1125 --json standard

# Pipe to jq for filtering
nugs list 1125 --json standard | jq '.shows[:10]'
```

**Response:**
```
Billy Strings - 430 shows

  ID       Date         Venue                    Location
  ────────────────────────────────────────────────────────────
  46385    12/14/25     ACL Live                 Austin, TX
  46380    12/13/25     The Criterion            Oklahoma City, OK
  ...
```

### Filter Shows by Venue

Filter artist's shows by venue name (case-insensitive substring match).

**Syntax:**
```bash
nugs list <artist_id> "<venue_substring>"
```

**Examples:**
```bash
# All Grateful Dead at Red Rocks
nugs list 461 "Red Rocks"

# All Billy Strings at Ryman (case-insensitive)
nugs list 1125 "ryman"

# Any artist at Madison Square Garden
nugs list 1045 "Madison Square"
```

### List Artist's Latest Shows

Show most recent N shows for an artist.

**Syntax:**
```bash
nugs list <artist_id> latest <N>
```

**Examples:**
```bash
# Latest 5 shows
nugs list 1125 latest 5

# Latest 10 shows
nugs list 461 latest 10

# With JSON
nugs list 1125 latest 5 --json standard
```

## Catalog Commands

### Update Catalog

Fetch latest catalog from Nugs.net and update local cache.

**Syntax:**
```bash
nugs update
```

**Examples:**
```bash
# Update catalog
nugs update
```

**Response:**
```
✓ Catalog updated successfully
  Total shows: 13,253
  Update time: 1 seconds
  Cache location: /home/user/.cache/nugs
```

**Cache Files Created:**
- `catalog.json` - Full show metadata (~7-8 MB)
- `by-artist.json` - Shows grouped by artist
- `by-date.json` - Shows sorted chronologically
- `catalog-meta.json` - Cache statistics

### View Cache Status

Display cache metadata and status.

**Syntax:**
```bash
nugs cache [--json <level>]
```

**Examples:**
```bash
# Human-readable
nugs cache

# JSON output
nugs cache --json standard
```

**Response:**
```
Catalog Cache Status:

  Location:     /home/user/.cache/nugs
  Last Updated: 2026-02-05 14:30:00 (2 hours ago)
  Total Shows:  13,253
  Artists:      335 unique
  Cache Size:   7.4 MB
  Version:      v1.0.0
```

### Catalog Statistics

Display catalog statistics (top artists, date ranges, counts).

**Syntax:**
```bash
nugs stats [--json <level>]
```

**Examples:**
```bash
# Human-readable
nugs stats

# JSON output
nugs stats --json standard

# Pipe to jq for custom stats
nugs stats --json standard | jq '.topArtists[:5]'
```

**Response:**
```
Catalog Statistics:

  Total Shows:    13,253
  Total Artists:  335 unique
  Date Range:     1965-01-01 to 2026-02-04

Top 10 Artists by Show Count:

  ID       Artist                    Shows
  ──────────────────────────────────────────
  1125     Billy Strings             430
  22       Umphrey's McGee           415
  1084     Spafford                  411
  ...
```

### Latest Additions

Show recently added shows to the catalog with media type indicators.

**Syntax:**
```bash
nugs latest [limit] [audio|video|both] [--json <level>]
```

**Examples:**
```bash
# Default (15 shows) with media indicators
nugs latest

# Last 50 shows
nugs latest 50

# Latest video releases only
nugs latest video

# Latest 25 audio shows
nugs latest 25 audio

# JSON output
nugs latest 25 --json standard
```

**Response:**
```
Latest 15 Shows in Catalog:

      Artist               Date        Title                      Media
   1. 🎬 Daniel Donato     02/03/26    02/03/26 Missoula, MT      Video
   2. 🎵 String Cheese...  07/18/00    07/18/00 Mt. Shasta, CA    Audio
   3. 📹 Dizgo             01/30/26    01/30/26 Columbus, OH      Both
   ...
```

## Gap Detection Commands

### Find Missing Shows

List shows from artist's catalog that you haven't downloaded.

**Syntax:**
```bash
nugs gaps <artist_id> [artist_id2 ...] [--ids-only] [--json <level>]
```

**Examples:**
```bash
# Single artist
nugs gaps 1125

# Multiple artists
nugs gaps 1125 461 1045

# IDs only for piping
nugs gaps 1125 --ids-only

# JSON output
nugs gaps 1125 --json standard
```

**Response:**
```
Missing Shows: Billy Strings (23 shows)

  ID       Date         Title
  ────────────────────────────────────────────────────────────
  46385    12/14/25     12/14/25 ACL Live Austin, TX
  46380    12/13/25     12/13/25 The Criterion Oklahoma City
  ...
```

**IDs Only Output:**
```
46385
46380
46375
...
```

**Detection Logic:**
- Checks `outPath` directory for existing downloads
- Checks rclone remote if configured
- Compares against catalog data
- Shows what's missing from your collection

### Auto-Download Missing Shows

Automatically download all missing shows for an artist.

**Syntax:**
```bash
nugs gaps <artist_id> fill
```

**Examples:**
```bash
# Fill all gaps for Billy Strings
nugs gaps 1125 fill

# Fill gaps for multiple artists (run separately)
nugs gaps 1125 fill
nugs gaps 461 fill
```

**Response:**
```
Filling Gaps: Billy Strings

  Total Missing:    23 shows

⬇ Downloading 1/23: 2025-12-14 - 12/14/25 ACL Live...
⬇ Downloading 2/23: 2025-12-13 - 12/13/25 The Criterion...
...

Download Summary:
  Total Attempted:         23
  Successfully Downloaded: 22
  Failed:                 1
```

**Behavior:**
- Downloads all missing shows sequentially
- Shows progress for each download
- Continues on errors (won't stop entire batch)
- Reports summary at end

### Integration Examples

**Download all gaps using pipe:**
```bash
# All gaps
nugs gaps 1125 --ids-only | xargs -n1 nugs grab

# First 10 gaps
nugs gaps 1125 --ids-only | head -10 | xargs -n1 nugs grab

# Parallel downloads (3 concurrent)
nugs gaps 1125 --ids-only | xargs -P 3 -n1 nugs grab

# Save gaps to file
nugs gaps 1125 --ids-only > billy-gaps.txt
```

## Coverage Commands

### Show Download Coverage

Display download coverage statistics for artists.

**Syntax:**
```bash
nugs coverage [artist_id1 artist_id2 ...] [--json <level>]
```

**Examples:**
```bash
# All artists with downloads (auto-detect)
nugs coverage

# Specific artist
nugs coverage 1125

# Multiple artists
nugs coverage 1125 461 1045

# JSON output
nugs coverage 1125 --json standard
```

**Response:**
```
Download Coverage Statistics

  Artist ID    Artist Name          Downloaded    Total    Coverage
  ────────────────────────────────────────────────────────────────
       1125    Billy Strings               23      430       5.3%
        461    Grateful Dead              195      734      26.6%
       1045    Phish                      142      892      15.9%
```

**Auto-Detection:**
- Scans `outPath` directory
- Identifies which artists you've downloaded
- Compares against catalog
- Shows progress toward complete collections

## Auto-Refresh Commands

### Enable Auto-Refresh

Enable automatic catalog updates on schedule.

**Syntax:**
```bash
nugs refresh enable
```

**Examples:**
```bash
# Enable with current settings
nugs refresh enable
```

**Response:**
```
✓ Auto-refresh enabled
  Schedule: Daily at 05:00 America/New_York
```

**Behavior:**
- Uses settings from config.json
- Triggers at startup if refresh time has passed
- Updates catalog automatically in background

### Disable Auto-Refresh

Disable automatic catalog updates.

**Syntax:**
```bash
nugs refresh disable
```

**Examples:**
```bash
# Disable auto-refresh
nugs refresh disable
```

**Response:**
```
✓ Auto-refresh disabled
  Manual updates only (run 'nugs update')
```

### Configure Auto-Refresh

Interactively configure auto-refresh schedule.

**Syntax:**
```bash
nugs refresh set
```

**Examples:**
```bash
# Interactive configuration
nugs refresh set

# Follow prompts:
# Enter refresh time (24-hour format): 03:00
# Enter timezone: America/Los_Angeles
# Enter interval (daily/weekly): weekly
```

**Response:**
```
✓ Auto-refresh configured
  Schedule: Weekly at 03:00 America/Los_Angeles
  Next refresh: 2026-02-09 03:00:00
```

**Configuration Options:**
- **Time:** 24-hour format (e.g., "05:00", "13:30")
- **Timezone:** IANA timezone (e.g., "America/New_York", "Europe/London")
- **Interval:** "daily" or "weekly"

## JSON Output Levels

All catalog commands support `--json <level>` flag:

### minimal
Essential fields only - compact output.

**Example:**
```json
{
  "artists": [
    {"id": 1125, "name": "Billy Strings", "showCount": 430}
  ]
}
```

### standard
Adds location and date details.

**Example:**
```json
{
  "artists": [
    {
      "id": 1125,
      "name": "Billy Strings",
      "showCount": 430,
      "shows": [
        {
          "containerID": 46385,
          "date": "2025-12-14",
          "venue": "ACL Live",
          "city": "Austin",
          "state": "TX"
        }
      ]
    }
  ]
}
```

### extended
All available metadata.

**Example:**
```json
{
  "artists": [
    {
      "id": 1125,
      "name": "Billy Strings",
      "showCount": 430,
      "firstShow": "2016-01-15",
      "latestShow": "2025-12-14",
      "shows": [
        {
          "containerID": 46385,
          "date": "2025-12-14",
          "title": "12/14/25 ACL Live Austin, TX",
          "venue": "ACL Live",
          "city": "Austin",
          "state": "TX",
          "country": "USA",
          "hasVideo": false,
          "formatAvailable": ["FLAC", "ALAC", "MQA"]
        }
      ]
    }
  ]
}
```

### raw
Unmodified API response from Nugs.net.

**Example:**
```json
{
  "_raw": {
    "status": "success",
    "data": { ... }
  }
}
```

## Exit Codes

- `0` - Success
- `1` - General error (auth, network, config)
- `2` - Invalid arguments or command
- `3` - File not found (config, catalog cache)

## Shell Completions

Install tab completions for your shell:

**Bash:**
```bash
sudo nugs completion bash > /etc/bash_completion.d/nugs
```

**Zsh:**
```bash
nugs completion zsh > ~/.zsh/completion/_nugs
```

**Fish:**
```bash
nugs completion fish > ~/.config/fish/completions/nugs.fish
```

**PowerShell:**
```powershell
nugs completion powershell >> $PROFILE
```

## Help Command

Get help for any command:

```bash
nugs --help
nugs help
nugs list --help
nugs gaps --help
```
