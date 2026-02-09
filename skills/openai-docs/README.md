# OpenAI Documentation Search

Semantic search over OpenAI's official documentation using MCP (Model Context Protocol) server.

## What It Does

- Searches OpenAI documentation semantically (understands context, not just keywords)
- Provides relevant documentation sections for API usage questions
- Covers all OpenAI products:
  - Chat Completions API
  - Assistants API
  - Function Calling (Tool Use)
  - Vision API
  - DALL-E Image Generation
  - Whisper Speech-to-Text
  - Text-to-Speech (TTS)
  - Embeddings
  - Moderation
  - Fine-tuning

All operations are read-only documentation queries powered by the `llama_index_docs` MCP server.

## Setup

### MCP Server Configuration

This skill requires the `llama_index_docs` MCP server to be configured in Claude Code.

**Check if configured:**
```bash
# MCP servers are configured in Claude Code settings
# This skill uses: mcp__llama_index_docs__*
```

If the skill doesn't work, the MCP server may need to be added to your Claude Code configuration. Contact support or check Claude Code documentation for MCP server setup.

### No Credentials Required

This skill uses the MCP server connection already configured in Claude Code. No API keys or authentication needed.

## Usage Examples

### Search for API Usage

Ask Claude questions about OpenAI APIs:

```
"How do I use function calling with GPT-4?"
"Show me examples of streaming chat completions"
"What parameters does the Assistants API support?"
"How do I generate images with DALL-E 3?"
```

Claude will use this skill automatically when you ask OpenAI-related questions.

### Direct Skill Invocation

You can explicitly invoke the skill:

```
"Use the OpenAI docs skill to search for vision API examples"
"Search OpenAI documentation for fine-tuning best practices"
```

## How It Works

1. **Semantic Search** - Query is converted to embeddings and matched against OpenAI docs
2. **Relevant Sections** - Returns most relevant documentation sections
3. **Context-Aware** - Understands intent, not just keyword matching
4. **Up-to-Date** - Documentation is indexed from official OpenAI sources

## MCP Tools Used

This skill uses these MCP tools:
- `mcp__llama_index_docs__search_docs` - Semantic search over documentation
- `mcp__llama_index_docs__read_doc` - Read full documentation pages
- `mcp__llama_index_docs__grep_docs` - Pattern-based search in docs

## Troubleshooting

### "MCP tool not available"

The `llama_index_docs` MCP server is not configured. Check:
1. Claude Code MCP settings
2. Server is running and accessible
3. Correct server name in configuration

### No search results

Try:
- Rephrasing your query
- Using more specific terms
- Breaking complex questions into smaller parts
- Checking if the topic is covered in OpenAI docs

### Outdated information

The MCP server's documentation index may need updating. Check:
- When the index was last refreshed
- If the topic is from a recent OpenAI release
- Official OpenAI documentation for latest changes

## Notes

- Read-only operations (no API calls to OpenAI)
- Searches locally indexed documentation
- No rate limits or API keys required
- Results may not reflect bleeding-edge changes
- Always verify with official OpenAI documentation for production use

## Reference

- **OpenAI Platform Docs:** https://platform.openai.com/docs
- **OpenAI API Reference:** https://platform.openai.com/docs/api-reference
- **OpenAI Cookbook:** https://cookbook.openai.com/
- **MCP Protocol:** https://modelcontextprotocol.io/

---

**Version:** 1.0.0
**Type:** Read-Only
**Dependencies:** llama_index_docs MCP server
