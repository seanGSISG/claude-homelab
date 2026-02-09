#!/bin/bash
# Verification Script: Test all 13 services can load credentials from .env
# Purpose: Verify environment variable migration is complete and working
# Usage: ./scripts/verify-env-migration.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/load-env.sh"
source "$SCRIPT_DIR/../lib/logging.sh"

init_logging "verify-env-migration"
load_env_file

# Test each service
services=(
    "UNIFI:UNIFI_URL:UNIFI_USERNAME:UNIFI_PASSWORD"
    "LINKDING:LINKDING_URL:LINKDING_API_KEY"
    "RADARR:RADARR_URL:RADARR_API_KEY"
    "SONARR:SONARR_URL:SONARR_API_KEY"
    "PROWLARR:PROWLARR_URL:PROWLARR_API_KEY"
    "OVERSEERR:OVERSEERR_URL:OVERSEERR_API_KEY"
    "SABNZBD:SABNZBD_URL:SABNZBD_API_KEY"
    "QBITTORRENT:QBITTORRENT_URL:QBITTORRENT_USERNAME"
    "GOTIFY:GOTIFY_URL:GOTIFY_TOKEN"
    "GLANCES:GLANCES_URL"
    "TAILSCALE:TAILSCALE_API_KEY:TAILSCALE_TAILNET"
    "UNRAID_TOOTIE:UNRAID_TOOTIE_URL:UNRAID_TOOTIE_API_KEY"
    "UNRAID_SHART:UNRAID_SHART_URL:UNRAID_SHART_API_KEY"
)

pass_count=0
fail_count=0

echo ""
echo "============================================"
echo " Environment Variable Migration Verification"
echo "============================================"
echo ""

for service_spec in "${services[@]}"; do
    IFS=':' read -r service_name vars <<< "$service_spec"
    IFS=':' read -ra var_array <<< "$vars"

    if validate_env_vars "${var_array[@]}"; then
        log_success "✓ $service_name credentials loaded"
        pass_count=$((pass_count + 1))
    else
        log_error "✗ $service_name missing variables: ${var_array[*]}"
        fail_count=$((fail_count + 1))
    fi
done

echo ""
echo "============================================"
echo " Results: $pass_count passed, $fail_count failed"
echo "============================================"
echo ""

if (( fail_count > 0 )); then
    log_error "Verification FAILED: $fail_count services missing credentials"
    exit $fail_count
else
    log_success "Verification PASSED: All services can load credentials from .env"
    exit 0
fi
