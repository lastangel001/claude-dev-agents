# ADR-0001: Treat the local repo's agent/skill names as the authoritative uninstall manifest

## Context

`claude-dev-agents` is a distribution package, not a runtime application. Its only
"behavior" is the installer pair (`install.sh`, `install.ps1`) that copies
`agents/*.md` and `skills/*/` into a target Claude Code config directory
(`~/.claude` for user scope, `./.claude` for project scope). There is no compiled
artifact, no manifest, and no version file (`no VERSION/CHANGELOG/CONTRIBUTING`
confirmed in discovery).

The install set is computed by **auto-discovery** at runtime — every `.md` under
`agents/` and every directory under `skills/` is installed (`install.sh:52-58`,
`install.ps1:43-49`). This is a deliberate, well-documented design choice ("no list
to maintain", `install.sh:3`, `README.md:62`) and it is correct for *install*.

The decision under review is a one-way-door for the **uninstall** path, because it
shapes what user data the tool is allowed to delete. The uninstaller reuses the same
auto-discovered set to decide what to remove:

- `install.sh:73-74` — `rm -f "${AGENTS_DIR}/${a}.md"` and `rm -rf "${SKILLS_DIR}/${s}"`
- `install.ps1:66-67` — `Remove-Item ... -Recurse -Force`

The forces at play:

1. **The uninstall target is the user's live config**, which may contain agents and
   skills from other sources, hand edits, or a *different version* of this package.
2. The set being deleted is derived from **whatever repo the script currently sits
   next to** (or a freshly downloaded `main` tarball, `install.sh:39-50`), not from a
   record of **what this tool actually installed**. These two sets can diverge:
   - If the user installed v1 (which shipped `php-developer`) and later runs
     `--uninstall` from a v2 checkout that renamed it to `php-builder`, the v1 file is
     orphaned (never removed) and a same-named v2 file the user authored could be
     removed instead.
   - `skills/*` removal is `rm -rf` of an entire directory under the user's config; a
     name collision with a user-authored skill of the same name means silent data loss.
3. There is **no record of provenance** — nothing marks a file as "installed by
   claude-dev-agents", so the uninstaller cannot distinguish its own artifacts from
   the user's. The backup mechanism (`install.sh:60-69`) protects the *install*
   overwrite path but does **not** cover the *uninstall* delete path.

This is a genuine one-way-door: deleting user config files is not cheaply reversible,
and the blast radius is the user's global `~/.claude` directory.

## Decision

Adopt and **document explicitly** the current behavior as an intentional contract,
with one safety boundary added at the design level (to be implemented by an
implementation agent — this ADR does not change code):

1. **Install** stays name-keyed and auto-discovered (unchanged — it is correct).
2. **Uninstall** must remove only artifacts it can prove it owns. The chosen mechanism
   is a **per-run install receipt**: on install, write a manifest
   (`<scope>/.claude/.cda-backups/installed.json` or a sibling
   `<scope>/.claude/.cda-manifest.json`) listing the exact relative paths written and
   a content hash for each. Uninstall reads this receipt and removes only files whose
   current hash still matches the recorded hash; anything modified by the user after
   install is left in place and reported, not deleted.
3. Until the receipt exists, uninstall of `skills/*` must not `rm -rf` a directory whose
   contents differ from what this package ships (fail safe: warn and skip, do not delete).

The receipt — not the current working tree — becomes the authoritative uninstall
manifest. Auto-discovery remains the authoritative *install* manifest.

## Consequences

### Positive
- Uninstall can no longer delete a user-authored agent/skill that merely shares a name
  with a package artifact — closes the silent-data-loss path on `install.sh:73-74` /
  `install.ps1:66-67`.
- Renames/removals across package versions stop orphaning old files: the receipt
  records what *this install* actually placed, independent of the current tree.
- Provenance becomes explicit and auditable; the tool gains a clear ownership boundary
  at the trust edge (user's config directory).
- Symmetry with the existing backup philosophy ("never let Claude Code load a stray
  artifact", `install.sh:60-61`) — the receipt extends the same care to deletion.

### Negative
- Adds a small amount of state (one JSON receipt) and hashing logic to both installers,
  modestly increasing the maintenance surface that the "no list to maintain" ethos
  (`install.sh:3`) was designed to minimize.
- A missing/corrupt receipt requires a defined fallback (recommended: refuse to delete
  and tell the user to remove files manually) — slightly less convenient than today's
  unconditional delete.
- Two installer implementations (bash + PowerShell) must keep receipt format in lock-step,
  duplicating the logic across `install.sh` and `install.ps1`.

### Alternatives considered
- **Keep current behavior, document the risk only** — cheapest, but leaves a real
  data-loss footgun on the user's global config; rejected for a one-way-door operation.
- **Namespace-prefix every artifact** (e.g. `cda-php-developer.md`) so uninstall can glob
  by prefix — robust ownership signal, but breaks the agent/skill `name:` ↔ filename
  relationship Claude Code relies on, changes user-facing invocation names, and pollutes
  the listing; rejected.
- **Per-file marker comment / frontmatter key** (e.g. `x-installed-by: claude-dev-agents`)
  parsed on uninstall — works for agents (markdown) but is awkward for multi-file skill
  directories and still can't detect user edits; weaker than a hashed receipt; rejected.
- **Drop uninstall entirely, tell users to delete manually** — eliminates the risk but
  removes a documented feature (`README.md:79-83`); rejected as a usability regression.

## Status
Accepted — implemented in `install.sh` / `install.ps1` (`.cda-manifest` receipt). The
receipt format is a zero-dependency `<relpath>\t<sha256>` text file rather than JSON, so
neither installer needs a JSON parser; this is an implementation refinement of the format
named in the Decision, not a change to the decision itself.

## Date
2026-06-06
