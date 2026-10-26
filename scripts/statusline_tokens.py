#!/usr/bin/env python3
"""Sum token usage of one Claude Code session (or a whole project folder).

Usage: statusline_tokens.py <session_transcript.jsonl | project_transcript_dir>
Prints one line: "<total> <input> <output> <cache_write> <cache_read>".
Per-file results are cached by (mtime, size) so only changed files are re-read.
"""
import json
import os
import sys

CACHE_DIR = os.path.join(os.path.expanduser("~"), ".claude", "statusline-cache")


def scan_file(path):
    totals = [0, 0, 0, 0]  # input, output, cache_write, cache_read
    seen = set()
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            if '"usage"' not in line:
                continue
            try:
                entry = json.loads(line)
            except ValueError:
                continue
            msg = entry.get("message") or {}
            usage = msg.get("usage") if isinstance(msg, dict) else None
            if not isinstance(usage, dict):
                continue
            # Streaming can write the same response on several lines
            key = (msg.get("id"), entry.get("requestId"))
            if key[0] and key in seen:
                continue
            seen.add(key)
            totals[0] += usage.get("input_tokens") or 0
            totals[1] += usage.get("output_tokens") or 0
            totals[2] += usage.get("cache_creation_input_tokens") or 0
            totals[3] += usage.get("cache_read_input_tokens") or 0
    return totals


def main():
    if len(sys.argv) < 2:
        return
    target = os.path.abspath(sys.argv[1])
    if os.path.isfile(target):
        # Session mode: the transcript file plus its "<session-id>/" folder (subagents)
        paths = [target]
        scan_dir = os.path.splitext(target)[0]
    elif os.path.isdir(target):
        # Project mode: every transcript in the project folder
        paths = []
        scan_dir = target
    else:
        return
    os.makedirs(CACHE_DIR, exist_ok=True)
    cache_path = os.path.join(CACHE_DIR, os.path.basename(scan_dir) + ".json")

    try:
        with open(cache_path, "r", encoding="utf-8") as f:
            cache = json.load(f)
    except (OSError, ValueError):
        cache = {}

    new_cache = {}
    sums = [0, 0, 0, 0]
    changed = False
    # Include subagent transcripts stored in nested folders
    for root, _dirs, files in os.walk(scan_dir):
        paths.extend(os.path.join(root, n) for n in files if n.endswith(".jsonl"))
    for path in paths:
        try:
            st = os.stat(path)
        except OSError:
            continue
        old = cache.get(path)
        if old and old[0] == st.st_mtime and old[1] == st.st_size:
            totals = old[2]
        else:
            try:
                totals = scan_file(path)
            except OSError:
                continue
            changed = True
        new_cache[path] = [st.st_mtime, st.st_size, totals]
        for i in range(4):
            sums[i] += totals[i]

    if changed or len(new_cache) != len(cache):
        tmp = cache_path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(new_cache, f)
        os.replace(tmp, cache_path)

    print(sum(sums), *sums)


if __name__ == "__main__":
    main()
