#!/usr/bin/env python3
"""
Build the analysis & transformation report page (site/report.html) from
docs/report.md.

Dynamic content (row counts, analysis extracts, table heads) is computed
directly from the SQLite databases produced by the pipeline:

  - dist/jolpica.db   (raw snapshot)  -> Chapter 2 extracts, dataset inventory
  - dist/formula1.db  (analytics)     -> correction tables, f1summary extract

Usage:
    python scripts/build_report_page.py [--raw PATH] [--analytics PATH]
                                        [--source PATH] [--output PATH]

Schema notes (verified against the Jolpica export):
  - session_entry: id, session_id, round_entry_id, grid, position, points
    (double), laps_completed, fastest_lap_rank, time, detail, status,
    is_classified (string), is_eligible_for_points (string), api_id
  - roundentry:    id, round_id, team_driver_id, car_number, api_id
  - round:         id, season_id, circuit_id, number, race_number, name,
                   date, is_cancelled, wikipedia, api_id
  - session:       id, round_id, type, number, timestamp, timezone,
                   scheduled_laps, point_system_id, is_cancelled,
                   has_time_data, api_id
Flag columns are strings compared against 'f' (t/f convention, matching
the companion R analysis). If Jolpica ever changes that convention, the
WHERE clauses below are the lines to adjust.
"""

import argparse
import math
import re
import sqlite3
from pathlib import Path

import markdown
import pandas as pd

# ---------------------------------------------------------------------------
# Paths (defaults match the GitHub Actions working tree)
# ---------------------------------------------------------------------------

DEFAULT_SOURCE = "docs/report.md"
DEFAULT_RAW_DB = "dist/jolpica.db"
DEFAULT_ANALYTICS_DB = "dist/formula1.db"
DEFAULT_OUTPUT = "site/report.html"

PLACEHOLDER_RE = re.compile(r"\{\{\s*(\w+)\s*\}\}")

# ---------------------------------------------------------------------------
# Shared HTML scaffold — same theme as build_adr_site.py / index.html
# ---------------------------------------------------------------------------

HEADER_HTML = """
  <header class="hero py-5">
    <div class="container py-3">
      <span class="badge text-bg-light text-dark mb-3">Formula 1 Data Project</span>
      <h1 class="display-5 fw-bold">Explore the data</h1>
      <p class="lead mb-0">
        Data quality review and the construction of the analytical schema.
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
  <title>Analysis &amp; Transformation - F1 Data Project</title>

  <link rel="icon" type="image/png" href="favicon.png">
  <link
    href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/css/bootstrap.min.css"
    rel="stylesheet"
    integrity="sha384-sRIl4kxILFvY47J16cr9ZwB07vP4J8+LH7qKQnuqkuIAvNWLzeN8tE5YBujZqJLB"
    crossorigin="anonymous">

  <style>
    body {
      background: #f4f6f9;
    }

    .hero {
      background: linear-gradient(135deg, #15151e, #e10600);
      color: white;
    }

    .resource-card {
      transition: transform 160ms ease, box-shadow 160ms ease;
    }

    .resource-card:hover {
      transform: translateY(-4px);
      box-shadow: 0 1rem 2rem rgba(0, 0, 0, 0.12);
    }
    article {
      margin: 0 auto;
      padding: 2rem;
      background: white;
      border-radius: 0.5rem;
      box-shadow: 0 0.5rem 1rem rgba(0, 0, 0, 0.08);
    }
    article img { display: block; max-width: 100%; height: auto; margin: 2rem auto;
              border-radius: 0.5rem;
              box-shadow: 0 0.5rem 1rem rgba(0, 0, 0, 0.12); }
    .table-responsive .table {
      width: auto;            /* shrink to fit content, don't stretch */
      max-width: 100%;        /* ...but never overflow the article */
      margin-left: auto;      /* centre within the article */
      margin-right: auto;
    }
    figcaption {
      text-align: center;
      color: #6c757d;
      font-size: 0.9rem;
      margin-top: 0.5rem;
    }
    figure { margin: 2rem 0; }

    #scrollToTop {
      position: fixed;
      bottom: 2rem;
      right: 2rem;
      z-index: 1030;
      display: none;                 /* hidden until the reader scrolls down */
      border-radius: 50%;
      width: 2.5rem;
      height: 2.5rem;
      padding: 0;
      align-items: center;
      justify-content: center;
      background: #6c757d;           /* Bootstrap "secondary", always opaque */
      color: #ffffff;                /* white chevron */
      border: none;
      box-shadow: 0 0.25rem 0.75rem rgba(0, 0, 0, 0.2);
      transition: background-color 160ms ease, transform 160ms ease;
    }

    #scrollToTop:hover {
      background: #495057;           /* darker grey on hover */
      color: #ffffff;
      transform: translateY(-2px);
    }
  </style>
</head>
<body>
{HEADER}
  <main class="container py-5">
<article>
<div class="breadcrumb-nav">
  <nav aria-label="breadcrumb">
    <ol class="breadcrumb">
      <li class="breadcrumb-item"><a href="index.html">Home</a></li>
      <li class="breadcrumb-item active">Analysis &amp; Transformation</li>
    </ol>
  </nav>
</div>
{content}
<div class="back-link">
  <a href="index.html" class="btn btn-outline-secondary">&larr; Back to home</a>
</div>
</article>
  </main>

<button id="scrollToTop" type="button"
        aria-label="Scroll to top" title="Back to top">
  <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14"
       fill="currentColor" viewBox="0 0 16 16" aria-hidden="true">
    <path fill-rule="evenodd"
          d="M7.646 4.646a.5.5 0 0 1 .708 0l6 6a.5.5 0 0 1-.708.708L8 5.707l-5.646 5.647a.5.5 0 0 1-.708-.708l6-6z"/>
  </svg>
</button>

  <footer class="text-center text-secondary small mt-5">
    Formula 1 Data Project · Updated automatically by the pipeline
  </footer>

  <script>
    (() => {
      const btn = document.getElementById('scrollToTop');
      const toggle = () => { btn.style.display = window.scrollY > 400 ? 'flex' : 'none'; };
      btn.addEventListener('click', () =>
        window.scrollTo({ top: 0, behavior: 'smooth' }));
      window.addEventListener('scroll', toggle, { passive: true });
      toggle();
    })();
  </script>
</body>
</html>
""".replace("{HEADER}", HEADER_HTML)

