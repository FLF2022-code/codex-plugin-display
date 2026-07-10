# verify.ps1 - Check Codex plugin state

$codexCli = 'D:\WindowsApps\OpenAI.Codex_26.616.9593.0_x64__2p2nqsd0c76g0\app\resources\codex.exe'

Write-Host "=== 1. Marketplaces ==="
& $codexCli plugin marketplace list 2>&1

Write-Host "`n=== 2. Plugin Status ==="
$list = & $codexCli plugin list 2>&1
$installed = ($list | Select-String "installed, enabled" | Measure-Object).Count
$notInstalled = ($list | Select-String "not installed" | Measure-Object).Count
Write-Host "Installed: $installed"
Write-Host "Available: $notInstalled"
Write-Host "Total: $($installed + $notInstalled)"

Write-Host "`n=== 3. Onboarding State ==="
Get-Content "$env:USERPROFILE\.codex\.codex-global-state.json" -Encoding UTF8 | Select-String "plugin-checklist|primary.runtime" -AllMatches | ForEach-Object { $_.Line }

Write-Host "`n=== 4. Junction Points ==="
$plugins = @("documents", "pdf", "presentations", "spreadsheets", "template-creator")
foreach ($p in $plugins) {
    $path = "$env:USERPROFILE\plugins\$p"
    $exists = Test-Path $path
    if ($exists) {
        $item = Get-Item $path
        if ($item.LinkType) {
            Write-Host "$p: Junction -> $($item.Target)"
        } else {
            Write-Host "$p: Directory"
        }
    } else {
        Write-Host "$p: NOT FOUND"
    }
}

Write-Host "`n=== 5. Marketplace File ==="
$apiPath = "$env:USERPROFILE\.codex\.tmp\plugins\.agents\plugins\api_marketplace.json"
if (Test-Path $apiPath) {
    $apiMarket = Get-Content $apiPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host "api_marketplace.json: $($apiMarket.plugins.Count) plugins"
}