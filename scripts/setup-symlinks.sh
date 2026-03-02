#!/bin/bash
# =============================================================================
# Setup Symlinks for Claude Homelab
# =============================================================================
# Creates symlinks from this repo to ~/.claude/ for Claude Code discovery
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Repository root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_DIR="$HOME/.claude"

# Counters
created=0
skipped=0
errors=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create symlink with validation
create_symlink() {
    local source="$1"
    local target="$2"
    local type="${3:-file}"  # file or directory

    # Check if source exists
    if [ ! -e "$source" ]; then
        log_error "Source does not exist: $source"
        ((errors++))
        return 1
    fi

    # Create target directory if it doesn't exist
    local target_dir
    if [ "$type" = "directory" ]; then
        target_dir=$(dirname "$target")
    else
        target_dir=$(dirname "$target")
    fi

    mkdir -p "$target_dir"

    # Check if target already exists
    if [ -e "$target" ] || [ -L "$target" ]; then
        # Check if it's already a valid symlink to the correct source
        if [ -L "$target" ] && [ "$(readlink -f "$target")" = "$(readlink -f "$source")" ]; then
            log_warn "Skipped (already linked): $target"
            ((skipped++))
            return 0
        else
            # Invalid symlink or regular file/directory
            log_warn "Exists (not overwriting): $target"
            ((skipped++))
            return 0
        fi
    fi

    # Create symlink
    if ln -sf "$source" "$target"; then
        log_success "Created: $target → $source"
        ((created++))
    else
        log_error "Failed to create: $target"
        ((errors++))
        return 1
    fi
}

# Main setup function
main() {
    echo ""
    log_info "====================================================================="
    log_info "Claude Homelab Symlink Setup"
    log_info "====================================================================="
    log_info "Repository: $REPO_ROOT"
    log_info "Target: $CLAUDE_DIR"
    echo ""

    # Create base directories
    log_info "Creating base directories..."
    mkdir -p "$CLAUDE_DIR"/{skills,agents,commands}

    # Setup skills
    echo ""
    log_info "Setting up skills..."
    if [ -d "$REPO_ROOT/skills" ]; then
        while IFS= read -r -d '' skill_dir; do
            skill_name=$(basename "$skill_dir")
            # Skip CLAUDE.md file
            if [ "$skill_name" != "CLAUDE.md" ] && [ -d "$skill_dir" ]; then
                create_symlink "$skill_dir" "$CLAUDE_DIR/skills/$skill_name" "directory"
            fi
        done < <(find "$REPO_ROOT/skills" -mindepth 1 -maxdepth 1 -print0)
    fi

    # Setup agents
    echo ""
    log_info "Setting up agents..."
    if [ -d "$REPO_ROOT/agents" ]; then
        while IFS= read -r -d '' agent_file; do
            agent_name=$(basename "$agent_file")
            if [[ "$agent_name" == *.md ]]; then
                create_symlink "$agent_file" "$CLAUDE_DIR/agents/$agent_name" "file"
            fi
        done < <(find "$REPO_ROOT/agents" -maxdepth 1 -type f -name "*.md" -print0)
    fi

    # Setup commands
    echo ""
    log_info "Setting up commands..."
    if [ -d "$REPO_ROOT/commands" ]; then
        # Symlink .md files (single commands)
        while IFS= read -r -d '' cmd_file; do
            cmd_name=$(basename "$cmd_file")
            create_symlink "$cmd_file" "$CLAUDE_DIR/commands/$cmd_name" "file"
        done < <(find "$REPO_ROOT/commands" -maxdepth 1 -type f -name "*.md" -print0)

        # Symlink directories (namespaced commands)
        while IFS= read -r -d '' cmd_dir; do
            cmd_name=$(basename "$cmd_dir")
            create_symlink "$cmd_dir" "$CLAUDE_DIR/commands/$cmd_name" "directory"
        done < <(find "$REPO_ROOT/commands" -mindepth 1 -maxdepth 1 -type d -print0)
    fi

    # Setup ~/.homelab-skills/
    echo ""
    log_info "Setting up ~/.homelab-skills/ ..."
    local homelab_dir="$HOME/.homelab-skills"
    mkdir -p "$homelab_dir"

    # Install load-env.sh
    cp "$REPO_ROOT/lib/load-env.sh" "$homelab_dir/load-env.sh"
    log_success "Installed: $homelab_dir/load-env.sh"

    # Stub .env from .env.example only if not already present
    if [[ ! -f "$homelab_dir/.env" ]]; then
        cp "$REPO_ROOT/.env.example" "$homelab_dir/.env"
        chmod 600 "$homelab_dir/.env"
        log_success "Created:   $homelab_dir/.env (from .env.example)"
        echo ""
        log_warn "┌─────────────────────────────────────────────────────────┐"
        log_warn "│  Next step: add your credentials                        │"
        log_warn "│  \$EDITOR ~/.homelab-skills/.env                        │"
        log_warn "└─────────────────────────────────────────────────────────┘"
    else
        log_warn "Skipped:   $homelab_dir/.env (already exists)"
    fi

    # Summary
    echo ""
    log_info "====================================================================="
    log_info "Summary"
    log_info "====================================================================="
    log_success "Created: $created symlinks"
    if [ "$skipped" -gt 0 ]; then
        log_warn "Skipped: $skipped (already exist or valid)"
    fi
    if [ "$errors" -gt 0 ]; then
        log_error "Errors: $errors"
        exit 1
    fi
    echo ""
    log_success "✓ Setup complete!"
    log_info "Credentials: ~/.homelab-skills/.env"
    log_info "Verify with: ./scripts/verify-symlinks.sh"
    echo ""
}

# Run main function
main "$@"