# ---------------------------------------------------------------------------
# Flattened race results (port of the R `results` chain, report section 2.4)
# ---------------------------------------------------------------------------
# The Jolpica export spreads a driver's race result across five tables
# (session_entry -> session / roundentry -> team_driver -> round / team /
# driver / season). This temp view flattens it, restricted to Grand Prix
# sessions ("R"), exactly like the R dplyr chain it replaces. The driver
# name is computed here so consuming queries can select rf.driver directly.

RESULTS_VIEW_SQL = """
CREATE TEMP VIEW results_flat AS
SELECT
  se.id,
  sn.year,
  rnd.name            AS circuit,
  TRIM(COALESCE(d.forename, '') || ' ' || COALESCE(d.surname, '')) AS driver,
  t.name              AS team,
  se.position,
  se.points,
  se.detail,
  se.laps_completed,
  se.fastest_lap_rank,
  se.is_classified,
  se.is_eligible_for_points
FROM session_entry se
JOIN session ses         ON ses.id = se.session_id
LEFT JOIN roundentry re  ON re.id = se.round_entry_id
LEFT JOIN team_driver td ON td.id = re.team_driver_id
LEFT JOIN team t         ON t.id = td.team_id
LEFT JOIN driver d       ON d.id = td.driver_id
LEFT JOIN round rnd      ON rnd.id = re.round_id
LEFT JOIN season sn      ON sn.id = rnd.season_id
WHERE ses.type = 'R'
"""

# ---------------------------------------------------------------------------
# Queries (one per placeholder) — (db_key, sql, kind)
# kind: "table" -> HTML table, "scalar" -> single value, "computed" -> built
# in build_context() from the inventory rather than a single SQL statement
# ---------------------------------------------------------------------------

