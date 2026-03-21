#!/bin/bash
# =============================================================================
# Claude Homelab Installer
# =============================================================================
# One-liner: curl -sSL https://raw.githubusercontent.com/jmagar/claude-homelab/main/scripts/install.sh | bash
#
# What this does:
#   1. Checks prerequisites (git, jq, curl)
#   2. Clones repo to ~/claude-homelab (or git pull if it exists)
#   3. Runs setup-symlinks.sh (symlinks skills/agents/commands into ~/.claude/)
#   4. Stubs ~/.claude-homelab/.env from .env.example with chmod 600
#   5. Prints next steps
#
# Non-interactive — safe for curl | bash (no read -p prompts)
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO_URL="https://github.com/jmagar/claude-homelab.git"
INSTALL_DIR="$HOME/claude-homelab"
HOMELAB_DIR="$HOME/.claude-homelab"

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC}   $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERR]${NC}  $1"; }

# -------------------------------------------------------------------
# Step 1: Check prerequisites
# -------------------------------------------------------------------
check_prereqs() {
    local missing=()
    for cmd in git jq curl; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing[*]}"
        echo "Install them first, then re-run this script."
        exit 1
    fi
    log_success "Prerequisites met (git, jq, curl)"
}

# -------------------------------------------------------------------
# Step 2: Clone or update repo
# -------------------------------------------------------------------
clone_or_pull() {
    if [[ -d "$INSTALL_DIR/.git" ]]; then
        log_info "Repository already exists at $INSTALL_DIR — pulling latest..."
        git -C "$INSTALL_DIR" pull --ff-only || {
            log_warn "git pull failed (you may have local changes). Continuing with existing checkout."
        }
    else
        if [[ -e "$INSTALL_DIR" ]]; then
            log_error "$INSTALL_DIR exists but is not a git repo. Move or remove it first."
            exit 1
        fi
        log_info "Cloning claude-homelab to $INSTALL_DIR..."
        git clone "$REPO_URL" "$INSTALL_DIR"
    fi
    log_success "Repository ready at $INSTALL_DIR"
}

# -------------------------------------------------------------------
# Step 3: Run setup-symlinks.sh
# -------------------------------------------------------------------
run_symlinks() {
    local script="$INSTALL_DIR/scripts/setup-symlinks.sh"
    if [[ ! -f "$script" ]]; then
        log_error "setup-symlinks.sh not found at $script"
        exit 1
    fi
    chmod +x "$script"
    log_info "Running setup-symlinks.sh..."
    bash "$script"
}

# -------------------------------------------------------------------
# Step 4: Stub ~/.claude-homelab/.env
# -------------------------------------------------------------------
stub_env() {
    mkdir -p "$HOMELAB_DIR"

    if [[ -f "$HOMELAB_DIR/.env" ]]; then
        log_warn "~/.claude-homelab/.env already exists — not overwriting"
        return 0
    fi

    local example="$INSTALL_DIR/.env.example"
    if [[ ! -f "$example" ]]; then
        log_warn ".env.example not found — creating empty .env"
        touch "$HOMELAB_DIR/.env"
    else
        cp "$example" "$HOMELAB_DIR/.env"
    fi
    chmod 600 "$HOMELAB_DIR/.env"
    log_success "Created ~/.claude-homelab/.env (chmod 600)"
}

# -------------------------------------------------------------------
# Step 5: Print next steps
# -------------------------------------------------------------------
print_next_steps() {
    echo ""
    echo -e "${GREEN}=== Installation Complete ===${NC}"
    echo ""
    echo "Next steps:"
    echo ""
    echo -e "  1. ${YELLOW}Add your credentials:${NC}"
    echo "     \$EDITOR ~/.claude-homelab/.env"
    echo ""
    echo -e "  2. ${YELLOW}Restart Claude Code${NC} to pick up the new skills"
    echo ""
    echo -e "  3. ${YELLOW}Verify setup:${NC}"
    echo "     ~/claude-homelab/scripts/verify-symlinks.sh"
    echo ""
    echo -e "  4. ${YELLOW}Try a command:${NC}"
    echo "     /homelab:system-resources"
    echo ""
}

# -------------------------------------------------------------------
# Main
# -------------------------------------------------------------------
echo ""
echo -e "${BLUE}=== Claude Homelab Installer ===${NC}"
echo ""

check_prereqs
clone_or_pull
run_symlinks
stub_env
print_next_steps
