#!/bin/bash
# Download OpenAPI specifications for homelab services
# This script downloads publicly available OpenAPI specs and attempts to fetch
# specs from locally running instances of Sonarr, Radarr, and Prowlarr.

set -euo pipefail

BASE="/home/jmagar/workspace/homelab/skills"

# Create references directories if they don't exist
echo "Ensuring references directories exist..."
for service in overseerr sonarr radarr prowlarr gotify; do
  if [[ ! -d "$BASE/$service/references" ]]; then
    mkdir -p "$BASE/$service/references" || {
      echo "❌ Failed to create directory for $service"
      exit 1
    }
  fi
done
echo "✅ Directories ready"
echo ""

echo "Downloading OpenAPI specifications..."
echo ""

# Overseerr - public GitHub
echo "Downloading Overseerr OpenAPI spec..."
if curl -sL https://raw.githubusercontent.com/sct/overseerr/develop/overseerr-api.yml \
  -o "$BASE/overseerr/references/overseerr-api.yml"; then
  echo "✅ Overseerr spec downloaded"
else
  echo "❌ Failed to download Overseerr spec"
fi

# Gotify - public GitHub
echo "Downloading Gotify Swagger spec..."
if curl -sL https://raw.githubusercontent.com/gotify/server/master/docs/spec.json \
  -o "$BASE/gotify/references/gotify-swagger.json"; then
  echo "✅ Gotify spec downloaded"
else
  echo "❌ Failed to download Gotify spec"
fi

# Sonarr - from running instance (requires local setup)
echo "Attempting to download Sonarr OpenAPI spec from local instance..."
if [[ -n "${SONARR_API_KEY:-}" ]]; then
  if curl -s "http://localhost:8989/api/v3/openapi.json" \
     -H "X-Api-Key: $SONARR_API_KEY" \
     -o "$BASE/sonarr/references/sonarr-openapi.json" 2>/dev/null; then
    echo "✅ Sonarr spec downloaded from local instance"
  else
    echo "⚠️  Sonarr OpenAPI not available (service not running or connection failed)"
  fi
else
  echo "⚠️  SONARR_API_KEY not set, skipping Sonarr spec download"
fi

# Radarr - from running instance
echo "Attempting to download Radarr OpenAPI spec from local instance..."
if [[ -n "${RADARR_API_KEY:-}" ]]; then
  if curl -s "http://localhost:7878/api/v3/openapi.json" \
     -H "X-Api-Key: $RADARR_API_KEY" \
     -o "$BASE/radarr/references/radarr-openapi.json" 2>/dev/null; then
    echo "✅ Radarr spec downloaded from local instance"
  else
    echo "⚠️  Radarr OpenAPI not available (service not running or connection failed)"
  fi
else
  echo "⚠️  RADARR_API_KEY not set, skipping Radarr spec download"
fi

# Prowlarr - from running instance
echo "Attempting to download Prowlarr OpenAPI spec from local instance..."
if [[ -n "${PROWLARR_API_KEY:-}" ]]; then
  if curl -s "http://localhost:9696/api/v1/openapi.json" \
     -H "X-Api-Key: $PROWLARR_API_KEY" \
     -o "$BASE/prowlarr/references/prowlarr-openapi.json" 2>/dev/null; then
    echo "✅ Prowlarr spec downloaded from local instance"
  else
    echo "⚠️  Prowlarr OpenAPI not available (service not running or connection failed)"
  fi
else
  echo "⚠️  PROWLARR_API_KEY not set, skipping Prowlarr spec download"
fi

echo ""
echo "Download complete!"
echo ""
echo "Summary:"
echo "- Public specs: Overseerr, Gotify"
echo "- Local instances: Sonarr, Radarr, Prowlarr (requires API keys and running services)"
