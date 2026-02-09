#!/usr/bin/env python3
"""
Generate API endpoint documentation from OpenAPI specs.
Outputs markdown following homelab documentation patterns.

Usage:
    python3 generate-api-docs.py <spec-file> <service-name>

Example:
    python3 generate-api-docs.py skills/overseerr/references/overseerr-api.yml "Overseerr"
"""

import yaml
import json
import sys
from pathlib import Path
from typing import Dict, List, Any
from datetime import datetime


def parse_openapi(spec_file: str) -> Dict[str, Any]:
    """Parse OpenAPI YAML or JSON specification."""
    try:
        with open(spec_file) as f:
            if spec_file.endswith(('.yml', '.yaml')):
                return yaml.safe_load(f)
            return json.load(f)
    except FileNotFoundError:
        print(f"Error: File not found: {spec_file}", file=sys.stderr)
        sys.exit(1)
    except (yaml.YAMLError, json.JSONDecodeError) as e:
        print(f"Error parsing spec file: {e}", file=sys.stderr)
        sys.exit(1)


def group_endpoints_by_tag(spec: Dict[str, Any]) -> Dict[str, List[Dict]]:
    """
    Group endpoints by OpenAPI tags (functional categories).
    Returns: {tag_name: [endpoints]}
    """
    groups = {}
    paths = spec.get('paths', {})

    if not paths:
        print("Warning: No paths found in OpenAPI spec", file=sys.stderr)
        return groups

    for path, methods in paths.items():
        for method, details in methods.items():
            if method.lower() not in ['get', 'post', 'put', 'delete', 'patch']:
                continue

            tags = details.get('tags', ['Uncategorized'])
            tag = tags[0]  # Use first tag for grouping

            if tag not in groups:
                groups[tag] = []

            groups[tag].append({
                'path': path,
                'method': method.upper(),
                'summary': details.get('summary', 'No description'),
                'description': details.get('description', ''),
                'parameters': details.get('parameters', []),
                'requestBody': details.get('requestBody', {}),
                'responses': details.get('responses', {})
            })

    return groups


def generate_parameter_table(parameters: List[Dict]) -> str:
    """Generate markdown table for endpoint parameters."""
    if not parameters:
        return ""

    table = "\n**Parameters:**\n"
    table += "| Name | Type | Required | Description |\n"
    table += "|------|------|----------|-------------|\n"

    for param in parameters:
        name = param.get('name', '')
        param_in = param.get('in', '')
        schema = param.get('schema', {})
        param_type = schema.get('type', 'string')
        required = 'Yes' if param.get('required', False) else 'No'
        description = param.get('description', '').replace('\n', ' ').replace('|', '\\|')

        table += f"| {name} ({param_in}) | {param_type} | {required} | {description} |\n"

    return table + "\n"


def generate_curl_example(endpoint: Dict, base_url: str) -> str:
    """Generate working curl example for endpoint."""
    method = endpoint['method']
    path = endpoint['path']

    # Replace common path parameters with example values
    example_path = (path
        .replace('{id}', '123')
        .replace('{tmdbId}', '550')
        .replace('{tvdbId}', '121361')
        .replace('{deviceId}', 'device-123')
        .replace('{messageId}', 'msg-123')
    )

    curl = f'curl -X {method} "$BASE_URL{example_path}"'

    # Add authentication header (common pattern)
    curl += ' \\\n  -H "X-Api-Key: $API_KEY"'

    # Add Content-Type for POST/PUT/PATCH
    if method in ['POST', 'PUT', 'PATCH']:
        curl += ' \\\n  -H "Content-Type: application/json"'

    # Add example body for POST/PUT/PATCH
    if method in ['POST', 'PUT', 'PATCH'] and endpoint.get('requestBody'):
        curl += " \\\n  -d '{\"example\": \"data\"}'"

    return f"**Example Request:**\n```bash\n{curl}\n```\n"


