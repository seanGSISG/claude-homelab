# API Documentation Scripts

This directory contains scripts for creating and maintaining API reference documentation for homelab services.

## Scripts

### download-openapi-specs.sh

Downloads OpenAPI/Swagger specifications for services that provide them.

**Usage:**
```bash
./scripts/download-openapi-specs.sh
```

**What it does:**
- Downloads public OpenAPI specs for Overseerr and Gotify from GitHub
- Attempts to download specs from locally running instances of Sonarr, Radarr, and Prowlarr
- Creates references directories if they don't exist
- Provides clear status messages for each download

**Requirements:**
- `curl` installed
- For Sonarr/Radarr/Prowlarr: Services must be running and API keys must be set in environment:
  - `SONARR_API_KEY`
  - `RADARR_API_KEY`
  - `PROWLARR_API_KEY`

**Output:**
- `skills/overseerr/references/overseerr-api.yml`
- `skills/gotify/references/gotify-swagger.json`
- `skills/sonarr/references/sonarr-openapi.json` (if available)
- `skills/radarr/references/radarr-openapi.json` (if available)
- `skills/prowlarr/references/prowlarr-openapi.json` (if available)

---

### generate-api-docs.py

Parses OpenAPI specifications and generates markdown API reference documentation.

**Usage:**
```bash
python3 scripts/generate-api-docs.py <spec-file> <service-name>
```

**Examples:**
```bash
python3 scripts/generate-api-docs.py skills/overseerr/references/overseerr-api.yml "Overseerr"
python3 scripts/generate-api-docs.py skills/gotify/references/gotify-swagger.json "Gotify"
```

**What it does:**
- Parses OpenAPI YAML or JSON specifications
- Groups endpoints by functional category (OpenAPI tags)
- Generates markdown with:
  - Authentication details
  - Quick start section
  - Endpoints organized by category
  - Parameter tables
  - curl examples
  - Response codes
  - Version history

**Requirements:**
- Python 3.8+
- `pyyaml` module: `pip install pyyaml`

**Output:**
- Creates `api-endpoints.md` in the same directory as the spec file

---

### validate-api-docs.sh

Validates completeness and quality of API documentation.

**Usage:**
```bash
./scripts/validate-api-docs.sh
```

**What it checks:**
- References directories exist
- `api-endpoints.md` file exists
- Required sections present (Authentication, Base URL, Quick Start, Endpoints)
- Bash code blocks (curl examples) present
- Markdown formatting (if `markdownlint` is available)
- File size (warns if < 50 lines)
- Tier-appropriate files (quick-reference.md, troubleshooting.md for Tier 2/3)

**Exit codes:**
- `0` - All validations passed (or only warnings)
- `1` - Errors found

**Tiers:**
- **Tier 3** (Comprehensive): Overseerr, Sonarr, Radarr, Prowlarr
  - Requires: api-endpoints.md, quick-reference.md, troubleshooting.md
- **Tier 2** (Enhanced): qBittorrent, Plex
  - Requires: api-endpoints.md, quick-reference.md, troubleshooting.md
- **Tier 1** (Essential): Gotify, SABnzbd, Tailscale, Linkding
  - Requires: api-endpoints.md

---

## Workflow

### Generating Documentation

1. **Download OpenAPI specs** (if available):
   ```bash
   # Set API keys if services are running locally
   export SONARR_API_KEY="your-key"
   export RADARR_API_KEY="your-key"
   export PROWLARR_API_KEY="your-key"

   # Download specs
   ./scripts/download-openapi-specs.sh
   ```

2. **Generate markdown documentation**:
   ```bash
   # For services with OpenAPI specs
   python3 scripts/generate-api-docs.py skills/overseerr/references/overseerr-api.yml "Overseerr"
   python3 scripts/generate-api-docs.py skills/gotify/references/gotify-swagger.json "Gotify"

   # If Sonarr/Radarr/Prowlarr specs were downloaded:
   python3 scripts/generate-api-docs.py skills/sonarr/references/sonarr-openapi.json "Sonarr"
   python3 scripts/generate-api-docs.py skills/radarr/references/radarr-openapi.json "Radarr"
   python3 scripts/generate-api-docs.py skills/prowlarr/references/prowlarr-openapi.json "Prowlarr"
   ```

