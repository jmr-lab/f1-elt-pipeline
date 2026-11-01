#!/usr/bin/env python3
"""
Build ADR documentation pages from markdown files.
Generates individual HTML pages for ADRs and converts README.md to index.html.
Uses the same Bootstrap theme as the main index.html for consistency.
"""

import os
import markdown
from pathlib import Path

ADR_SOURCE_DIR = "docs/adr"
SITE_ADR_DIR = "site/adr"

# Matches index.html hero section
HEADER_HTML = """
  <header class="hero py-5">
    <div class="container py-3">
      <span class="badge text-bg-light text-dark mb-3">Architecture Decisions</span>
      <h1 class="display-5 fw-bold">F1 Data Project</h1>
      <p class="lead mb-0">
        Architecture Decision Records documenting the pipeline design choices.
      </p>
    </div>
  </header>
"""

BASE_TEMPLATE = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#f8f9fa">
  <title>{title} - F1 Data Project</title>

  <link rel="icon" type="image/png" href="../favicon.png">
  <link
    href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/css/bootstrap.min.css"
    rel="stylesheet"
    integrity="sha384-sRIl4kxILFvY47J16cr9ZwB07vP4J8+LH7qKQnuqkuIAvNWLzeN8tE5YBujZqJLB"
    crossorigin="anonymous">

  <style>
    body {{ background: #f4f6f9; }}
    .resource-card {{ transition: transform 160ms ease, box-shadow 160ms ease; }}
    .resource-card:hover {{ transform: translateY(-4px); box-shadow: 0 1rem 2rem rgba(0, 0, 0, 0.12); }}
    .hero {{ background: linear-gradient(135deg, #15151e, #e10600); color: white; }}
    article {{ max-width: 900px; margin: 0 auto; padding: 2rem; background: white; border-radius: 0.5rem; box-shadow: 0 0.5rem 1rem rgba(0, 0, 0, 0.08); }}
    h1 {{ color: #15151e; border-bottom: 3px solid #e10600; padding-bottom: 0.5rem; margin-bottom: 1.5rem; }}
    h2 {{ color: #15151e; margin-top: 2rem; }}
    .metadata {{ color: #6c757d; font-size: 0.9rem; margin-bottom: 2rem; padding-bottom: 1rem; border-bottom: 1px solid #dee2e6; }}
    .back-link {{ margin-top: 2rem; padding-top: 1rem; border-top: 1px solid #dee2e6; }}
    code {{ background: #f8f9fa; padding: 0.125rem 0.375rem; border-radius: 0.25rem; }}
    pre {{ background: #f8f9fa; padding: 1rem; border-radius: 0.5rem; overflow-x: auto; }}
    table {{ width: 100%; border-collapse: collapse; margin: 1rem 0; }}
    th, td {{ padding: 0.5rem; border: 1px solid #dee2e6; text-align: left; }}
    th {{ background: #f8f9fa; }}
    .breadcrumb-nav {{ padding: 1rem 0; background: white; border-radius: 0.25rem; margin-bottom: 2rem; }}
  </style>
</head>
<body>
{HEADER}
  <main class="container py-5">
<article>
<div class="breadcrumb-nav">
  <nav aria-label="breadcrumb">
    <ol class="breadcrumb">
      <li class="breadcrumb-item"><a href="../index.html">Home</a></li>
      <li class="breadcrumb-item active">ADRs</li>
    </ol>
  </nav>
</div>
{content}
<div class="back-link">
  <a href="../index.html" class="btn btn-outline-secondary">&larr; Back to home</a>
</div>
</article>
  </main>

  <footer class="text-center text-secondary small mt-5">
    Formula 1 Data Project
  </footer>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/js/bootstrap.bundle.min.js" integrity="sha384-pprnSPW4jJv7q8qKqCqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqK" crossorigin="anonymous"></script>
</body>
</html>
""".replace("{HEADER}", HEADER_HTML)


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


def wrap_html(content: str, title: str = "Architecture Decision Records") -> str:
    """Wrap markdown content with the HTML template."""
    return BASE_TEMPLATE.format(title=title, content=content)


def main():
    source_path = Path(ADR_SOURCE_DIR)
    output_path = Path(SITE_ADR_DIR)

    # Ensure output directory exists
    output_path.mkdir(parents=True, exist_ok=True)

    # Convert each ADR markdown file (except README.md)
    md_files = sorted(source_path.glob("*.md"))
    for md_file in md_files:
        if md_file.name == "template.md":
            continue
        
        content = md_file.read_text(encoding="utf-8")
        
        # For README.md, use it as index.html
        if md_file.name == "README.md":
            html_body = markdown.markdown(content, extensions=['fenced_code', 'tables', 'toc'])
            html_page = wrap_html(html_body, "Architecture Decision Records")
            output_file = output_path / "index.html"
            output_file.write_text(html_page, encoding="utf-8")
            print(f"Generated: {output_file}")
        
        # For other ADRs, generate individual pages
        else:
            title, status, body_content = parse_frontmatter(content)
            html_body = markdown.markdown(body_content, extensions=['fenced_code', 'tables', 'toc'])
            html_page = BASE_TEMPLATE.format(title=title, content=html_body)
            output_file = output_path / f"{md_file.stem}.html"
            output_file.write_text(html_page, encoding="utf-8")
            print(f"Generated: {output_file}")


if __name__ == "__main__":
    main()
