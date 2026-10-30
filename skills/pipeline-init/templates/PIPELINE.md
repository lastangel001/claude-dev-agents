# Pipeline — {{project}}

<!-- Written by the pipeline-init skill on {{date}} from the signals scan and the answers below.
     Re-run /pipeline-init to update: it diffs the signals against this file and proposes changes.
     Language of this file: the user's. -->

## Project facts

- **Stack:** {{stack}}
- **Source of the architecture map:** {{architecture_source}}
- **CI:** {{ci}}
- **Review process:** {{review_process}}
- **Tracker:** {{tracker}}
- **Output language:** {{language}}

## Active agents

| Role | Agent or skill | Notes |
|---|---|---|
| Builder | {{builder}} | |
| Code reviewer | {{code_reviewer}} | |
| Contract reviewer | `contract-reviewer` | runs only when a changed call leaves the module |
| Security pass | `security-reviewer` | runs only on a security trigger |
| Verifier | `review-verifier` | before anything is published to an author or a PR |
| Design | `architect`, `design-reviewer` | one-way doors only |
| QA | `qa-expert`, `test-automator` | rigor `standard` and above |
| Delivery | {{delivery}} | |

Named by the masks but **not active** in this project: {{inactive_agents}}.

## One-way doors in this project

{{one_way_doors}}

## Stages by operation and size

Stage numbers refer to the skeleton in the `pipeline-init` skill (`references/stages.md`):
0 Investigate · 1 Clarify · 2 Design · 3 Pressure-test · 4 Test strategy · 5 Implement · 6 Code review ·
7 Contract review · 8 Security · 9 Verify findings · 10 Address review · 11 Coverage · 12 Deliver.

| Operation | trivial | small | standard | large |
|---|---|---|---|---|
| feature | {{m_feature_trivial}} | {{m_feature_small}} | {{m_feature_standard}} | {{m_feature_large}} |
| change | {{m_change_trivial}} | {{m_change_small}} | {{m_change_standard}} | {{m_change_large}} |
| fix | {{m_fix_trivial}} | {{m_fix_small}} | {{m_fix_standard}} | {{m_fix_large}} |
| refactor | {{m_refactor_trivial}} | {{m_refactor_small}} | {{m_refactor_standard}} | {{m_refactor_large}} |
| greenfield | — | — | {{m_greenfield_standard}} | {{m_greenfield_large}} |
| research | {{m_research_trivial}} | {{m_research_small}} | {{m_research_standard}} | {{m_research_large}} |

Size: take the highest tier reached by files touched, new dependency or contract, or design
ambiguity; anything touching a security trigger or a public contract is at least `standard`.
State the operation and size in one line at Gate 1 so the user can override.

## Gates and autonomy

- **Mode:** `{{autonomy}}` (propose → guided → autonomous; raise after tasks run without manual correction)
- **Gate 1** after Clarify and Design: requirements, ADR if any, stage mask with size, active set. Nothing implemented before it is shown.
- **Gate 2** before Deliver: diff summary, verdicts, open questions, the delivery checklist. Nothing pushed, merged or released before it is shown.

## Security triggers

{{security_triggers}}

## Terminal states

An agent that ends with `NEEDS_INPUT`, `BLOCKED` or `OUT_OF_SCOPE` stops the pipeline at that stage;
the state is shown to the user verbatim. A second `NEEDS_INPUT` from the same stage on the same task
moves that stage into the main loop.

## Artifacts

| Artifact | Path |
|---|---|
| ADRs | {{adr_path}} |
| Test strategy, coverage matrix | {{qa_path}} |
| Environment spec | {{env_path}} |
| Backlog | {{backlog_path}} |

## Project rules for agents

<!-- One subsection per ACTIVE agent (the table above). Every agent's contract reads this file
     and its own subsection before its defaults; the main loop also pastes the subsection into
     the brief. Keep each one short: where this role writes, what it must never touch, what the
     project adds to the role's defaults. Delete subsections for agents that are not active. -->

### {{builder}}

- Writes: {{builder_writes}}
- Never touches: {{builder_never}}
- Project rules: {{builder_rules}}

### {{code_reviewer}}

- Conventions to honour: {{reviewer_conventions}}
- Severity notes for this project: {{reviewer_severity_notes}}

### architect

- ADRs: {{adr_path}}; numbering and status words as the existing ADRs use them

### qa-expert

- Strategy and matrix: {{qa_path}}; test levels this project runs: {{test_levels}}

### test-automator

- E2E suite root and runner: {{e2e_root}}; environment spec: {{env_path}}

### devops-engineer

- CI files: {{ci_files}}; protected paths: {{protected_paths}}; secrets policy: names only

## Definition of done

{{definition_of_done}}

## Before delivery (Gate 2 checklist)

- Every stage in the mask ran, or the report says which did not and why.
- CRITICAL and HIGH findings closed or explicitly accepted.
- The diff stayed inside the declared scope; any excess named and authorised.
- Tests prove the changed behaviour.
- Required artifacts exist and are current.
- Rollback or revert path stated for anything deployed or migrated.
- Documentation naming the changed behaviour updated or listed as drift.

## Signals at the time of writing

```
{{signals}}
```
