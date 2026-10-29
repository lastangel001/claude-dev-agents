## Pipeline

- Stack: {{stack}}. Active agents: {{active_agents}}. Not used here: {{inactive_agents}}.
- Every task starts by stating operation and size, then follows the row in [docs/PIPELINE.md](docs/PIPELINE.md).
- Mandatory for every change: {{always_stages}}. One-way doors ({{one_way_doors}}): add `architect` and `design-reviewer`.
- Mode `{{autonomy}}`: Gate 1 after Clarify, Gate 2 before Deliver; an agent's `NEEDS_INPUT` / `BLOCKED` is shown verbatim.
- Artifacts: ADRs {{adr_path}}, QA {{qa_path}}, backlog {{backlog_path}}. Reports in {{language}}.
