#!/bin/bash
# =============================================================================
# Verify Symlinks for Claude Homelab
# =============================================================================
# Checks that all symlinks from this repo to ~/.claude/ are valid
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
valid=0
missing=0
broken=0
incorrect=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Verify a symlink
verify_symlink() {
    local source="$1"
    local target="$2"
    local name="$3"

    # Check if target exists
    if [ ! -e "$target" ] && [ ! -L "$target" ]; then
        log_warn "Missing: $name"
        log_info "  Expected: $target → $source"
        log_info "  Run: ln -sf $source $target"
        ((missing++))
        return 1
    fi

    # Check if target is a symlink
    if [ ! -L "$target" ]; then
        log_error "Not a symlink: $name"
        log_info "  Path: $target"
        log_info "  Remove and re-run: rm -rf $target && ./scripts/setup-symlinks.sh"
        ((incorrect++))
        return 1
    fi

    # Check if symlink points to correct source
    local actual_source
    actual_source=$(readlink -f "$target")
    local expected_source
    expected_source=$(readlink -f "$source")

    if [ "$actual_source" != "$expected_source" ]; then
        log_error "Incorrect target: $name"
        log_info "  Expected: $expected_source"
        log_info "  Actual: $actual_source"
        log_info "  Fix: ln -sf $source $target"
        ((incorrect++))
        return 1
    fi

    # Check if symlink target exists
    if [ ! -e "$actual_source" ]; then
        log_error "Broken symlink: $name"
        log_info "  Target does not exist: $actual_source"
        log_info "  Remove: rm $target"
        ((broken++))
        return 1
    fi

    # All checks passed
    log_success "Valid: $name"
    ((valid++))
}

# Main verification function
main() {
    echo ""
    log_info "====================================================================="
    log_info "Claude Homelab Symlink Verification"
    log_info "====================================================================="
    log_info "Repository: $REPO_ROOT"
    log_info "Target: $CLAUDE_DIR"
    echo ""

    # Verify skills
    log_info "Verifying skills..."
    if [ -d "$REPO_ROOT/skills" ]; then
        while IFS= read -r -d '' skill_dir; do
            skill_name=$(basename "$skill_dir")
            # Skip CLAUDE.md file
            if [ "$skill_name" != "CLAUDE.md" ] && [ -d "$skill_dir" ]; then
                verify_symlink "$skill_dir" "$CLAUDE_DIR/skills/$skill_name" "skills/$skill_name"
            fi
        done < <(find "$REPO_ROOT/skills" -mindepth 1 -maxdepth 1 -print0)
    fi

    echo ""

    # Verify agents
    log_info "Verifying agents..."
    if [ -d "$REPO_ROOT/agents" ]; then
        while IFS= read -r -d '' agent_file; do
            agent_name=$(basename "$agent_file")
            if [[ "$agent_name" == *.md ]]; then
                verify_symlink "$agent_file" "$CLAUDE_DIR/agents/$agent_name" "agents/$agent_name"
            fi
        done < <(find "$REPO_ROOT/agents" -maxdepth 1 -type f -name "*.md" -print0)
    fi

    echo ""

    # Verify commands
    log_info "Verifying commands..."
    if [ -d "$REPO_ROOT/commands" ]; then
        # Verify .md files (single commands)
        while IFS= read -r -d '' cmd_file; do
            cmd_name=$(basename "$cmd_file")
            verify_symlink "$cmd_file" "$CLAUDE_DIR/commands/$cmd_name" "commands/$cmd_name"
        done < <(find "$REPO_ROOT/commands" -maxdepth 1 -type f -name "*.md" -print0)

        # Verify directories (namespaced commands)
        while IFS= read -r -d '' cmd_dir; do
            cmd_name=$(basename "$cmd_dir")
            verify_symlink "$cmd_dir" "$CLAUDE_DIR/commands/$cmd_name" "commands/$cmd_name/"
        done < <(find "$REPO_ROOT/commands" -mindepth 1 -maxdepth 1 -type d -print0)
    fi

    # Summary
    echo ""
    log_info "====================================================================="
    log_info "Summary"
    log_info "====================================================================="
    log_success "Valid: $valid symlinks"

    if [ "$missing" -gt 0 ]; then
        log_warn "Missing: $missing symlinks"
    fi

    if [ "$broken" -gt 0 ]; then
        log_error "Broken: $broken symlinks"
    fi

    if [ "$incorrect" -gt 0 ]; then
        log_error "Incorrect: $incorrect symlinks"
    fi

    echo ""

    # Exit status
    if [ "$missing" -gt 0 ] || [ "$broken" -gt 0 ] || [ "$incorrect" -gt 0 ]; then
        log_error "✗ Verification failed!"
        log_info "Run: ./scripts/setup-symlinks.sh"
        exit 1
    else
        log_success "✓ All symlinks are valid!"
    fi
    echo ""
}

# Run main function
main "$@"