3. **Enhance generated docs**:
   - Replace generic examples with real data
   - Add practical workflows
   - Improve functional grouping
   - Add field explanations

4. **Create additional files** (Tier 2/3):
   - `quick-reference.md` - Common operations
   - `troubleshooting.md` - Common issues and solutions

5. **Validate documentation**:
   ```bash
   ./scripts/validate-api-docs.sh
   ```

### Manual Documentation

For services without OpenAPI specs (qBittorrent, Plex, SABnzbd, Tailscale, Linkding):

1. Read official API documentation
2. Test endpoints with curl
3. Document actual responses
4. Organize by functional categories
5. Follow the template in the main plan

---

## Testing

### Test OpenAPI Download
```bash
# Should download Overseerr and Gotify specs
./scripts/download-openapi-specs.sh

# Verify downloads
ls -lh skills/overseerr/references/overseerr-api.yml
ls -lh skills/gotify/references/gotify-swagger.json
```

### Test Documentation Generation
```bash
# Generate docs from Gotify spec (simpler test)
python3 scripts/generate-api-docs.py \
  skills/gotify/references/gotify-swagger.json \
  "Gotify"

# Check output
cat skills/gotify/references/api-endpoints.md
```

### Test Validation
```bash
# Run validation (will show errors for missing docs)
./scripts/validate-api-docs.sh
```

---

## Troubleshooting

### Download Script Issues

**"Failed to download Overseerr spec"**
- Check internet connection
- Verify GitHub is accessible
- Check if URL has changed (see plan for current URL)

**"Service not running or connection failed"** (Sonarr/Radarr/Prowlarr)
- Verify services are running: `systemctl status sonarr`
- Check ports are correct (default: Sonarr 8989, Radarr 7878, Prowlarr 9696)
- Verify API keys are set and valid

### Generation Script Issues

**"File not found"**
- Ensure OpenAPI spec was downloaded successfully
- Check file path is correct

**"Error parsing spec file"**
- Verify spec file is valid YAML/JSON
- Check file isn't corrupted or empty

**"Warning: Output seems short"**
- OpenAPI spec may be incomplete
- Check spec has `paths` section with endpoints

### Validation Script Issues

**"Missing references/ directory"**
- Run Phase 1 of plan to create directories
- Or create manually: `mkdir -p skills/SERVICE/references`

**"Missing api-endpoints.md"**
- Documentation hasn't been generated yet
- Run generation script or create manually

---

## Dependencies

### Required
- `bash` 4.0+
- `curl`
- `python3` 3.8+

### Optional
- `markdownlint` - For markdown validation
- `jq` - For JSON processing (not currently used but useful)

### Python Packages
```bash
# Required for generate-api-docs.py
pip install pyyaml

# Or using uv (preferred for this project)
uv pip install pyyaml
```

---

## Maintenance

### Updating OpenAPI Specs

To update specs when APIs change:

```bash
# Re-download specs
./scripts/download-openapi-specs.sh

# Re-generate documentation
python3 scripts/generate-api-docs.py <spec-file> <service-name>

# Manually merge with existing enhancements
# Preserve: examples, workflows, troubleshooting sections
```

### Adding New Services

1. Add service to `SERVICES` array in `validate-api-docs.sh`
2. If service has OpenAPI spec:
   - Add download logic to `download-openapi-specs.sh`
   - Run generation script
3. If service doesn't have OpenAPI spec:
   - Create documentation manually
   - Follow template in main plan

---

## See Also

- [Implementation Plan](../.config/21st-desktop/claude-sessions/ml4i5e8k8p7ngpy8/plans/sorted-frolicking-pond.md) - Full implementation details
- [AGENTS.md](../AGENTS.md) - Development guidelines for scripts
- [Unraid References](../skills/unraid/references/) - Example of Tier 3 documentation
- [UniFi References](../skills/unifi/references/) - Example of Tier 2 documentation
- [Glances References](../skills/glances/references/) - Example of Tier 1 documentation
