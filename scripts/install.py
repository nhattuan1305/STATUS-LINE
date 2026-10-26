#!/usr/bin/env python3
"""Copy the status line scripts to ~/.claude/status-line/ and point settings.json at them.

Copying (instead of pointing at the plugin folder) keeps the status line working
after the plugin cache moves to a new version folder.
"""
import json
import os
import shutil
import sys
import time

SRC = os.path.dirname(os.path.abspath(__file__))
CLAUDE_DIR = os.path.join(os.path.expanduser("~"), ".claude")
DEST = os.path.join(CLAUDE_DIR, "status-line")
SETTINGS = os.path.join(CLAUDE_DIR, "settings.json")


def main():
    os.makedirs(DEST, exist_ok=True)
    for name in ("statusline.sh", "statusline_tokens.py"):
        shutil.copy2(os.path.join(SRC, name), os.path.join(DEST, name))

    settings = {}
    if os.path.exists(SETTINGS):
        with open(SETTINGS, "r", encoding="utf-8") as f:
            settings = json.load(f)  # fail loudly on a broken file rather than overwrite it
        backup = SETTINGS + ".bak-statusline-" + time.strftime("%Y%m%d%H%M%S")
        shutil.copy2(SETTINGS, backup)
        print("Backup:", backup)

    script = os.path.join(DEST, "statusline.sh").replace("\\", "/")
    settings["statusLine"] = {"type": "command", "command": 'bash "%s"' % script}
    tmp = SETTINGS + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp, SETTINGS)
    print("Installed:", script)

    missing = [t for t in ("bash", "jq") if not shutil.which(t)]
    if missing:
        print("Warning: not found on PATH:", ", ".join(missing), file=sys.stderr)


if __name__ == "__main__":
    main()
