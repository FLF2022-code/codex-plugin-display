---
name: plugin-display
description: "Diagnose and fix Windows-specific Codex plugin panel display issues. Use when: (1) Codex plugin panel shows very few plugins instead of the expected 200+, (2) the official marketplace plugins are missing after installation or restart, (3) plugins appear in CLI but not in the desktop app UI, (4) onboarding plugin checklist stays active indefinitely, (5) plugins were downloaded/cached but not visible. This skill handles the Windows junction/symlink mechanism, marketplace registration, and built-in marketplace merging that Codex on Windows requires."
---

# Plugin Display

## Overview

On Windows, Codex may fail to register and display plugins correctly due to a gap between the download phase and the installation/activation phase. Plugins get cached to `~/.codex/plugins/cache/` but never appear in the app's plugin panel.

**Root cause:** Codex's onboarding flow (`onboarding-plugin-checklist-active`) can stall on Windows, leaving the built-in `openai-curated` marketplace (178 plugins) registered but not activated. Custom marketplaces added via `codex plugin marketplace add` are cleaned from `config.toml` on restart.

**How this skill fixes it:** Merges all official plugins into the built-in `openai-api-curated` marketplace (which persists across restarts), installs them, and creates directory junction points for the primary runtime plugins.

---

## Diagnostic Steps

Run these checks before applying any fix:

1. Check current marketplaces:
```
codex plugin marketplace list
```
Expected: `openai-api-curated` should be present (it is built-in).

2. Check how many plugins are registered vs installed:
```
codex plugin list
```
Look at `installed` vs `not installed` counts.

3. Check config.toml for marketplace sections:
```
Get-Content ~/.codex/config.toml | Select-String "marketplaces"
```
If marketplace entries exist, they will be cleaned on next restart.

4. Check onboarding state:
```
Get-Content ~/.codex/.codex-global-state.json | Select-String "plugin-checklist|primary.runtime"
```
`onboarding-plugin-checklist-active: true` means the plugin flow is stuck.

5. Check if marketplace files exist:
```
Test-Path ~/.codex/.tmp/plugins/.agents/plugins/marketplace.json
Test-Path ~/.codex/.tmp/plugins/.agents/plugins/api_marketplace.json
```
The `marketplace.json` contains `openai-curated` (reserved name, 178 plugins).
The `api_marketplace.json` contains `openai-api-curated` (built-in, originally 28 plugins).

---

## Fix Procedures

### Phase 1: Fix Primary Runtime Plugins

The 5 primary runtime plugins (documents, pdf, presentations, spreadsheets, template-creator) are cached at `~/.codex/plugins/cache/openai-primary-runtime/{name}/{version}/`. Create junction points so they are discovered:

```powershell
$plugins = @("documents", "pdf", "presentations", "spreadsheets", "template-creator")
foreach ($p in $plugins) {
    $source = "$env:USERPROFILE\.codex\plugins\cache\openai-primary-runtime\$p\26.622.11653"
    $target = "$env:USERPROFILE\plugins\$p"
    if (-not (Test-Path $target)) {
        New-Item -ItemType Junction -Path $target -Target $source -Force
    }
}
```

Run `scripts/fix_primary_runtime.ps1` to automate this.

### Phase 2: Merge Marketplace Plugins

The official `openai-curated` marketplace (178 plugins) uses a reserved name. The `openai-api-curated` marketplace IS built-in and persists across restarts. Merge the 178 plugins into `api_marketplace.json`:

```powershell
$regularPath = "$env:USERPROFILE\.codex\.tmp\plugins\.agents\plugins\marketplace.json"
$apiPath = "$env:USERPROFILE\.codex\.tmp\plugins\.agents\plugins\api_marketplace.json"

$regular = Get-Content $regularPath -Raw -Encoding UTF8 | ConvertFrom-Json
$apiMarket = Get-Content $apiPath -Raw -Encoding UTF8 | ConvertFrom-Json

$apiNames = @{}; foreach ($p in $apiMarket.plugins) { $apiNames[$p.name] = $true }

foreach ($p in $regular.plugins) {
    if (-not $apiNames.ContainsKey($p.name)) {
        $newEntry = @{
            name = $p.name
            source = @{ source = "local"; path = $p.source.path }
            policy = @{ installation = $p.policy.installation; authentication = $p.policy.authentication }
            category = $p.category
        }
        $apiMarket.plugins += $newEntry
    }
}

$apiMarket.plugins = $apiMarket.plugins | Sort-Object -Property name
$jsonString = $apiMarket | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($apiPath, $jsonString, [System.Text.UTF8Encoding]::new($false))
```

Run `scripts/fix_marketplace_merge.py` to automate this (preferred) or use the PowerShell version above.

### Phase 3: Install Plugins

Install the merged plugins via CLI:

```powershell
$codexCli = 'D:\WindowsApps\OpenAI.Codex_26.616.9593.0_x64__2p2nqsd0c76g0\app\resources\codex.exe'
$list = & $codexCli plugin list --marketplace openai-api-curated 2>&1
$plugins = $list | Select-String "not installed" | ForEach-Object {
    if ($_ -match '^(\S+@\S+)') { $matches[1] }
}
foreach ($p in $plugins) {
    & $codexCli plugin add "$p" 2>&1 | Out-Null
}
```

### Phase 4: Update Onboarding State

```powershell
$gsPath = "$env:USERPROFILE\.codex\.codex-global-state.json"
$gsContent = Get-Content $gsPath -Raw -Encoding UTF8
$gsContent = $gsContent -replace '"electron:onboarding-plugin-checklist-active":true', '"electron:onboarding-plugin-checklist-active":false'
[System.IO.File]::WriteAllText($gsPath, $gsContent, [System.Text.UTF8Encoding]::new($false))
```

---

## Verification

After applying the fix, verify with:
```
codex plugin marketplace list
codex plugin list
```

Expected: 3 marketplaces (personal, openai-api-curated with ~178 plugins, openai-api-curated).
All plugins show as `installed, enabled` after Phase 3.

Restart Codex desktop app to confirm plugins appear in the plugin panel.

---

## References

- **references/architecture.md** - Explains Codex plugin architecture on Windows (marketplace system, cache structure, discovery paths)
- **references/faq.md** - Troubleshooting common scenarios

## Scripts

- **scripts/fix_all.ps1** - Runs the full fix pipeline (Phase 1-4) in one command
- **scripts/fix_marketplace_merge.py** - Merges `openai-curated` plugins into `openai-api-curated` marketplace (Phase 2)
- **scripts/verify.ps1** - Diagnostic checks for the current plugin state
