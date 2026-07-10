# Plugin Display - Codex Skill

Diagnose and fix Windows-specific Codex plugin panel display issues.

## Problem

On Windows, Codex fails to register plugins correctly. The onboarding flow stalls, leaving 
178 official plugins unregistered. Custom marketpaces added via CLI are cleaned on restart.

## Fix Strategy

Merge all official plugins into the built-in `openai-api-curated` marketplace (which persists
across restarts), install them, and create junction points for primary runtime plugins.

## Files

| File | Description |
|---|---|
| `SKILL.md` | Complete diagnostic & fix guide (4 phases) |
| `scripts/fix_all.ps1` | One-click fix pipeline automation |
| `scripts/fix_marketplace_merge.py` | Merge marketplace plugins (Python) |
| `scripts/verify.ps1` | Plugin state diagnostic checker |
| `references/architecture.md` | Codex plugin architecture on Windows |