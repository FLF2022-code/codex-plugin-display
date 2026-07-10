#!/usr/bin/env python3
"""Merge openai-curated marketplace plugins into openai-api-curated marketplace.
This fixes the issue where openai-curated (178 plugins) uses a reserved name
that cannot be registered from local sources on Windows."""

import json
import os
import sys

def main():
    home = os.path.expanduser("~")
    regular_path = os.path.join(home, ".codex", ".tmp", "plugins", ".agents", "plugins", "marketplace.json")
    api_path = os.path.join(home, ".codex", ".tmp", "plugins", ".agents", "plugins", "api_marketplace.json")

    if not os.path.exists(regular_path):
        print(f"ERROR: {regular_path} not found")
        sys.exit(1)
    if not os.path.exists(api_path):
        print(f"ERROR: {api_path} not found")
        sys.exit(1)

    with open(regular_path, "r", encoding="utf-8") as f:
        regular = json.load(f)
    with open(api_path, "r", encoding="utf-8") as f:
        api_market = json.load(f)

    existing_names = {p["name"] for p in api_market["plugins"]}
    added = 0
    for plugin in regular["plugins"]:
        if plugin["name"] not in existing_names:
            entry = {
                "name": plugin["name"],
                "source": {"source": "local", "path": plugin["source"]["path"]},
                "policy": {
                    "installation": plugin["policy"].get("installation", "AVAILABLE"),
                    "authentication": plugin["policy"].get("authentication", "ON_INSTALL"),
                },
                "category": plugin.get("category", "Productivity"),
            }
            api_market["plugins"].append(entry)
            added += 1

    api_market["plugins"].sort(key=lambda x: x["name"])

    with open(api_path, "w", encoding="utf-8") as f:
        json.dump(api_market, f, indent=2, ensure_ascii=False)

    print(f"Merged {added} plugins into openai-api-curated marketplace")
    print(f"Total plugins in api_marketplace.json: {len(api_market['plugins'])}")

if __name__ == "__main__":
    main()