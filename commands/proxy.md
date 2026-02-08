---
description: Create reverse proxy config for deployed services
argument-hint: <server_name> <upstream_app> <upstream_port> [protocol] [auth]
allowed-tools: Bash(ssh *), Bash(rsync *)
---

Create a SWAG reverse proxy configuration from the template and deploy it to the SWAG server.

## Parse Arguments

Arguments received: $ARGUMENTS

Expected format: `server_name upstream_app upstream_port [protocol] [auth]`

Parse into variables:
- `server_name`: Subdomain name (required, position 1)
- `upstream_app`: Container name or host IP (required, position 2)
- `upstream_port`: Service port number (required, position 3)
- `protocol`: http or https (optional, position 4, default: http)
- `auth`: auth or noauth (optional, position 5, default: auth)

## Validation

Verify all inputs before proceeding:
1. server_name, upstream_app, and upstream_port are provided
2. upstream_port is numeric (1-65535)
3. protocol is either 'http' or 'https' (if provided)
4. auth flag is either 'auth' or 'noauth' (if provided)

If validation fails, explain the error and show correct usage.

## Template Processing

1. Read template: `~/.claude/templates/swag_template.subdomain.conf`
2. Replace all instances of placeholders:
   - `<container_name>` → {server_name}
   - `<port_number>` → {upstream_port}
   - `<http or https>` → {protocol}
3. Handle authentication:
   - If auth='auth': Uncomment the line `#include /config/nginx/authelia-location.conf` (remove the `#` at start of line)
   - If auth='noauth': Leave authentication lines commented
4. Remove all lines containing the text "REMOVE THIS LINE BEFORE SUBMITTING"
5. Save processed config to temporary file: `/tmp/{server_name}.subdomain.conf`

## Deployment

1. Check if file exists on target:
   ```bash
   ssh squirts "test -f /mnt/appdata/swag/nginx/proxy-confs/{server_name}.subdomain.conf && echo 'exists' || echo 'new'"
   ```

2. If file exists, create backup:
   ```bash
   ssh squirts "cp /mnt/appdata/swag/nginx/proxy-confs/{server_name}.subdomain.conf /mnt/appdata/swag/nginx/proxy-confs/{server_name}.subdomain.conf.bak"
   ```

3. Deploy the configuration:
   ```bash
   rsync -avz /tmp/{server_name}.subdomain.conf squirts:/mnt/appdata/swag/nginx/proxy-confs/
   ```

4. Verify deployment:
   ```bash
   ssh squirts "ls -lh /mnt/appdata/swag/nginx/proxy-confs/{server_name}.subdomain.conf"
   ```

5. Clean up temporary file:
   ```bash
   rm /tmp/{server_name}.subdomain.conf
   ```

## Report Results

Provide a summary including:
- Configuration file created: {server_name}.subdomain.conf
- Upstream target: {upstream_app}:{upstream_port}
- Protocol: {protocol}
- Authentication: {enabled/disabled}
- Backup created: {yes/no}
- Deployment status: {success/failed}
- Note: SWAG will automatically reload the configuration

## Error Handling

If any step fails:
- SSH connectivity issues: Check if squirts host is accessible
- Template not found: Verify ~/.claude/templates/swag_template.subdomain.conf exists
- Invalid parameters: Show usage and expected format
- Rsync failure: Check network connectivity and permissions
- Provide clear error message and suggested resolution
