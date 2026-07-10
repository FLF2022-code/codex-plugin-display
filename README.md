# Plugin Display - Codex Skill
诊断并修复 Windows 平台上 Codex 插件面板的显示问题。
Diagnose and fix Windows-specific Codex plugin panel display issues.

## Problem
在 Windows 上，使用第三方大模型接入Codex时，无法正确注册插件，导致引导流程卡住，且 178 个官方插件未能注册。
通过 CLI 添加的自定义市场在重启后会被清除。
On Windows, when using third-party large models to connect to Codex, the plugin registration fails, 
causing the onboarding process to stall and preventing the registration of 178 official plugins. Custom 
marketplaces added via the CLI are wiped after a restart.

## Fix Strategy
将所有官方插件合并至内置的 `openai-api-curated` 市​​场（该市场在重启后数据依然保留），进行安装，并为主要运行时插件创建连接点（junction points）。
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
