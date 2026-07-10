# Codex Plugin Architecture on Windows

## Directory Structure

```
~/.codex/
├── config.toml                     # Runtime config (marketplaces, plugins state)
├── .codex-global-state.json        # Electron app state (onboarding, UI state)
├── plugins/
│   ├── cache/                      # Installed plugin files
│   │   ├── personal/               # Personal marketplace plugins
│   │   ├── openai-primary-runtime/ # Built-in runtime plugins (documents, pdf, etc.)
│   │   ├── openai-api-curated/     # API-curated marketplace plugins
│   │   └── codex-imported/         # Previously imported (legacy)
│   └── cache/openai-primary-runtime/
│       └── {name}/{version}/       # Cached but uninstalled plugins
├── .tmp/plugins/
│   ├── .agents/plugins/
│   │   ├── marketplace.json        # openai-curated (178 plugins, RESERVED name)
│   │   └── api_marketplace.json    # openai-api-curated (built-in, 28+178 plugins)
│   └── plugins/                    # Plugin source directories
│       └── {name}/                 # Individual plugin: .codex-plugin/, assets/, skills/
├── skills/                         # Codex skill files
└── .agents/
    └── plugins/
        └── marketplace.json         # Personal marketplace (auto-discovered)

~/.agents/
└── plugins/
    └── marketplace.json             # Personal marketplace (auto-discovered, root=~)
```

## Marketplace System

Codex discovers plugins through marketplaces:

| Marketplace | Source | Persistence | Plugins |
|---|---|---|---|
| `personal` | `~/.agents/plugins/marketplace.json` (auto-discovered) | Root=~ | Personal plugins |
| `openai-api-curated` | Built-in + `api_marketplace.json` | **Persists across restarts** | 28+ API-curated plugins |
| `openai-curated` | `marketplace.json` + CDN | Reserved name, blocked from local add | 178 official plugins |
| Custom (e.g. `codex-imported`) | `config.toml` via `codex plugin marketplace add` | **Cleaned on restart** | User-added |

## The Key Insight

`openai-api-curated` is the ONLY marketplace that persists across app restarts. It is built into the Codex application binary. Custom marketplaces added via `codex plugin marketplace add` are stored in `config.toml` but get cleaned on the next app start.

The `openai-curated` marketplace (178 plugins) is reserved - it cannot be added from local sources. It is supposed to be activated during the onboarding flow, but this flow can stall on Windows.

## The Fix Strategy

Merge the 178 plugins from the reserved `openai-curated` marketplace into the `openai-api-curated` marketplace by modifying `api_marketplace.json`. Since `openai-api-curated` is built-in, its file definition persists and the merged plugins are visible after restart.

## Installation vs Registration

- `codex plugin marketplace add <path>` = Register a marketplace. Stored in `config.toml` (non-persistent).
- `codex plugin add <name>@<marketplace>` = Install a plugin from a registered marketplace. Files go to `plugins/cache/{marketplace}/{name}/`.
- `codex plugin remove <name>@<marketplace>` = Remove an installed plugin.
- Plugin discovery happens during app startup - both from marketplace definitions and from the `plugins/cache/` directory.