#!/bin/bash
# =============================================================================
# Claude Homelab Installer
# =============================================================================
# One-liner: curl -sSL https://raw.githubusercontent.com/jmagar/claude-homelab/main/scripts/install.sh | bash
#
# What this does:
#   1. Checks prerequisites (git, jq, curl)
#   2. Clones repo to ~/claude-homelab (or git pull if it exists)
#   3. Runs setup-creds.sh (creates ~/.claude-homelab/.env with chmod 600)
#   4. Runs setup-symlinks.sh (symlinks service-plugins/agents/commands into ~/.claude/)
#   5. Runs verify.sh (confirms everything is in place)
#   6. Prints next steps
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
# Step 3: Set up credentials
# -------------------------------------------------------------------
run_setup_creds() {
    local script="$INSTALL_DIR/scripts/setup-creds.sh"
    if [[ ! -f "$script" ]]; then
        log_error "setup-creds.sh not found at $script"
        exit 1
    fi
    chmod +x "$script"
    log_info "Setting up credentials..."
    bash "$script"
}

# -------------------------------------------------------------------
# Step 4: Run setup-symlinks.sh
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
# Step 5: Verify
# -------------------------------------------------------------------
run_verify() {
    local script="$INSTALL_DIR/scripts/verify.sh"
    if [[ -f "$script" ]]; then
        chmod +x "$script"
        log_info "Verifying installation..."
        bash "$script" || log_warn "Verification had warnings — see above"
    fi
}

# -------------------------------------------------------------------
# Step 6: Print next steps
# -------------------------------------------------------------------
print_next_steps() {
    echo ""
    echo -e "${GREEN}=== Installation Complete ===${NC}"
    echo ""
    echo "Next steps:"
    echo ""
    echo -e "  1. ${YELLOW}Configure credentials (interactive wizard):${NC}"
    echo "     Open Claude Code and run: /homelab-core:setup"
    echo ""
    echo -e "     Or edit manually:  \$EDITOR ~/.claude-homelab/.env"
    echo ""
    echo -e "  2. ${YELLOW}Restart Claude Code${NC} to pick up the new skills"
    echo ""
    echo -e "  3. ${YELLOW}Check service health:${NC}"
    echo "     /homelab-core:health"
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
run_setup_creds
run_symlinks
run_verify
print_next_steps
