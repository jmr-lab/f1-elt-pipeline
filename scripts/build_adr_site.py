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
      <li class="breadcrumb-item"><a href="index.html">ADRs</a></li>
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
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/js/bootstrap.bundle.min.js" integrity="sha384-pprnSPW4jJv7q8qKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqK" crossorigin="anonymous"></script>
</body>
</html>
""".replace("{HEADER}", HEADER_HTML)

INDEX_TEMPLATE = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#f8f9fa">
  <title>Architecture Decision Records - F1 Data Project</title>

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
    .adr-list {{ list-style: none; padding: 0; }}
    .adr-item {{ padding: 1rem; margin-bottom: 0.5rem; background: #f8f9fa; border-left: 4px solid #6d4aff; border-radius: 0 0.25rem 0.25rem 0; }}
    .adr-item:hover {{ background: #e9ecef; }}
    .adr-meta {{ color: #6c757d; font-size: 0.85rem; }}
    .back-link {{ margin-top: 2rem; padding-top: 1rem; border-top: 1px solid #dee2e6; }}
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

<h1>Architecture Decision Records</h1>
<p class="lead">Documentation of significant design decisions behind the F1 ELT pipeline.</p>

<ul class="adr-list">
{adr_links}
</ul>

<div class="back-link">
  <a href="../index.html" class="btn btn-outline-secondary">&larr; Back to home</a>
</div>
</article>
  </main>

  <footer class="text-center text-secondary small mt-5">
    Formula 1 Data Project
  </footer>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/js/bootstrap.bundle.min.js" integrity="sha384-pprnSPW4jJv7q8qKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqKqK" crossorigin="anonymous"></script>
</body>
</html>
""".replace("{HEADER}", HEADER_HTML)
