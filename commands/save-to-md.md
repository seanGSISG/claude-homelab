---
description: Save session documentation with Neo4j memory integration
argument-hint: [output-path]
allowed-tools: Write, mcp__neo4j-memory__create_entities, mcp__neo4j-memory__create_relations, mcp__neo4j-memory__add_observations
---

# Save Session Documentation

Document the **entire conversation session** (not just recent work) as a markdown file at `$ARGUMENTS`. If no path is provided, save to `.docs/tmp/[relevant-name].md` in the current working directory.

## Documentation Requirements

Include in the markdown file:
1. **Session Overview**: Brief summary of what was accomplished
2. **Timeline**: Chronological breakdown of major activities
3. **Key Findings**: Important discoveries with file paths and line numbers where relevant
4. **Technical Decisions**: Reasoning behind implementation choices
5. **Files Modified**: List of all files created/modified with purpose
6. **Commands Executed**: Critical bash commands and their results
7. **Next Steps**: Any remaining tasks or follow-up items

Keep findings concise but include enough detail for verification. Use file:line references (e.g., `server.ts:45`) for code-specific findings.

## Neo4j Memory Integration

After saving the markdown file, extract and store session knowledge in Neo4j:

### Entities to Create:
- **Files**: All files created, modified, or discussed (type: "file")
- **Services**: Services deployed, configured, or debugged (type: "service")
- **Features**: Features implemented or planned (type: "feature")
- **Bugs**: Issues discovered and fixed (type: "bug")
- **Technologies**: Libraries, frameworks, tools used (type: "technology")
- **Concepts**: Important patterns, techniques, or approaches (type: "concept")

### Relations to Create:
- Files → Services: `BELONGS_TO`, `CONFIGURES`, `IMPLEMENTS`
- Features → Files: `IMPLEMENTED_IN`, `REQUIRES`
- Bugs → Files: `FOUND_IN`, `FIXED_IN`
- Technologies → Features: `USED_BY`, `ENABLES`
- Services → Technologies: `DEPENDS_ON`, `USES`

### Observations to Add:
For each entity, add observations capturing:
- What was done (e.g., "Implemented OAuth2 token refresh")
- Why it was done (e.g., "Required for persistent authentication")
- How it was done (e.g., "Used @azure/msal-node library")
- When it was done (current session date)
- Any challenges or gotchas encountered

Use the neo4j-memory MCP tools:
1. `mcp__neo4j-memory__create_entities` - Create all identified entities
2. `mcp__neo4j-memory__create_relations` - Link related entities
3. `mcp__neo4j-memory__add_observations` - Enrich with session details