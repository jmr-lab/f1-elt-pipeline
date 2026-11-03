#!/usr/bin/env python3
"""Wrap Databricks HTML export with project header using Bootstrap."""

import sys
from bs4 import BeautifulSoup

def wrap_with_header(html_content: str, project_name: str = "Formula 1 Portfolio") -> str:
    """Inject Bootstrap-styled header into Databricks export."""
    
    soup = BeautifulSoup(html_content, 'html.parser')
    
    # Add Bootstrap CDN in head (if not present)
    bootstrap_link = soup.new_tag(
        'link',
        href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css",
        rel="stylesheet"
    )
    soup.head.append(bootstrap_link)
    
    # Create scoped header container
    header_html = f'''
<div id="project-header-wrapper">
<nav class="navbar navbar-expand-lg navbar-dark bg-primary mb-4" style="border-radius: 0;">
  <div class="container-fluid">
    <a class="navbar-brand fw-bold" href="#">{project_name}</a>
    <ul class="navbar-nav ms-auto">
      <li class="nav-item"><a class="nav-link" href="../index.html">Home</a></li>
      <li class="nav-item"><a class="nav-link active" href="#">Dashboard</a></li>
    </ul>
  </div>
</nav>
<style>
#project-header-wrapper {{
  position: relative;
  z-index: 1000;
}}
#project-header-wrapper .navbar {{
  margin-bottom: 1rem !important;
}}
/* Isolate from Databricks styles */
#project-header-wrapper * {{
  font-family: system-ui, -apple-system, sans-serif !important;
}}
</style>
</div>
'''
    
    # Insert after opening body tag
    if soup.body:
        soup.body.insert(0, BeautifulSoup(header_html, 'html.parser'))
    
    return str(soup)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: wrap_dashboard.py <input.html> <output.html>", file=sys.stderr)
        sys.exit(1)
    
    input_path, output_path = sys.argv[1], sys.argv[2]
    
    with open(input_path, 'r', encoding='utf-8') as f:
        html = f.read()
    
    wrapped = wrap_with_header(html)
    
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(wrapped)
    
    print(f"Wrote {output_path}")
