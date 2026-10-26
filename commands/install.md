---
description: Install the 4-line usage status line into ~/.claude/settings.json
allowed-tools: Bash(python:*), Bash(python3:*)
---

Run this command with the Bash tool (use `python3` if `python` is not found):

```
python "${CLAUDE_PLUGIN_ROOT}/scripts/install.py"
```

Then tell the user, in their language, what it printed (backup file, install path, any warning about missing `bash` or `jq`), and that the status line shows up on the next message.
