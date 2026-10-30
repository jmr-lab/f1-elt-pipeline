#!/usr/bin/env python3
"""
Build ADR documentation pages from markdown files.
Generates individual HTML pages plus an index listing all ADRs.
"""

import os
import markdown
from pathlib import Path

ADR_SOURCE_DIR = "docs/adr"
SITE_ADR_DIR = "site/adr"

# Bootstrap 5 HTML template matching your index.html style
BASE_TEMPLATE = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#f8f9fa">
  <title>{title} - F1 Data Project</title>
  <link rel="icon" type="image/png" href="../favicon.png">
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-sRIl4kxILFvY47J16cr9ZwB07vP4J8+LH7qKQnuqkuIAvNWLzeN8tE5YBujZqJLB" crossorigin="anonymous">
  <style>
    body {{ background: #f4f6f9; }}
    article {{ max-width: 900px; margin: 2rem auto; padding: 2rem; background: white; border-radius: 0.5rem; box-shadow: 0 0.5rem 1rem rgba(0, 0, 0, 0.08); }}
    h1 {{ color: #15151e; border-bottom: 3px solid #e10600; padding-bottom: 0.5rem; margin-bottom: 1.5rem; }}
    h2 {{ color: #15151e; margin-top: 2rem; }}
    .metadata {{ color: #6c757d; font-size: 0.9rem; margin-bottom: 2rem; padding-bottom: 1rem; border-bottom: 1px solid #dee2e6; }}
    .back-link {{ margin-top: 2rem; padding-top: 1rem; border-top: 1px solid #dee2e6; }}
    code {{ background: #f8f9fa; padding: 0.125rem 0.375rem; border-radius: 0.25rem; }}
    pre {{ background: #f8f9fa; padding: 1rem; border-radius: 0.5rem; overflow-x: auto; }}
    table {{ width: 100%; border-collapse: collapse; margin: 1rem 0; }}
    th, td {{ padding: 0.5rem; border: 1px solid #dee2e6; text-align: left; }}
    th {{ background: #f8f9fa; }}
  </style>
</head>
<body>
<article>
{content}
<div class="back-link">
  <a href="../index.html" class="btn btn-outline-secondary">&larr; Back to home</a>
</div>
</article>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/js/bootstrap.bundle.min.js" integrity="sha384-pprnSPW4jJv7q8qKqCqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqK" crossorigin="anonymous"></script>
</body>
</html>
"""

INDEX_TEMPLATE = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#f8f9fa">
  <title>Architecture Decision Records - F1 Data Project</title>
  <link rel="icon" type="image/png" href="../favicon.png">
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-sRIl4kxILFvY47J16cr9ZwB07vP4J8+LH7qKQnuqkuIAvNWLzeN8tE5YBujZqJLB" crossorigin="anonymous">
  <style>
    body {{ background: #f4f6f9; }}
    article {{ max-width: 900px; margin: 2rem auto; padding: 2rem; background: white; border-radius: 0.5rem; box-shadow: 0 0.5rem 1rem rgba(0, 0, 0, 0.08); }}
    h1 {{ color: #15151e; border-bottom: 3px solid #e10600; padding-bottom: 0.5rem; margin-bottom: 1.5rem; }}
    .adr-list {{ list-style: none; padding: 0; }}
    .adr-item {{ padding: 1rem; margin-bottom: 0.5rem; background: #f8f9fa; border-left: 4px solid #6d4aff; border-radius: 0 0.25rem 0.25rem 0; }}
    .adr-item:hover {{ background: #e9ecef; }}
    .adr-meta {{ color: #6c757d; font-size: 0.85rem; }}
    .back-link {{ margin-top: 2rem; padding-top: 1rem; border-top: 1px solid #dee2e6; }}
  </style>
</head>
<body>
<article>
<h1>Architecture Decision Records</h1>
<p class="lead">Documentation of significant design decisions behind the F1 ELT pipeline.</p>

<ul class="adr-list">
{adr_links}
</ul>

<div class="back-link">
  <a href="../index.html" class="btn btn-outline-secondary">&larr; Back to home</a>
</div>
</article>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/js/bootstrap.bundle.min.js" integrity="sha384-pprnSPW4jJv7q8qKqCqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqK" crossorigin="anonymous"></script>
</body>
</html>
"""


def parse_frontmatter(content: str) -> tuple[str, str]:
    """Extract title and status from markdown frontmatter."""
    lines = content.split('\n')
    title = None
    status = None
    body_start = 0

    for i, line in enumerate(lines):
        if line.startswith('# '):
            title = line[2:].strip()
            body_start = i + 1
            break

    for line in lines:
        if 'Status:' in line:
            status = line.split('Status:')[1].strip()
            break

    return title, status, '\n'.join(lines[body_start:])


def build_index(adrs: list[tuple[str, str, str]]) -> str:
    """Generate the ADR index page."""
    links = []
    for num, title, status in adrs:
        link = f'<li class="adr-item"><a href="{num}.html"><strong>{num}</strong>: {title}</a><br><span class="adr-meta">Status: {status}</span></li>'
        links.append(link)
    return INDEX_TEMPLATE.format(adr_links='\n'.join(links))


def main():
    adrs = []
    source_path = Path(ADR_SOURCE_DIR)
    output_path = Path(SITE_ADR_DIR)

    # Ensure output directory exists
    output_path.mkdir(parents=True, exist_ok=True)

    # Convert each ADR markdown file
    md_files = sorted(source_path.glob("*.md"))
    for md_file in md_files:
        if md_file.name == "template.md":
            continue

        content = md_file.read_text(encoding="utf-8")
        title, status, body_content = parse_frontmatter(content)

        # Convert markdown to HTML
        html_body = markdown.markdown(body_content, extensions=['fenced_code', 'tables', 'toc'])

        # Wrap with template
        html_page = BASE_TEMPLATE.format(title=title, content=html_body)

        # Write output
        output_file = output_path / f"{md_file.stem}.html"
        output_file.write_text(html_page, encoding="utf-8")

        # Track for index
        adrs.append((md_file.stem, title, status or "Unknown"))
        print(f"Generated: {output_file}")

    # Generate index page
    index_html = build_index(adrs)
    index_path = output_path / "index.html"
    index_path.write_text(index_html, encoding="utf-8")
    print(f"Generated: {index_path}")


if __name__ == "__main__":
    main()
