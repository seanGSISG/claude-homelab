# Changelog

All notable changes to the fail2ban-swag skill will be documented in this file.

## [1.0.0] - 2026-02-07

### Added
- Initial release of fail2ban-swag skill
- Complete SKILL.md with mandatory invocation warnings and user-specific setup details
- Comprehensive wrapper script (`scripts/fail2ban-swag.sh`) with 20+ commands
- Quick reference guide with copy-paste command examples
- Filter examples reference with 15+ pre-built attack patterns
- Detailed troubleshooting guide covering all common issues
- User-friendly README.md with setup instructions and workflows

### Features
- Monitor fail2ban status and active jails
- View and manage banned IPs
- Create custom jails and filters
- Test filter regex against actual logs
- View fail2ban and nginx logs in real-time
- Search for specific IPs across all logs
- Backup and restore configurations
- Troubleshoot common issues

### Documentation
- Integration with NotebookLM research findings
- Reference to setup documentation and research findings
- Links to official fail2ban and SWAG documentation
- Progressive disclosure pattern with references/ files

### Configuration
- Configurable via environment variables (SWAG_HOST, SWAG_CONTAINER_NAME, SWAG_APPDATA_PATH)
- Container: swag (LinuxServer.io image)
- Supports any SWAG deployment
- Common jails documented
- Network whitelisting guidance provided
