<!--
Sync Impact Report
- Version change: (template, unratified) → 1.0.0
- Principles defined (all new; template placeholders replaced):
  - [PRINCIPLE_1_NAME] → I. One Design Language: Project SEKAI
  - [PRINCIPLE_2_NAME] → II. Preserve the Existing Configuration
  - [PRINCIPLE_3_NAME] → III. Every Big Migration Has a Rollback Plan
  - [PRINCIPLE_4_NAME] → IV. Tests Come With Every Integration
  - [PRINCIPLE_5_NAME] → V. Reproducible on Any Machine
- Added sections: "Plugins and Integrations" (SECTION_2), "Development Workflow and Quality
  Gates" (SECTION_3), Governance rules
- Removed sections: none
- Templates: none modified (dependent templates read this file at runtime)
- Deferred TODOs: none
-->

# SekaiPop Constitution

SekaiPop is a Linux rice (a Quickshell + Hyprland desktop) built to one vision: Project SEKAI
COLORFUL STAGE! as a whole desktop. It is the owner's default setup, meant to be installed on any
PC they reinstall, and it grows through plugins and modifications of their own.

## Core Principles

### I. One Design Language: Project SEKAI

Every surface the shell draws (bar, popups, panels, Settings, Edit Desktop, desktop widgets,
plugins) MUST follow `docs/DESIGN-SYSTEM.md`:

- Blocks are built one way: outline, ring, fill, hard shadow straight down. No soft shadows,
  glows or blur.
- Colours, sizes and fonts MUST come from the theme (`mt` / `host.theme`), never hard-coded,
  except the fixed set the design system lists.
- Motion pops out of its source with overshoot and shrinks back into it; it does not fade out
  in place.
- A narrow or unusual screen (a portrait monitor) gets a rearranged layout of the same
  components; it MUST NOT get a squeezed, overlapping or clipped one.
- A change that departs from the design system MUST update `docs/DESIGN-SYSTEM.md` in the
  same change.

Rationale: the vision is the product. A feature that works but looks bolted on fails it.

### II. Preserve the Existing Configuration

The existing configuration, the project's and the user's, is followed and kept as it is unless
a change is specifically fixing a bug or modifying a direct dependency of what is being built.

- New work MUST follow the patterns already in the code (services as singletons, pure UI files
  fed through properties, `.pragma library` JS for logic, settings through `SettingsService`,
  state through the `scripts/state` helpers) rather than introduce parallel ones.
- Unrelated refactors, renames and reformatting MUST NOT ride along with a feature or fix.
- Anything the user configured (Hyprland edits, `custom/` files, settings, presets, plugin
  folders, secrets) MUST survive installs and updates. Where an update must replace a file the
  user changed, their version MUST be kept or merged, never silently overwritten.
- A behaviour change to an existing feature MUST be opt-in or default to the old behaviour,
  unless the old behaviour is the bug being fixed.

Rationale: this is the owner's daily desktop; a lost mouse setting or a moved key is a
regression, whatever else improved.

### III. Every Big Migration Has a Rollback Plan

A big migration (anything that moves, renames, rewrites or converts user files or state, changes
a config format, replaces a subsystem, or raises the plugin API version) MUST ship with a
rollback plan that is written down and works:

- What is replaced MUST be backed up first, under a time-stamped name, never deleted
  (as `hypr.sekaipop-backup-<time>`, `plugins.sekaipop-backup-<time>/` do).
- There MUST be a documented way back: a command (`./install.sh --restore`), an IPC call, or
  exact manual steps in the feature's doc.
- The migration MUST be safe to run twice and MUST support `--dry-run` where it runs from the
  installer.
- The rollback path MUST be exercised once (by a test or a recorded manual run) before release.

Rationale: a rice is installed onto machines that already have a life; a migration that cannot
be undone turns one bug into a lost setup.

### IV. Tests Come With Every Integration

Every new integration (a service, a plugin, an external API or program, an installer step, a
new state file) MUST land with unit tests that run in the repository's suite
(`sekaipop/tests/<area>-test/`, or a plugin's own `tests/`).

- Logic MUST be kept in pure functions (`.pragma library` JS, or shell helpers) so it can be
  tested without a running shell; QML wiring is checked by source tests, as the existing suite
  does.
- Tests MUST exercise the failure paths that matter (no network, missing dependency, refused
  token, a file the user changed), not only the happy path.
- A bug fix SHOULD add the test that would have caught it.
- A test MUST NOT be weakened to make a change pass; when intended behaviour changes, the test
  is updated to state the new behaviour.

Rationale: the shell cannot be run in CI; the suite is the only thing that tells a future change
it broke an old promise.

### V. Reproducible on Any Machine

SekaiPop MUST install from a bare system to the owner's setup with `get.sh` / `install.sh`, and
reinstall onto an existing one without loss.

- Everything the owner considers part of their rice (plugins, configuration, defaults) MUST be
  installable by the installer, not by hand.
- Machine-specific values (monitor names, output layouts, paths, hardware) MUST NOT be baked in
  as defaults or carried by desktop presets; they are detected or kept per machine.
- Secrets (API tokens, passwords) MUST never be written to settings, presets, logs or command
  lines; they live in the environment or in mode-600 files the user owns.
- The installer MUST state what it changes and keep backups (Principle III).

Rationale: the point of a personal default rice is that a new PC becomes "mine" in one run.

## Plugins and Integrations

- Features that serve one person, need their own account or token, or would not belong in
  every install MUST be built as plugins (`docs/PLUGINS.md`), not hard-wired into the shell.
  Bundled plugins live in `plugins/` and are installed by `install.sh`.
- Plugins rely only on the documented plugin interface (`host`, the manifest, the promised
  theme names). Changing the meaning of any part of it is a new plugin API version
  (`API_VERSION`) and a big migration under Principle III.
- Plugins MUST follow the design language (Principle I) by building from `host.theme`.
- Plugins MUST be configurable from their own UI where practical; no setup step may require
  editing a file by hand when the plugin can do it for the user.
- External services MUST be called with rate limits respected, only while the plugin is shown,
  and with failures shown in words.

## Development Workflow and Quality Gates

Before a change is considered done:

1. **Design**: it follows `docs/DESIGN-SYSTEM.md`, or updates it (Principle I).
2. **Scope**: it touches only what the fix or feature needs (Principle II).
3. **Tests**: the suite passes with no new failures against the base commit; new integrations
   bring their tests (Principle IV).
4. **Migration**: a big migration names its backup and its way back, and both were tried
   (Principle III).
5. **Docs**: user-facing behaviour is described in `docs/` and in `sekaipop/CHANGELOG.md`
   under "Unreleased", in the project's plain-words style.
6. **Verification**: visual changes are checked rendered (a screenshot or a sandbox render),
   at least at a normal and a narrow width.

Commits and pushes happen only when the owner asks for them.

## Governance

This constitution takes precedence over other practices in this repository. Where a document in
`docs/` and this constitution disagree, this constitution wins and the document is corrected.

- **Amendments**: proposed as a change to `.specify/memory/constitution.md` that states which
  principle changes and why, approved by the owner, and recorded with a new version and date.
- **Versioning**: semantic. MAJOR: a principle removed or redefined so that existing work could
  stop complying. MINOR: a principle or section added, or guidance materially expanded. PATCH:
  wording and clarifications with no change in meaning.
- **Compliance**: every spec, plan and review checks the work against the five principles and
  the quality gates. A deviation MUST be written down with its reason and the simpler option
  that was rejected; an undocumented deviation is a defect.

**Version**: 1.0.0 | **Ratified**: 2026-11-25 | **Last Amended**: 2026-11-25