def build_queries() -> dict:
    return {
        # -- Section: Pipeline ------------------------------------------------
        # ~X K rows inline (rounded to nearest 10K like the R helper)
        "total_rows_k": ("raw", None, "computed"),

        # 3-column grid of the 18 input CSV files (built from the inventory)
        "tbl_dataset_files": ("raw", None, "computed"),

        # -- Section: Quick analysis, a first look ---------------------------
        "tbl_season_head": (
            "raw", "SELECT * FROM season LIMIT 5", "table"),
        "tbl_pit_stop_head": (
            "raw", "SELECT * FROM pit_stop LIMIT 5", "table"),

        # -- Winner uniqueness ------------------------------------------------
        # Human-readable view: per Grand Prix, how many drivers are recorded
        # in position 1 (shared drives of the early years). Uses only
        # schema-confirmed columns: session.round_id -> round.name ->
        # round.season_id -> season.year.
        "tbl_multi_winner_races": (
            "raw", """
            SELECT
            se.session_id,
            COUNT(*) AS n_winners
            FROM session_entry AS se
            WHERE se.position = 1
            GROUP BY se.session_id
            HAVING COUNT(*) > 1
            ORDER BY se.session_id""", "table"),

        # Year + circuit view over the flattened results (R:
        # results %>% group_by(year, circuit) %>% filter(position == 1) ...)
        "tbl_multi_winner_details": (
            "raw", """
            SELECT year, circuit, COUNT(*) AS n_winners
            FROM results_flat
            WHERE position = 1
            GROUP BY year, circuit
            HAVING COUNT(*) > 1
            ORDER BY year, circuit""", "table"),

        # -- Fractional point values -------------------------------------------
        # All non-integer points grouped by fractional part. SQLite's %
        # operator casts its operands to INTEGER, so the fractional part is
        # computed explicitly as points - CAST(points AS INTEGER) — the port
        # of R's points %% 1. ROUND(x, 3) normalises the float noise of the
        # 1/7 shares, exactly like the R mutate(round(points %% 1, 3)).
        "tbl_fractional_points_survey": (
            "raw", """
            SELECT ROUND(points - CAST(points AS INTEGER), 3) AS fractional_part,
                   COUNT(*) AS n_rows
            FROM session_entry
            WHERE points IS NOT NULL
              AND points <> CAST(points AS INTEGER)
            GROUP BY fractional_part
            ORDER BY n_rows DESC""", "table"),

        # Neither integers nor exact halves -> only the 1954 British GP
        # (1/7 shares) and 1955 Argentine GP (4/3 shares) survive
        "tbl_fine_fraction_rows": (
            "raw", """
            SELECT rf.year, rf.circuit, rf.driver, rf.team,
                   rf.position, rf.points
            FROM results_flat rf
            WHERE (rf.points - CAST(rf.points AS INTEGER)) <> 0
              AND (rf.points - CAST(rf.points AS INTEGER)) <> 0.5
            ORDER BY rf.year, rf.circuit, rf.position""", "table"),

        # -- Shared fastest lap, 1954 British GP -------------------------------
        # Fractional part within +/-0.01 of 1/7 (~0.143); tolerance is robust
        # to float noise, and 1/6 (~0.167) / 1/8 (0.125) lie outside the band.
        # fastest_lap_rank is selected to show it is NULL for these rows.
        "tbl_fastest_lap_shared_rows": (
            "raw", """
            SELECT rf.year, rf.circuit, rf.driver, rf.team,
                   rf.position, rf.points, rf.fastest_lap_rank
            FROM results_flat rf
            WHERE ABS((rf.points - CAST(rf.points AS INTEGER)) - 1.0/7.0) < 0.01
            ORDER BY rf.circuit, rf.position""", "table"),

        # Fastest-lap coverage boundary (expected: 1958)
        "first_fastest_lap_season": (
            "raw",
            "SELECT MIN(year) FROM results_flat "
            "WHERE fastest_lap_rank IS NOT NULL", "scalar"),

        # -- Eligibility / points correspondence --------------------------------
        # Exactly ONE row expected (Fangio, Monaco 1956). The prose asserts
        # "exactly once", so anything other than a single row is a red flag.
        "tbl_ineligible_scorers": (
            "raw", """
            SELECT rf.year, rf.circuit, rf.driver, rf.team,
                   rf.position, rf.points, rf.detail, rf.laps_completed
            FROM results_flat rf
            WHERE rf.points IS NOT NULL
              AND rf.is_eligible_for_points = 'f'
              AND rf.points > 0
            ORDER BY rf.year, rf.circuit""", "table"),

        # Ferrari entries at the 1956 Monaco GP (context for the above)
        "tbl_ferrari_monaco_1956": (
            "raw", """
            SELECT rf.driver, rf.position, rf.points,
                   rf.is_eligible_for_points AS eligible,
                   rf.detail, rf.laps_completed
            FROM results_flat rf
            WHERE rf.year = 1956
              AND rf.team = 'Ferrari'
              AND rf.circuit = 'Monaco Grand Prix'
            ORDER BY rf.position""", "table"),

        # -- Classification / points correspondence -----------------------------
        # Fastest-lap bonus on retired cars; includes Moss, France 1959 (DQ).
        "tbl_unclassified_scorers": (
            "raw", """
            SELECT rf.year, rf.circuit, rf.driver, rf.team,
                   rf.position, rf.points, rf.detail,
                   rf.fastest_lap_rank
            FROM results_flat rf
            WHERE rf.points IS NOT NULL
              AND rf.is_classified = 'f'
              AND rf.points > 0
            ORDER BY rf.year, rf.circuit""", "table"),

        # -- Nationality ----------------------------------------------------------
        "tbl_team_nationality_head": (
            "raw", "SELECT name, nationality FROM team LIMIT 6", "table"),

        # -- Transformation chapter (analytics DB) --------------------------------
        "tbl_driver_nat_corr_head": (
            "ana", "SELECT * FROM driver_nationality_corrections LIMIT 6",
            "table"),
        "tbl_team_nat_corr_head": (
            "ana", "SELECT * FROM team_nationality_corrections LIMIT 6",
            "table"),
        "tbl_f1resultsummary_head": (
            "ana", """
            SELECT resultId, positionOrder, points, year, circuit,
                   driverName, driverAge, constructorName
            FROM f1_result_summary
            LIMIT 6""", "table"),
    }

