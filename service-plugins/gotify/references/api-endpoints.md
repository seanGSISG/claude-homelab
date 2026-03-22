# Gotify API Reference

**API Version:** 2.0.2
**Last Updated:** 2026-02-01

This is the documentation of the Gotify REST-API.

# Authentication
In Gotify there are two token types:
__clientToken__: a client is something that receives message and manages stuff like creating new tokens or delete messages. (f.ex this token should be used for an android app)
__appToken__: an application is something that sends messages (f.ex. this token should be used for a shell script)

The token can be transmitted in a header named `X-Gotify-Key`, in a query parameter named `token` or
through a header named `Authorization` with the value prefixed with `Bearer` (Ex. `Bearer randomtoken`).
There is also the possibility to authenticate through basic auth, this should only be used for creating a clientToken.

\---

Found a bug or have some questions? [Create an issue on GitHub](https://github.com/gotify/server/issues)

**Base URL:** `http://localhost:PORT` (configure based on your setup)

## Quick Start

```bash
# Set environment variables
export BASE_URL="http://localhost:5055"
export API_KEY="your-api-key"

# Test connection
curl -s "$BASE_URL/api/v1/status" -H "X-Api-Key: $API_KEY"
```

## Endpoints by Category

### application

#### GET /application

Return all applications.

**Example Request:**
```bash
curl -X GET "$BASE_URL/application" \
  -H "X-Api-Key: $API_KEY"
```
**Response Codes:**
- `200`: Ok
- `401`: Unauthorized
- `403`: Forbidden

---

#### POST /application

Create an application.


**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| body (body) | string | Yes | the application to add |

**Example Request:**
```bash
curl -X POST "$BASE_URL/application" \
  -H "X-Api-Key: $API_KEY" \
  -H "Content-Type: application/json"
```
**Response Codes:**
- `200`: Ok
- `400`: Bad Request
- `401`: Unauthorized
- `403`: Forbidden

---

#### PUT /application/{id}

Update an application.


**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| body (body) | string | Yes | the application to update |
| id (path) | string | Yes | the application id |

**Example Request:**
```bash
curl -X PUT "$BASE_URL/application/123" \
  -H "X-Api-Key: $API_KEY" \
  -H "Content-Type: application/json"
```
**Response Codes:**
- `200`: Ok
- `400`: Bad Request
- `401`: Unauthorized
- `403`: Forbidden
- `404`: Not Found

---

#### DELETE /application/{id}

Delete an application.


**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| id (path) | string | Yes | the application id |

**Example Request:**
```bash
curl -X DELETE "$BASE_URL/application/123" \
  -H "X-Api-Key: $API_KEY"
```
**Response Codes:**
- `200`: Ok
- `400`: Bad Request
- `401`: Unauthorized
- `403`: Forbidden
- `404`: Not Found

---

#### POST /application/{id}/image

Upload an image for an application.


**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| file (formData) | string | Yes | the application image |
| id (path) | string | Yes | the application id |

**Example Request:**
```bash
curl -X POST "$BASE_URL/application/123/image" \
  -H "X-Api-Key: $API_KEY" \
  -H "Content-Type: application/json"
```
**Response Codes:**
- `200`: Ok
- `400`: Bad Request
- `401`: Unauthorized
- `403`: Forbidden
- `404`: Not Found
- `500`: Server Error

---

#### DELETE /application/{id}/image

Deletes an image of an application.


**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| id (path) | string | Yes | the application id |

**Example Request:**
```bash
curl -X DELETE "$BASE_URL/application/123/image" \
  -H "X-Api-Key: $API_KEY"
```
**Response Codes:**
- `200`: Ok
- `400`: Bad Request
- `401`: Unauthorized
- `403`: Forbidden
- `404`: Not Found
- `500`: Server Error

---

### client

#### GET /client

Return all clients.

**Example Request:**
```bash
curl -X GET "$BASE_URL/client" \
  -H "X-Api-Key: $API_KEY"
```
**Response Codes:**
- `200`: Ok
- `401`: Unauthorized
- `403`: Forbidden

---

#### POST /client

Create a client.


**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| body (body) | string | Yes | the client to add |

**Example Request:**
```bash
curl -X POST "$BASE_URL/client" \
  -H "X-Api-Key: $API_KEY" \
  -H "Content-Type: application/json"
```
**Response Codes:**
- `200`: Ok
- `400`: Bad Request
- `401`: Unauthorized
- `403`: Forbidden

---

#### PUT /client/{id}

Update a client.


**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| body (body) | string | Yes | the client to update |
| id (path) | string | Yes | the client id |

**Example Request:**
```bash
curl -X PUT "$BASE_URL/client/123" \
  -H "X-Api-Key: $API_KEY" \
  -H "Content-Type: application/json"
```
**Response Codes:**
- `200`: Ok
- `400`: Bad Request
- `401`: Unauthorized
- `403`: Forbidden
- `404`: Not Found

---

#### DELETE /client/{id}

Delete a client.


**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| id (path) | string | Yes | the client id |

**Example Request:**
```bash
curl -X DELETE "$BASE_URL/client/123" \
  -H "X-Api-Key: $API_KEY"
```
**Response Codes:**
- `200`: Ok
- `400`: Bad Request
- `401`: Unauthorized
- `403`: Forbidden
- `404`: Not Found

---

### health

#### GET /health

Get health information.

**Example Request:**
```bash
curl -X GET "$BASE_URL/health" \
  -H "X-Api-Key: $API_KEY"
```
**Response Codes:**
- `200`: Ok
- `500`: Ok

---

### message

#### GET /application/{id}/message

Return all messages from a specific application.


**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| id (path) | string | Yes | the application id |
| limit (query) | string | No | the maximal amount of messages to return |
| since (query) | string | No | return all messages with an ID less than this value |

**Example Request:**
```bash
curl -X GET "$BASE_URL/application/123/message" \
  -H "X-Api-Key: $API_KEY"
```
**Response Codes:**
- `200`: Ok
- `400`: Bad Request
- `401`: Unauthorized
- `403`: Forbidden
- `404`: Not Found

---

#### DELETE /application/{id}/message

Delete all messages from a specific application.


**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| id (path) | string | Yes | the application id |

**Example Request:**
```bash
curl -X DELETE "$BASE_URL/application/123/message" \
  -H "X-Api-Key: $API_KEY"
```
**Response Codes:**
- `200`: Ok
- `400`: Bad Request
- `401`: Unauthorized
- `403`: Forbidden
- `404`: Not Found

---

#### GET /message

Return all messages.


**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| limit (query) | string | No | the maximal amount of messages to return |
| since (query) | string | No | return all messages with an ID less than this value |

**Example Request:**
```bash
curl -X GET "$BASE_URL/message" \
  -H "X-Api-Key: $API_KEY"
```
**Response Codes:**
- `200`: Ok
- `400`: Bad Request
- `401`: Unauthorized
- `403`: Forbidden

---

#### POST /message

Create a message.

__NOTE__: This API ONLY accepts an application token as authentication.


**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| body (body) | string | Yes | the message to add |

**Example Request:**
```bash
curl -X POST "$BASE_URL/message" \
  -H "X-Api-Key: $API_KEY" \
  -H "Content-Type: application/json"
```
**Response Codes:**
- `200`: Ok
- `400`: Bad Request
- `401`: Unauthorized
- `403`: Forbidden

---

#### DELETE /message

Delete all messages.

**Example Request:**
```bash
curl -X DELETE "$BASE_URL/message" \
  -H "X-Api-Key: $API_KEY"
```
**Response Codes:**
- `200`: Ok
- `401`: Unauthorized
- `403`: Forbidden

---

#### DELETE /message/{id}

Deletes a message with an id.


**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| id (path) | string | Yes | the message id |

**Example Request:**
```bash
curl -X DELETE "$BASE_URL/message/123" \
  -H "X-Api-Key: $API_KEY"
```
**Response Codes:**
- `200`: Ok
- `400`: Bad Request
- `401`: Unauthorized
- `403`: Forbidden
- `404`: Not Found

---

#### GET /stream

Websocket, return newly created messages.

**Example Request:**
```bash
curl -X GET "$BASE_URL/stream" \
  -H "X-Api-Key: $API_KEY"
```
**Response Codes:**
- `200`: Ok
- `400`: Bad Request
- `401`: Unauthorized
- `403`: Forbidden
- `500`: Server Error

---

### plugin

#### GET /plugin

Return all plugins.

**Example Request:**
```bash
curl -X GET "$BASE_URL/plugin" \
  -H "X-Api-Key: $API_KEY"
```
**Response Codes:**
- `200`: Ok
- `401`: Unauthorized
- `403`: Forbidden
- `404`: Not Found
- `500`: Internal Server Error

---

#### GET /plugin/{id}/config

Get YAML configuration for Configurer plugin.


**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| id (path) | string | Yes | the plugin id |

**Example Request:**
```bash
curl -X GET "$BASE_URL/plugin/123/config" \
  -H "X-Api-Key: $API_KEY"
```
**Response Codes:**
- `200`: Ok
- `400`: Bad Request
- `401`: Unauthorized
- `403`: Forbidden
- `404`: Not Found
- `500`: Internal Server Error

---

#### POST /plugin/{id}/config

Update YAML configuration for Configurer plugin.


**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| id (path) | string | Yes | the plugin id |

**Example Request:**
```bash
curl -X POST "$BASE_URL/plugin/123/config" \
  -H "X-Api-Key: $API_KEY" \
  -H "Content-Type: application/json"
```
**Response Codes:**
- `200`: Ok
- `400`: Bad Request
- `401`: Unauthorized
- `403`: Forbidden
- `404`: Not Found
- `500`: Internal Server Error

---

#### POST /plugin/{id}/disable

Disable a plugin.


**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| id (path) | string | Yes | the plugin id |

**Example Request:**
```bash
curl -X POST "$BASE_URL/plugin/123/disable" \
  -H "X-Api-Key: $API_KEY" \
  -H "Content-Type: application/json"
```
**Response Codes:**
- `200`: Ok
- `401`: Unauthorized
- `403`: Forbidden
- `404`: Not Found
- `500`: Internal Server Error

---

#### GET /plugin/{id}/display

Get display info for a Displayer plugin.


**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| id (path) | string | Yes | the plugin id |

**Example Request:**
```bash
curl -X GET "$BASE_URL/plugin/123/display" \
  -H "X-Api-Key: $API_KEY"
```
**Response Codes:**
- `200`: Ok
- `401`: Unauthorized
- `403`: Forbidden
- `404`: Not Found
- `500`: Internal Server Error

---

#### POST /plugin/{id}/enable

Enable a plugin.


**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| id (path) | string | Yes | the plugin id |

**Example Request:**
```bash
curl -X POST "$BASE_URL/plugin/123/enable" \
  -H "X-Api-Key: $API_KEY" \
  -H "Content-Type: application/json"
```
**Response Codes:**
- `200`: Ok
- `401`: Unauthorized
- `403`: Forbidden
- `404`: Not Found
- `500`: Internal Server Error

---

### user

#### GET /current/user

Return the current user.

**Example Request:**
```bash
curl -X GET "$BASE_URL/current/user" \
  -H "X-Api-Key: $API_KEY"
```
**Response Codes:**
- `200`: Ok
- `401`: Unauthorized
- `403`: Forbidden

---

#### POST /current/user/password

Update the password of the current user.


**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| body (body) | string | Yes | the user |

**Example Request:**
```bash
curl -X POST "$BASE_URL/current/user/password" \
  -H "X-Api-Key: $API_KEY" \
  -H "Content-Type: application/json"
```
**Response Codes:**
- `200`: Ok
- `400`: Bad Request
- `401`: Unauthorized
- `403`: Forbidden

---

#### GET /user

Return all users.

**Example Request:**
```bash
curl -X GET "$BASE_URL/user" \
  -H "X-Api-Key: $API_KEY"
```
**Response Codes:**
- `200`: Ok
- `401`: Unauthorized
- `403`: Forbidden

---

#### POST /user

Create a user.

With enabled registration: non admin users can be created without authentication.
With disabled registrations: users can only be created by admin users.


**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| body (body) | string | Yes | the user to add |

**Example Request:**
```bash
curl -X POST "$BASE_URL/user" \
  -H "X-Api-Key: $API_KEY" \
  -H "Content-Type: application/json"
```
**Response Codes:**
- `200`: Ok
- `400`: Bad Request
- `401`: Unauthorized
- `403`: Forbidden

---

#### GET /user/{id}

Get a user.


**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| id (path) | string | Yes | the user id |

**Example Request:**
```bash
curl -X GET "$BASE_URL/user/123" \
  -H "X-Api-Key: $API_KEY"
```
**Response Codes:**
- `200`: Ok
- `400`: Bad Request
- `401`: Unauthorized
- `403`: Forbidden
- `404`: Not Found

---

#### POST /user/{id}

Update a user.


**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| id (path) | string | Yes | the user id |
| body (body) | string | Yes | the updated user |

**Example Request:**
```bash
curl -X POST "$BASE_URL/user/123" \
  -H "X-Api-Key: $API_KEY" \
  -H "Content-Type: application/json"
```
**Response Codes:**
- `200`: Ok
- `400`: Bad Request
- `401`: Unauthorized
- `403`: Forbidden
- `404`: Not Found

---

#### DELETE /user/{id}

Deletes a user.


**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| id (path) | string | Yes | the user id |

**Example Request:**
```bash
curl -X DELETE "$BASE_URL/user/123" \
  -H "X-Api-Key: $API_KEY"
```
**Response Codes:**
- `200`: Ok
- `400`: Bad Request
- `401`: Unauthorized
- `403`: Forbidden
- `404`: Not Found

---

### version

#### GET /version

Get version information.

**Example Request:**
```bash
curl -X GET "$BASE_URL/version" \
  -H "X-Api-Key: $API_KEY"
```
**Response Codes:**
- `200`: Ok

---

## Version History

| API Version | Doc Version | Date | Changes |
|-------------|-------------|------|---------|
| 2.0.2 | 1.0.0 | 2026-02-01 | Initial documentation |

## Additional Resources

