#!/bin/bash
# =============================================================================
# Verify Claude Homelab Installation
# =============================================================================
# Works for both bash path (symlinks) and plugin path (Claude Code cache).
# Exits 0 if healthy, 1 if critical issues found.
# =============================================================================

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ok=0
warn=0
err=0

log_ok()   { echo -e "  ${GREEN}✓${NC}  $1"; ((ok++));   }
log_warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; ((warn++)); }
log_err()  { echo -e "  ${RED}✗${NC}  $1"; ((err++));   }
log_head() { echo ""; echo -e "${BLUE}$1${NC}"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOMELAB_DIR="$HOME/.claude-homelab"
CLAUDE_DIR="$HOME/.claude"

echo ""
echo -e "${BLUE}=== Claude Homelab — Verification ===${NC}"

# -------------------------------------------------------------------
# 1. Credentials
# -------------------------------------------------------------------
log_head "Credentials"

if [[ -f "$HOMELAB_DIR/.env" ]]; then
    perm=$(stat -c "%a" "$HOMELAB_DIR/.env" 2>/dev/null || stat -f "%Lp" "$HOMELAB_DIR/.env" 2>/dev/null)
    if [[ "$perm" == "600" ]]; then
        log_ok ".env exists with correct permissions (600)"
    else
        log_warn ".env exists but permissions are $perm (should be 600) — run: chmod 600 $HOMELAB_DIR/.env"
    fi
    if [[ -s "$HOMELAB_DIR/.env" ]]; then
        configured=$(grep -c "=.\+" "$HOMELAB_DIR/.env" 2>/dev/null || echo 0)
        log_ok "$configured credential lines configured"
    else
        log_warn ".env is empty — run /homelab-core:setup in Claude Code"
    fi
else
    log_err ".env missing — run: curl -sSL https://raw.githubusercontent.com/jmagar/claude-homelab/main/scripts/setup-creds.sh | bash"
fi

if [[ -f "$HOMELAB_DIR/load-env.sh" ]]; then
    log_ok "load-env.sh installed at $HOMELAB_DIR/load-env.sh"
else
    log_warn "load-env.sh missing — run setup-symlinks.sh"
fi

# -------------------------------------------------------------------
# 2. Bash path — symlinks
# -------------------------------------------------------------------
log_head "Bash Path (symlinks)"

if [[ -d "$CLAUDE_DIR/skills" ]]; then
    skill_count=$(find "$CLAUDE_DIR/skills" -maxdepth 1 -type l 2>/dev/null | wc -l)
    broken=$(find "$CLAUDE_DIR/skills" -maxdepth 1 -type l ! -e 2>/dev/null | wc -l)
    if [[ "$broken" -gt 0 ]]; then
        log_warn "$skill_count skill symlinks ($broken broken) — re-run: $REPO_ROOT/scripts/setup-symlinks.sh"
        find "$CLAUDE_DIR/skills" -maxdepth 1 -type l ! -e 2>/dev/null | while read -r s; do
            echo "     broken: $s"
        done
    else
        log_ok "$skill_count skill symlinks (all valid)"
    fi
else
    log_warn "~/.claude/skills/ missing — run setup-symlinks.sh"
fi

if [[ -d "$CLAUDE_DIR/agents" ]]; then
    agent_count=$(find "$CLAUDE_DIR/agents" -maxdepth 1 -type l 2>/dev/null | wc -l)
    log_ok "$agent_count agent symlinks"
else
    log_warn "~/.claude/agents/ missing"
fi

if [[ -d "$CLAUDE_DIR/commands" ]]; then
    cmd_count=$(find "$CLAUDE_DIR/commands" -maxdepth 1 \( -type l -o -type f \) -name "*.md" 2>/dev/null | wc -l)
    log_ok "$cmd_count command files"
else
    log_warn "~/.claude/commands/ missing"
fi

# -------------------------------------------------------------------
# 3. Plugin path — marketplace + plugin.json
# -------------------------------------------------------------------
log_head "Plugin Path"

if [[ -f "$REPO_ROOT/.claude-plugin/marketplace.json" ]]; then
    plugin_count=$(jq '.plugins | length' "$REPO_ROOT/.claude-plugin/marketplace.json" 2>/dev/null || echo "?")
    log_ok "marketplace.json valid ($plugin_count plugins listed)"

    # Verify no dead source paths
    dead=0
    while IFS= read -r src; do
        full_path="$REPO_ROOT/$src"
        if [[ ! -d "$full_path" && "$src" != "./" ]]; then
            log_warn "Dead marketplace entry: $src"
            ((dead++))
        fi
    done < <(jq -r '.plugins[].source' "$REPO_ROOT/.claude-plugin/marketplace.json" 2>/dev/null | sed 's|^\./||')
    [[ "$dead" -eq 0 ]] && log_ok "All marketplace source paths exist"
else
    log_err ".claude-plugin/marketplace.json missing"
fi

if [[ -f "$REPO_ROOT/.claude-plugin/plugin.json" ]]; then
    pname=$(jq -r '.name' "$REPO_ROOT/.claude-plugin/plugin.json" 2>/dev/null || echo "unknown")
    log_ok "homelab-core plugin.json valid (name: $pname)"
else
    log_err ".claude-plugin/plugin.json missing — homelab-core plugin cannot be installed"
fi

# Check service plugin manifests
missing_manifests=0
total_services=0
for d in "$REPO_ROOT/service-plugins"/*/; do
    ((total_services++))
    if [[ ! -f "$d.claude-plugin/plugin.json" ]]; then
        log_warn "Missing plugin.json: $d"
        ((missing_manifests++))
    fi
done
if [[ "$total_services" -gt 0 ]]; then
    good=$(( total_services - missing_manifests ))
    if [[ "$missing_manifests" -eq 0 ]]; then
        log_ok "$total_services service plugins with valid manifests"
    else
        log_warn "$good/$total_services service plugins have plugin.json ($missing_manifests missing)"
    fi
fi

# Check homelab-core skills
log_head "Homelab-Core Skills"
for skill in setup health; do
    if [[ -f "$REPO_ROOT/skills/$skill/SKILL.md" ]]; then
        log_ok "/homelab-core:$skill skill present"
    else
        log_err "skills/$skill/SKILL.md missing"
    fi
done

if [[ -x "$REPO_ROOT/skills/health/scripts/check-health.sh" ]]; then
    log_ok "check-health.sh is executable"
else
    log_warn "check-health.sh missing or not executable"
fi

# -------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------
echo ""
echo -e "${BLUE}============================${NC}"
echo -e "  ${GREEN}✓${NC}  OK:       $ok"
[[ "$warn" -gt 0 ]] && echo -e "  ${YELLOW}⚠${NC}  Warnings: $warn"
[[ "$err"  -gt 0 ]] && echo -e "  ${RED}✗${NC}  Errors:   $err"
echo ""

if [[ "$err" -gt 0 ]]; then
    echo -e "${RED}Critical issues found — fix errors above before using Claude Code skills.${NC}"
    echo ""
    exit 1
elif [[ "$warn" -gt 0 ]]; then
    echo -e "${YELLOW}Setup complete with warnings. Run /homelab-core:setup in Claude Code to configure credentials.${NC}"
    echo ""
else
    echo -e "${GREEN}All good! Run /homelab-core:health in Claude Code to verify service connectivity.${NC}"
    echo ""
fi