# ---------------------------------------------------------------------------
# Rendering helpers
# ---------------------------------------------------------------------------

def df_to_html(df: pd.DataFrame) -> str:
    """Render a data frame as a Bootstrap table with a dark header row."""
    html = df.to_html(index=False, border=0, na_rep="",
                      classes="table table-sm table-striped table-bordered")
    html = html.replace("<thead>", '<thead class="table-dark">', 1)
    # pandas inlines text-align styles on numeric columns; drop them so the
    # stylesheet's left-alignment applies uniformly
    html = re.sub(r'\s*style="[^"]*"', "", html)
    return f'<div class="table-responsive">\n{html}</div>'

# Matches only the bare <table> elements emitted by python-markdown for
# tables authored directly in the markdown. Dynamic (SQL-derived) tables
# arrive as <table border="0" class="dataframe ..."> from pandas and are
# therefore never touched by this pattern — they are styled exactly once,
# inside df_to_html().
TABLE_RE = re.compile(r"<table>.*?</table>", re.DOTALL)

def decorate_static_tables(html: str) -> str:
    """
    Give the Markdown-authored tables the same Bootstrap treatment as the
    SQL-derived ones: dark header row, bordered, striped, tight, inside a
    responsive wrapper (which also applies the width:auto / centring rule).
    """
    def wrap(match: re.Match) -> str:
        inner = match.group(0)
        inner = inner.replace(
            "<table>",
            '<table class="table table-sm table-striped table-bordered">', 1)
        inner = inner.replace("<thead>", '<thead class="table-dark">')
        return f'<div class="table-responsive">\n{inner}</div>'

    return TABLE_RE.sub(wrap, html)

# Pairs an image paragraph with the italic caption paragraph that follows it
# (authored as *Caption text* in the markdown) into a proper <figure>.
#   <p><img ...></p><p><em>Caption</em></p>   (image line, blank line, caption line)
#   <p><img ...> <em>Caption</em></p>         (image and caption in one paragraph,
#                                              i.e. no blank line in the markdown)
FIGURE_RE = re.compile(
    r'<p>\s*(<img[^>]*>)\s*(?:</p>\s*<p>\s*)?<em>(.*?)</em>\s*</p>',
    re.DOTALL)

def promote_figures(html: str) -> str:
    def wrap(match: re.Match) -> str:
        img, caption = match.group(1), match.group(2)
        return f'<figure>{img}<figcaption>{caption}</figcaption></figure>'
    return FIGURE_RE.sub(wrap, html)

def list_tables(con: sqlite3.Connection) -> list[str]:
    """All user tables, skipping SQLite internals (mirrors the R filter)."""
    rows = con.execute(
        "SELECT name FROM sqlite_master "
        "WHERE type = 'table' AND name NOT LIKE 'sqlite_%' "
        "AND name NOT LIKE '\\_%' ESCAPE '\\' "
        "ORDER BY name").fetchall()
    return [r[0] for r in rows]

