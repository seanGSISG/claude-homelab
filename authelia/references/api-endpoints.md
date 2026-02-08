# Authelia API Endpoints Reference

Complete reference for all Authelia REST API endpoints supported by this skill.

## Authentication

All API endpoints (except health checks and public endpoints) require authentication via:

**Option 1: Session Cookie (Default)**
- Authenticate via `POST /api/firstfactor` with username/password
- Receives `authelia_session` cookie
- Cookie used for subsequent requests
- Cookie expires based on Authelia session configuration

**Option 2: Bearer Token**
- Set `Authorization: Bearer <token>` header
- Token obtained via Authelia admin interface (if supported)
- No session management required

## Base URL

All endpoints are relative to your Authelia installation:
```
https://auth.example.com/api/...
```

---

## System Endpoints

### GET /api/health

**Purpose:** Check system health status

**Authentication:** None required

**Response:**
```json
{
  "status": "UP"
}
```

**HTTP Status Codes:**
- `200 OK` - System is healthy
- `503 Service Unavailable` - System has issues

**Example:**
```bash
curl -s https://auth.example.com/api/health
```

---

### GET /api/state

**Purpose:** Get current authentication state

**Authentication:** Optional (returns different data based on auth status)

**Response (Unauthenticated):**
```json
{
  "authentication_level": 0,
  "default_redirection_url": "https://app.example.com"
}
```

**Response (Authenticated):**
```json
{
  "username": "john",
  "authentication_level": 2,
  "default_redirection_url": "https://app.example.com"
}
```

**Authentication Levels:**
- `0` - Not authenticated
- `1` - First factor only (username/password)
- `2` - Two-factor authentication complete

**Example:**
```bash
curl -s https://auth.example.com/api/state
```

---

### GET /api/configuration

**Purpose:** Get available authentication methods and configuration

**Authentication:** Required (authelia_auth cookie)

**Response:**
```json
{
  "available_methods": [
    "totp",
    "webauthn",
    "mobile_push"
  ],
  "second_factor_enabled": true,
  "totp_period": 30
}
```

**Example:**
```bash
curl -s -b cookies.txt https://auth.example.com/api/configuration
```

---

### GET /api/configuration/password-policy

**Purpose:** Get password policy configuration

**Authentication:** None required

**Response:**
```json
{
  "min_length": 8,
  "max_length": 128,
  "require_uppercase": true,
  "require_lowercase": true,
  "require_number": true,
  "require_special": true
}
```

**Example:**
```bash
curl -s https://auth.example.com/api/configuration/password-policy
```

---

## Authentication Endpoints

### POST /api/firstfactor

**Purpose:** Authenticate user and create session

**Authentication:** None required

**Request Body:**
```json
{
  "username": "john",
  "password": "secure-password",
  "keepMeLoggedIn": false
}
```

**Response (Success):**
```json
{
  "status": "OK"
}
```

**Response (Failure):**
```json
{
  "status": "KO",
  "message": "Incorrect username or password."
}
```

**HTTP Status Codes:**
- `200 OK` - Authentication successful
- `401 Unauthorized` - Invalid credentials
- `429 Too Many Requests` - Rate limit exceeded

**Example:**
```bash
curl -s -c cookies.txt -X POST \
  https://auth.example.com/api/firstfactor \
  -H "Content-Type: application/json" \
  -d '{"username":"john","password":"pass","keepMeLoggedIn":false}'
```

---

### POST /api/logout

**Purpose:** Destroy user session

**Authentication:** Required (authelia_auth cookie)

**Response:**
```json
{
  "status": "OK"
}
```

**HTTP Status Codes:**
- `200 OK` - Logout successful
- `401 Unauthorized` - Not authenticated

**Example:**
```bash
curl -s -b cookies.txt -X POST \
  https://auth.example.com/api/logout
```

---

## User Management Endpoints

### GET /api/user/info

**Purpose:** Get user information and 2FA preferences

**Authentication:** Required (authelia_auth cookie)

**Response:**
```json
{
  "display_name": "John Doe",
  "method": "totp",
  "has_totp": true,
  "has_webauthn": false,
  "has_duo": false
}
```

**Fields:**
- `display_name` - User's display name
- `method` - Preferred second factor method (`totp`, `webauthn`, `duo`, etc.)
- `has_totp` - Whether user has TOTP configured
- `has_webauthn` - Whether user has WebAuthn configured
- `has_duo` - Whether user has Duo configured

**Example:**
```bash
curl -s -b cookies.txt https://auth.example.com/api/user/info
```

---

### POST /api/user/info/2fa_method

**Purpose:** Update user's preferred 2FA method

**Authentication:** Required (authelia_auth cookie)

**Request Body:**
```json
{
  "method": "totp"
}
```

**Valid Methods:**
- `totp` - Time-based One-Time Password
- `webauthn` - WebAuthn/FIDO2
- `duo` - Duo Push
- `mobile_push` - Mobile push notification

**Response:**
```json
{
  "status": "OK"
}
```

**HTTP Status Codes:**
- `200 OK` - Method updated successfully
- `400 Bad Request` - Invalid method
- `401 Unauthorized` - Not authenticated

**Example:**
```bash
curl -s -b cookies.txt -X POST \
  https://auth.example.com/api/user/info/2fa_method \
  -H "Content-Type: application/json" \
  -d '{"method":"totp"}'
```

---

## Session Management Endpoints

### GET /api/user/session/elevation

**Purpose:** Check session elevation status

**Authentication:** Required (authelia_auth cookie)

**Response:**
```json
{
  "elevated": false,
  "elevation_required": false
}
```

