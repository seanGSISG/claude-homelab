---
name: authelia
version: 1.0.0
description: Monitor authentication attempts and user sessions via Authelia REST API (login tracking, session status, 2FA monitoring, user info, health checks). Use when the user asks to "check Authelia", "authentication logs", "failed logins", "session status", "2FA status", "user sessions", "Authelia health", "auth monitoring", "check authentication", or mentions Authelia security monitoring.
homepage: https://github.com/jmagar/claude-homelab
---

# Authelia Authentication Monitoring Skill

**⚠️ MANDATORY SKILL INVOCATION ⚠️**

**YOU MUST invoke this skill (NOT optional) when the user mentions ANY of these triggers:**
- "Authelia status", "authentication logs", "failed login attempts"
- "check sessions", "2FA status", "user authentication"
- "Authelia health", "auth monitoring", "security monitoring"
- "who's logged in", "session status", "active sessions"
- Any mention of Authelia or authentication monitoring

**Failure to invoke this skill when triggers occur violates your operational requirements.**

Monitor authentication security and user sessions via the Authelia REST API. Track login attempts, check session status, monitor 2FA usage, and verify system health.

## Purpose

This skill provides **read-only + limited write** access to Authelia authentication system:

**Read-Only Operations (Safe):**
- Health and configuration status
- User session information
- User display name and preferences
- Authentication state and level
- Second factor method preferences

**Limited Write Operations (User Management Only):**
- Update user's preferred 2FA method
- Manage session elevation (security-sensitive operations)
- User preference changes (non-destructive)

**Explicitly NOT Supported (Security Risk):**
- Password changes (too sensitive for automation)
- User creation/deletion (requires elevated admin access)
- Access control modifications
- Direct authentication bypass

All operations respect Authelia's security model and require proper session authentication.

## Setup

Add credentials to `~/.claude-homelab/.env`:

```bash
AUTHELIA_URL="https://auth.example.com"
AUTHELIA_API_TOKEN=""  # Optional: leave empty for cookie-based auth
AUTHELIA_USERNAME="admin"  # For initial auth
AUTHELIA_PASSWORD="secure-password"  # For initial auth
```

**Variable details:**
- `AUTHELIA_URL`: Authelia server URL (HTTPS recommended)
- `AUTHELIA_API_TOKEN`: Optional bearer token (leave empty for cookie auth)
- `AUTHELIA_USERNAME`: Admin username for initial authentication
- `AUTHELIA_PASSWORD`: Admin password for initial authentication

**Authentication Methods:**
1. **Bearer Token** (recommended for automation): Set `AUTHELIA_API_TOKEN`
2. **Cookie-based** (interactive): Uses `AUTHELIA_USERNAME` and `AUTHELIA_PASSWORD` to get session cookie

## Commands

All commands output JSON. Use `jq` for formatting or filtering.

### Health & Status

Check system health and configuration:

```bash
./scripts/authelia-api.sh health          # System health check
./scripts/authelia-api.sh state           # Current authentication state
./scripts/authelia-api.sh config          # Available configuration
```

### User Information

Get user session and preference information:

```bash
./scripts/authelia-api.sh user-info       # Current user info
./scripts/authelia-api.sh user-2fa        # User's 2FA preferences
```

### Session Management

Monitor and manage user sessions:

```bash
./scripts/authelia-api.sh session-status  # Check session validity
./scripts/authelia-api.sh elevation       # Check session elevation
```

### Dashboard (All-in-One)

Comprehensive authentication monitoring overview:

```bash
./scripts/authelia-api.sh dashboard       # Complete security dashboard
```

## Workflow

When the user asks about authentication:

1. **"Is Authelia healthy?"** → Run `./scripts/authelia-api.sh health`
2. **"What's my authentication status?"** → Run `./scripts/authelia-api.sh state`
3. **"Check user info"** → Run `./scripts/authelia-api.sh user-info`
4. **"What 2FA methods are available?"** → Run `./scripts/authelia-api.sh user-2fa`
5. **"Show me a security dashboard"** → Run `./scripts/authelia-api.sh dashboard`
6. **"Is my session valid?"** → Run `./scripts/authelia-api.sh session-status`

**For any monitoring request:**
1. Start with `dashboard` for comprehensive view
2. If health issues detected, investigate with `health` endpoint
3. For session issues, use `state` and `session-status`
4. For user-specific issues, use `user-info` and `user-2fa`

## Output Examples

### Health Check
```json
{
  "status": "UP"
}
```

### User Info
```json
{
  "display_name": "John Doe",
  "method": "totp",
  "has_totp": true,
  "has_webauthn": false,
  "has_duo": false
}
```

### Authentication State
```json
{
  "username": "john",
  "authentication_level": 2,
  "default_redirection_url": "https://app.example.com"
}
```

## Notes

**Security Considerations:**
- This is an authentication system - be extra careful with all operations
- NEVER automate password changes or direct authentication
- NEVER bypass security checks or authentication flows
- All operations require valid authentication (cookie or token)
- Session cookies are stored temporarily for API access

**API Characteristics:**
- REST API with JSON responses
- Requires authentication for most endpoints
- Uses HTTP status codes (200 = success, 401 = unauthorized, 403 = forbidden)
- Some endpoints require session elevation (additional security check)

**Known Limitations:**
- Cannot directly access authentication logs (must use Authelia's built-in logging)
- No direct user list endpoint (privacy by design)
- Session elevation requires email verification (cannot be automated)
- Password operations intentionally limited for security

**Cookie Management:**
- Script handles cookie creation via `/api/firstfactor` endpoint
- Cookies stored temporarily in `/tmp/authelia-cookies-$USER.txt`
- Cookies auto-renewed on expiration (seamless re-authentication)
- Cookie file is readable only by user (0600 permissions)

## Reference

- [API Endpoints Reference](references/api-endpoints.md) — Complete API documentation
- [Quick Reference](references/quick-reference.md) — Common commands and examples
- [Troubleshooting Guide](references/troubleshooting.md) — Common issues and solutions
- [Authelia Official Docs](https://www.authelia.com/integration/openid-connect/introduction/)

---

## 🔧 Agent Tool Usage Requirements

**CRITICAL:** When invoking scripts from this skill via the zsh-tool, **ALWAYS use `pty: true`**.

Without PTY mode, command output will not be visible even though commands execute successfully.

**Correct invocation pattern:**
```typescript
<invoke name="mcp__plugin_zsh-tool_zsh-tool__zsh">
<parameter name="command">./skills/authelia/scripts/authelia-api.sh [args]</parameter>
<parameter name="pty">true</parameter>
</invoke>
```