def build_dataset_files_grid(tables: list[str], n_col: int = 3) -> str:
    """
    Lay the export files out in an n-column grid, filling COLUMN by column
    (alphabetical order reads top-to-bottom, left-to-right), exactly like
    the R matrix(files, byrow = FALSE) construction.
    """
    files = [f"{t}.csv" for t in tables]
    n_row = math.ceil(len(files) / n_col)
    files += [""] * (n_row * n_col - len(files))

    grid = {}
    for col in range(n_col):
        grid[col] = files[col * n_row:(col + 1) * n_row]

    # Header: label the first column, leave the continuation columns unnamed
    col_names = ["Files"] + [""] * (n_col - 1)
    # Transpose the column lists into rows — building from a list of tuples
    # makes the `columns` argument positional (a dict + columns selects by
    # key, which mismatches and silently produces an empty frame)
    df = pd.DataFrame(list(zip(*grid.values())), columns=col_names)
    df = df.loc[(df != "").any(axis=1)]           # drop fully-empty padding rows
    return df_to_html(df)

# ---------------------------------------------------------------------------
# Main build
# ---------------------------------------------------------------------------

def build_context(raw_path: str, ana_path: str) -> dict:
    raw_con = sqlite3.connect(raw_path)
    raw_con.execute(RESULTS_VIEW_SQL)            # temp view on the raw DB

    ana_con = sqlite3.connect(ana_path) if Path(ana_path).exists() else None

    cons = {"raw": raw_con, "ana": ana_con}
    ctx: dict = {}

    # ---- computed values first (need the raw connection but not queries) ----
    tables = list_tables(raw_con)

    counts = {t: raw_con.execute(f'SELECT COUNT(*) FROM "{t}"').fetchone()[0]
              for t in tables}
    total_rows = sum(counts.values())
    # Round to the nearest 10,000 and express in thousands (e.g. 573,402 -> 570)
    ctx["total_rows_k"] = str(int(round(total_rows / 1000, -1)))

    ctx["tbl_dataset_files"] = build_dataset_files_grid(tables)

    # ---- everything driven by the query dictionary -------------------------
    for name, (db_key, sql, kind) in build_queries().items():
        if kind == "computed":
            continue                              # handled above

        con = cons[db_key]
        if con is None:
            raise RuntimeError(
                f"Query '{name}' needs the analytical DB, but {ana_path} "
                "was not found.")

        if kind == "scalar":
            value = con.execute(sql).fetchone()[0]
            if value is None:
                raise RuntimeError(
                    f"Scalar query '{name}' returned no value — the prose "
                    "relies on it.")
            ctx[name] = str(value)
        else:                                     # table
            ctx[name] = df_to_html(pd.read_sql(sql, con))

    raw_con.close()
    if ana_con is not None:
        ana_con.close()
    return ctx

def render(source_path: str, output_path: str, ctx: dict) -> None:
    md_text = Path(source_path).read_text(encoding="utf-8")

    # Substitute placeholders; unknown names must fail loudly — a literal
    # "{{ ... }}" leaking into the published page would go unnoticed.
    found = set()

    def substitute(match: re.Match) -> str:
        name = match.group(1)
        found.add(name)
        try:
            return ctx[name]
        except KeyError:
            raise RuntimeError(
                f"Report placeholder '{name}' has no query defined. Add it "
                "to build_queries() or fix the spelling in the markdown.") \
                from None

    md_text = PLACEHOLDER_RE.sub(substitute, md_text)

    unused = sorted(set(ctx) - found)
    if unused:
        print(f"WARNING: computed values never used in the markdown: "
              f"{', '.join(unused)}")

    body = markdown.markdown(
        md_text,
        extensions=["fenced_code", "tables", "toc", "attr_list"],
    )
    body = decorate_static_tables(body)
    body = promote_figures(body)

    html = BASE_TEMPLATE.replace("{content}", body)
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    Path(output_path).write_text(html, encoding="utf-8")
    print(f"Generated: {output_path}")

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", default=DEFAULT_SOURCE)
    parser.add_argument("--raw", default=DEFAULT_RAW_DB)
    parser.add_argument("--analytics", default=DEFAULT_ANALYTICS_DB)
    parser.add_argument("--output", default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    ctx = build_context(args.raw, args.analytics)
    render(args.source, args.output, ctx)

if __name__ == "__main__":
    main()
