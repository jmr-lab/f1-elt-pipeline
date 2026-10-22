#!/usr/bin/env python3
import sys
from pathlib import Path

SRC = Path(sys.argv[1] if len(sys.argv) > 1 else "docs/formula1_erd.mmd")
DEST = Path(sys.argv[2] if len(sys.argv) > 2 else "dbt/target/erd.html")

TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Formula1 Data Model</title>
<style>
  body { margin: 0; font-family: system-ui, -apple-system, sans-serif; color: #1a1a1a; }
  header { padding: 14px 22px; border-bottom: 1px solid #e6e6e6; font-size: 15px; }
  header a { color: #6d4aff; text-decoration: none; }
  #diagram { padding: 22px; overflow: auto; text-align: center; }
</style>
</head>
<body>
<header><strong>Formula1 Data Model</strong> &nbsp;·&nbsp; <a href="./">← dbt docs</a></header>
<div id="diagram" class="mermaid">
__DIAGRAM__
</div>
<script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
<script>mermaid.initialize({ startOnLoad: true });</script>
</body>
</html>
"""

def main():
    if not SRC.exists():
        sys.exit(f"ERROR: {SRC} not found")
    DEST.parent.mkdir(parents=True, exist_ok=True)
    DEST.write_text(TEMPLATE.replace("__DIAGRAM__", SRC.read_text().strip()))
    print(f"Wrote {DEST} ({DEST.stat().st_size} bytes)")

if __name__ == "__main__":
    main()
