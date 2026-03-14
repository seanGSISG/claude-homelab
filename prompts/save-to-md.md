Save the entire current session as a markdown document.

Target path:
- If arguments are provided, use `$ARGUMENTS` as the output path.
- If no path is provided, save to `docs/sessions/YYYY-MM-DD-description.md` in the current working directory.
- Path must stay inside the current repo root for this workflow; if outside, report and stop.
- If the target filename already exists, do not overwrite; append `-v2`, `-v3`, etc.

Required sections:
1. Session overview
2. Timeline of major activities
3. Key findings with `path:line` references when relevant
4. Technical decisions and rationale
5. Files modified/created and purpose
6. Critical commands executed and outcomes
7. Behavior changes (before/after)
8. Verification evidence (`command | expected | actual | status`)
9. Source IDs + collections touched (embed/retrieve source IDs, collections, outcomes)
10. Risks and rollback
11. Decisions not taken
12. Open questions
13. Next steps

Quality requirements:
- Keep it concise but verifiable.
- Do not expose secrets.
- Prefer concrete facts over narrative.
- Facts only; do not infer values that were not observed in command/tool output.
- If uncertain, put it in Open questions.
- Target max 5 bullets per section, but exceed when needed for completeness of implementation details, verification evidence, or risk/safety context.

After writing the markdown file, embedding with Axon is **mandatory** (always attempt):
1. Determine the final saved path (explicit argument path or generated `docs/sessions/...` path).
2. Optional preflight (recommended, not a substitute for embedding):
   - `axon status`
   - If required services are unavailable, still continue and attempt embed/retrieve; report failures explicitly.
3. Run embed and capture the job ID from the initial response:
   - `axon embed "<saved-session-markdown-path>" --json`
   - The initial JSON contains `data.job_id` (status `"queued"`) — **not** `data.url`/`data.collection`. Those are only available after the job completes.
4. Do not pass `--url`, `--source-id`, or `--collection` for this workflow.
   - Local embeds derive source ID automatically.
   - Local embeds route to the repo-name collection automatically.
5. Poll for completion and extract source metadata:
   - `axon embed status "<job_id-from-step-3>" --json`
   - Capture `data.url` (source ID) and `data.collection` from **this** output (not the initial embed response).
   - Retry if status is still `"running"` or `"queued"`.
6. Verify indexing using status output values (not assumptions):
   - `axon retrieve "<source-id-from-status-data.url>" --collection "<collection-from-status-data.collection>"`
   - If retrieve fails, report the error and the attempted source ID + collection.
7. You must always attempt both embed and retrieve verification. If Axon embed/retrieve fails due to environment or service availability, report clearly but continue Neo4j capture.
8. If embed succeeds but retrieve fails, report Axon as partial failure (embed success, verify failed).

After writing the markdown file, store session knowledge in Neo4j memory using MCP tools.

Create entities for:
- Files (`type: file`)
- Services (`type: service`)
- Features (`type: feature`)
- Bugs (`type: bug`)
- Technologies (`type: technology`)
- Concepts (`type: concept`)

Create relations where applicable:
- Files -> Services: `BELONGS_TO`, `CONFIGURES`, `IMPLEMENTS`
- Features -> Files: `IMPLEMENTED_IN`, `REQUIRES`
- Bugs -> Files: `FOUND_IN`, `FIXED_IN`
- Technologies -> Features: `USED_BY`, `ENABLES`
- Services -> Technologies: `DEPENDS_ON`, `USES`

Add observations that capture:
- What was done
- Why it was done
- How it was done
- When it was done
- Challenges/gotchas

Neo4j payload format requirements (critical):
- For all Neo4j MCP calls, pass arrays of native objects/dictionaries.
- Never pass JSON as strings (no `"{...}"` items, no `JSON.stringify(...)` payload elements).
- `create_entities.entities` must be `[{ name, type, observations: [...] }, ...]`.
- `create_relations.relations` must be `[{ source, target, relationType }, ...]`.
- `add_observations.observations` must be `[{ entityName, observations: [...] }, ...]`.
- If a call fails with a schema/model_type error, retry once with object literals and report the retry.

Use tools in this order:
1. `mcp__neo4j-memory__create_entities`
2. `mcp__neo4j-memory__create_relations`
3. `mcp__neo4j-memory__add_observations`

Return:
- Final saved path
- Axon embed status (success/failure) and source ID used
- Counts of entities/relations/observations created
- Any warnings or skipped items