def generate_markdown(spec: Dict[str, Any], service_name: str) -> str:
    """Generate complete markdown documentation."""
    info = spec.get('info', {})
    servers = spec.get('servers', [])

    # Header
    md = f"# {service_name} API Reference\n\n"

    # Metadata
    md += f"**API Version:** {info.get('version', 'Unknown')}\n"
    md += f"**Last Updated:** {datetime.now().strftime('%Y-%m-%d')}\n\n"

    if info.get('description'):
        md += f"{info['description']}\n\n"

    # Base URL
    if servers:
        base_url = servers[0].get('url', '')
        md += f"**Base URL:** `{base_url}`\n\n"
    else:
        md += "**Base URL:** `http://localhost:PORT` (configure based on your setup)\n\n"

    # Authentication section
    security_schemes = spec.get('components', {}).get('securitySchemes', {})
    if security_schemes:
        md += "## Authentication\n\n"
        for name, scheme in security_schemes.items():
            scheme_type = scheme.get('type', '')
            md += f"### {name}\n"
            md += f"**Type:** {scheme_type}\n\n"

            if scheme_type == 'apiKey':
                key_name = scheme.get('name', 'X-Api-Key')
                key_in = scheme.get('in', 'header')
                md += f"Add API key as `{key_name}` in {key_in}.\n\n"
                md += "```bash\n"
                md += f'-H "{key_name}: $API_KEY"\n'
                md += "```\n\n"
            elif scheme_type == 'http' and scheme.get('scheme') == 'bearer':
                md += "Use Bearer token authentication.\n\n"
                md += "```bash\n"
                md += '-H "Authorization: Bearer $TOKEN"\n'
                md += "```\n\n"

    # Quick start
    md += "## Quick Start\n\n"
    md += "```bash\n"
    md += "# Set environment variables\n"
    md += 'export BASE_URL="http://localhost:5055"\n'
    md += 'export API_KEY="your-api-key"\n\n'
    md += "# Test connection\n"
    md += 'curl -s "$BASE_URL/api/v1/status" -H "X-Api-Key: $API_KEY"\n'
    md += "```\n\n"

    # Endpoints by category
    md += "## Endpoints by Category\n\n"
    groups = group_endpoints_by_tag(spec)

    if not groups:
        md += "*No endpoints found in specification.*\n\n"
    else:
        for tag in sorted(groups.keys()):
            endpoints = groups[tag]
            md += f"### {tag}\n\n"

            for ep in endpoints:
                # Endpoint header
                md += f"#### {ep['method']} {ep['path']}\n\n"
                md += f"{ep['summary']}\n\n"

                # Description
                if ep['description']:
                    md += f"{ep['description']}\n\n"

                # Parameters
                md += generate_parameter_table(ep['parameters'])

                # Example
                base_url = servers[0].get('url', '') if servers else ''
                md += generate_curl_example(ep, base_url)

                # Response codes
                responses = ep.get('responses', {})
                if responses:
                    md += "**Response Codes:**\n"
                    for code, details in responses.items():
                        desc = details.get('description', 'No description')
                        md += f"- `{code}`: {desc}\n"
                    md += "\n"

                md += "---\n\n"

    # Footer
    md += "## Version History\n\n"
    md += "| API Version | Doc Version | Date | Changes |\n"
    md += "|-------------|-------------|------|---------|\n"
    md += f"| {info.get('version', 'Unknown')} | 1.0.0 | {datetime.now().strftime('%Y-%m-%d')} | Initial documentation |\n\n"

    md += "## Additional Resources\n\n"
    if 'externalDocs' in spec:
        md += f"- [Official Documentation]({spec['externalDocs'].get('url', '#')})\n"
    if 'x-repository' in info:
        md += f"- [GitHub Repository]({info['x-repository']})\n"
    elif 'contact' in info and 'url' in info['contact']:
        md += f"- [Project Website]({info['contact']['url']})\n"

    return md


def main():
    if len(sys.argv) < 3:
        print("Usage: generate-api-docs.py <spec-file> <service-name>")
        print("\nExample:")
        print("  python3 generate-api-docs.py skills/overseerr/references/overseerr-api.yml Overseerr")
        sys.exit(1)

    spec_file = sys.argv[1]
    service_name = sys.argv[2]

    print(f"Parsing {spec_file}...")
    spec = parse_openapi(spec_file)

    print(f"Generating markdown for {service_name}...")
    markdown = generate_markdown(spec, service_name)

    # Write output
    output_dir = Path(spec_file).parent
    output_file = output_dir / "api-endpoints.md"

    try:
        with open(output_file, 'w') as f:
            f.write(markdown)
    except IOError as e:
        print(f"Error writing output file: {e}", file=sys.stderr)
        sys.exit(1)

    line_count = len(markdown.splitlines())
    print(f"✅ Generated: {output_file}")
    print(f"   Lines: {line_count}")

    if line_count < 50:
        print("   ⚠️  Warning: Output seems short, check OpenAPI spec", file=sys.stderr)


if __name__ == "__main__":
    main()
