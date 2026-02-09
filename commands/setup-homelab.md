---
description: Initialize homelab environment and configure .env file
argument-hint: ""
allowed-tools: Bash(tool:*)
---

Initialize your Claude Homelab environment by running the setup script.

## Instructions

Run the setup script to:
1. Create `~/.claude-homelab/.env` from template
2. Set secure permissions (600)
3. Optionally configure services interactively

Execute the setup script:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-homelab.sh"
```

The script will:
- Copy `.env.example` to `~/.claude-homelab/.env`
- Set secure file permissions
- Offer interactive configuration for common services
- Provide next steps for completing setup

After setup, edit your configuration:
```bash
nano ~/.claude-homelab/.env
```

View all available services:
```bash
cat "${CLAUDE_PLUGIN_ROOT}/.env.example"
```