**Fields:**
- `elevated` - Whether session is currently elevated
- `elevation_required` - Whether elevation is required for current operation

**Example:**
```bash
curl -s -b cookies.txt https://auth.example.com/api/user/session/elevation
```

---

### POST /api/user/session/elevation

**Purpose:** Request session elevation (sends one-time code via email)

**Authentication:** Required (authelia_auth cookie)

**Request Body:**
```json
{
  "elevation_ttl": 300
}
```

**Response:**
```json
{
  "status": "OK",
  "message": "One-time code sent to your email"
}
```

**HTTP Status Codes:**
- `200 OK` - Elevation code sent
- `401 Unauthorized` - Not authenticated
- `500 Internal Server Error` - Failed to send code

**Example:**
```bash
curl -s -b cookies.txt -X POST \
  https://auth.example.com/api/user/session/elevation \
  -H "Content-Type: application/json" \
  -d '{"elevation_ttl":300}'
```

---

### PUT /api/user/session/elevation

**Purpose:** Validate elevation code and elevate session

**Authentication:** Required (authelia_auth cookie)

**Request Body:**
```json
{
  "one_time_code": "123456"
}
```

**Response:**
```json
{
  "status": "OK"
}
```

**HTTP Status Codes:**
- `200 OK` - Session elevated successfully
- `400 Bad Request` - Invalid code
- `401 Unauthorized` - Not authenticated

**Example:**
```bash
curl -s -b cookies.txt -X PUT \
  https://auth.example.com/api/user/session/elevation \
  -H "Content-Type: application/json" \
  -d '{"one_time_code":"123456"}'
```

---

### DELETE /api/user/session/elevation

**Purpose:** Revoke session elevation

**Authentication:** Required (authelia_auth cookie)

**Response:**
```json
{
  "status": "OK"
}
```

**HTTP Status Codes:**
- `200 OK` - Elevation revoked
- `401 Unauthorized` - Not authenticated

**Example:**
```bash
curl -s -b cookies.txt -X DELETE \
  https://auth.example.com/api/user/session/elevation
```

---

## Authorization Endpoints

These endpoints are used by reverse proxies for authorization checks. They are not typically used directly for monitoring.

### GET /api/authz/forward-auth

**Purpose:** ForwardAuth implementation (Traefik, Caddy, Skipper)

**Authentication:** Via headers from reverse proxy

**Response:**
- `200 OK` - Authorized (includes user headers)
- `302 Found` - Redirect to login
- `401 Unauthorized` - Not authorized

**Headers Returned (on 200):**
- `Remote-User` - Username
- `Remote-Name` - Display name
- `Remote-Email` - Email address
- `Remote-Groups` - Comma-separated groups

---

### GET /api/authz/auth-request

**Purpose:** AuthRequest implementation (NGINX, HAProxy)

**Authentication:** Via headers from reverse proxy

**Response:**
- `200 OK` - Authorized
- `401 Unauthorized` - Not authorized

---

### GET /api/verify

**Purpose:** Legacy authorization endpoint

**Authentication:** Via headers from reverse proxy

**Response:**
- `200 OK` - Authorized
- `302 Found` - Redirect to login
- `401 Unauthorized` - Not authorized

---

## Password Management Endpoints

**⚠️ NOT SUPPORTED BY THIS SKILL** - Password operations are too sensitive for automation.

These endpoints exist but are intentionally excluded from the skill:

- `POST /api/reset-password/identity/start` - Start password reset
- `POST /api/reset-password/identity/finish` - Finish password reset
- `POST /api/reset-password` - Complete password reset
- `POST /api/change-password` - Change password

---

## Error Responses

All endpoints follow consistent error response format:

```json
{
  "status": "KO",
  "message": "Human-readable error message"
}
```

**Common HTTP Status Codes:**
- `200 OK` - Request successful
- `204 No Content` - Request successful, no response body
- `400 Bad Request` - Invalid request parameters
- `401 Unauthorized` - Authentication required or failed
- `403 Forbidden` - Insufficient permissions
- `404 Not Found` - Endpoint not found
- `429 Too Many Requests` - Rate limit exceeded
- `500 Internal Server Error` - Server error
- `503 Service Unavailable` - Service temporarily unavailable

---

## Rate Limiting

Authelia implements rate limiting on authentication endpoints:

- **First factor:** 5 failed attempts per IP within 5 minutes
- **Second factor:** 3 failed attempts per user within 5 minutes
- **Password reset:** 3 requests per user within 1 hour

Rate limit exceeded returns:
```json
{
  "status": "KO",
  "message": "Too many authentication attempts, please try again later."
}
```

HTTP status: `429 Too Many Requests`

---

## Best Practices

1. **Cookie Management:**
   - Store cookies securely with `0600` permissions
   - Use cookie jar for multiple requests
   - Cookies expire based on session configuration
   - Re-authenticate when cookie expires

2. **Error Handling:**
   - Always check HTTP status codes
   - Parse JSON error messages
   - Implement exponential backoff for rate limits
   - Log authentication failures for security monitoring

3. **Security:**
   - Use HTTPS for all API calls
   - Never log passwords or tokens
   - Validate SSL certificates in production
   - Rotate API tokens regularly

4. **Performance:**
   - Reuse cookies across multiple requests
   - Implement caching for configuration endpoints
   - Avoid polling - use event-driven approach when possible
   - Monitor API response times

---

## API Versioning

Authelia API is currently unversioned. Breaking changes are avoided when possible, but monitor:
- [Authelia Changelog](https://github.com/authelia/authelia/releases)
- [API Documentation](https://www.authelia.com/integration/openid-connect/introduction/)

This documentation is accurate as of **Authelia v4.38+**.
