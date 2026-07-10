# fix_all.ps1 - Complete fix for Codex plugin display on Windows
# Run this script with: powershell -ExecutionPolicy Bypass -File fix_all.ps1

$codexCli = 'D:\WindowsApps\OpenAI.Codex_26.616.9593.0_x64__2p2nqsd0c76g0\app\resources\codex.exe'
$homeDir = $env:USERPROFILE

Write-Host "=== Phase 1: Fix Primary Runtime Plugins ==="
$plugins = @("documents", "pdf", "presentations", "spreadsheets", "template-creator")
foreach ($p in $plugins) {
    $source = "$homeDir\.codex\plugins\cache\openai-primary-runtime\$p\26.622.11653"
    $target = "$homeDir\plugins\$p"
    if (Test-Path $source) {
        if (-not (Test-Path $target)) {
            New-Item -ItemType Junction -Path $target -Target $source -Force | Out-Null
            Write-Host "  ✓ Created junction: $p"
        } else {
            Write-Host "  - Already exists: $p"
        }
    } else {
        Write-Host "  ✗ Cache not found: $p"
    }
}

Write-Host "`n=== Phase 2: Merge Marketplace ==="
$regularPath = "$homeDir\.codex\.tmp\plugins\.agents\plugins\marketplace.json"
$apiPath = "$homeDir\.codex\.tmp\plugins\.agents\plugins\api_marketplace.json"

if ((Test-Path $regularPath) -and (Test-Path $apiPath)) {
    $regular = Get-Content $regularPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $apiMarket = Get-Content $apiPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $apiNames = @{}; foreach ($p in $apiMarket.plugins) { $apiNames[$p.name] = $true }
    
    $count = 0
    foreach ($p in $regular.plugins) {
        if (-not $apiNames.ContainsKey($p.name)) {
            $apiMarket.plugins += @{
                name = $p.name
                source = @{ source = "local"; path = $p.source.path }
                policy = @{ installation = $p.policy.installation; authentication = $p.policy.authentication }
                category = $p.category
            }
            $count++
        }
    }
    $apiMarket.plugins = $apiMarket.plugins | Sort-Object -Property name
    $jsonString = $apiMarket | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($apiPath, $jsonString, [System.Text.UTF8Encoding]::new($false))
    Write-Host "  ✓ Merged $count plugins into openai-api-curated marketplace"
} else {
    Write-Host "  ✗ Marketplace files not found"
}

Write-Host "`n=== Phase 3: Install Plugins ==="
if (Test-Path $codexCli) {
    $list = & $codexCli plugin list --marketplace openai-api-curated 2>&1
    $toInstall = $list | Select-String "not installed" | ForEach-Object {
        if ($_ -match '^(\S+@\S+)') { $matches[1] }
    }
    $success = 0
    foreach ($p in $toInstall) {
        $result = & $codexCli plugin add "$p" 2>&1
        if ($LASTEXITCODE -eq 0) { $success++ }
    }
    Write-Host "  ✓ Installed $success/$($toInstall.Count) plugins"
    
    # Also install personal plugins
    & $codexCli plugin add documents@personal 2>&1 | Out-Null
    & $codexCli plugin add pdf@personal 2>&1 | Out-Null
    & $codexCli plugin add presentations@personal 2>&1 | Out-Null
    & $codexCli plugin add spreadsheets@personal 2>&1 | Out-Null
    & $codexCli plugin add template-creator@personal 2>&1 | Out-Null
    Write-Host "  ✓ Primary runtime plugins installed"
} else {
    Write-Host "  ✗ Codex CLI not found at: $codexCli"
}

Write-Host "`n=== Phase 4: Update Onboarding State ==="
$gsPath = "$homeDir\.codex\.codex-global-state.json"
$gsContent = Get-Content $gsPath -Raw -Encoding UTF8
$gsContent = $gsContent -replace '"electron:onboarding-plugin-checklist-active":true', '"electron:onboarding-plugin-checklist-active":false'
[System.IO.File]::WriteAllText($gsPath, $gsContent, [System.Text.UTF8Encoding]::new($false))
Write-Host "  ✓ Onboarding state updated"

Write-Host "`n=== Verification ==="
$final = & $codexCli plugin list 2>&1
$installed = ($final | Select-String "installed, enabled" | Measure-Object).Count
Write-Host "  Total installed plugins: $installed"
Write-Host "`nDone! Please restart the Codex app."