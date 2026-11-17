<!-- Build inputs required (fail the build if any are missing):
     inline: total_rows_k (×2), first_fastest_lap_season
     tables: tbl_dataset_files, tbl_season_head, tbl_pit_stop_head,
             tbl_multi_winner_races, tbl_multi_winner_details,
             tbl_fractional_points_survey, tbl_fine_fraction_rows,
             tbl_fastest_lap_shared_rows, tbl_ineligible_scorers,
             tbl_ferrari_monaco_1956, tbl_unclassified_scorers,
             tbl_team_nationality_head, tbl_driver_nat_corr_head,
             tbl_team_nat_corr_head, tbl_f1summary_head -->

# Data quality review {#analysis}

## Source {#sec-source}

The data used throughout this study comes from **Jolpica F1**, an open-source
(Apache 2.0) Formula 1 API maintained by a group of volunteers. Jolpica was
created as the successor to the widely used Ergast API, which was deprecated at
the end of the 2024 season, and provides the same type of historical data
(drivers, teams, sessions, results, standings, lap times and pit stops)
through a redesigned database schema. According to its maintainers, this new
schema is intended to better accommodate changing rule sets, reduce duplicated
information and allow the storage of additional F1-related data.

As Jolpica is an independent open-source project, its internals — scraping
process, data validation and correction policies — are the responsibility of
its maintainers and are outside the scope of this work. We therefore treat
Jolpica as the *system of record* for historical Formula 1 data and restrict
ourselves to documenting how the data is ingested, transformed and audited on
our side. A full description of the tables can be found in the project's
[database documentation](dbt/index.html).

It should be noted that Jolpica publishes its database dump with a delay of
approximately two weeks: more recent data is only available through a paid
tier. Since this study analyses historical data up to the end of the previous
season — deliberately excluding the ongoing season — the free release is
entirely sufficient, and the delayed publication has no impact on the
completeness of the dataset used here.

## Pipeline {#sec-pipeline}

The ingestion, transformation and publication of the data is fully automated in
an ELT pipeline published [on GitHub](https://github.com/jmr-lab/f1-elt-pipeline),
orchestrated with **GitHub Actions** and scheduled to run **weekly** (with
manual triggering also possible). The pipeline extracts the raw data from
Jolpica and produces two outputs: a normalised SQLite database used for
validation and transformation, and a mirror of the raw tables in Databricks
used for interactive analysis.

The pipeline performs the following steps:

1. **Extract** — the full Jolpica database dump (18 CSV files, one per table,
   ~40 MB compressed) is downloaded from the Jolpica data endpoint. A
   freshness check skips the download if the data is less than 7 days old,
   and the original Ergast/Jolpica table schemas are preserved.
2. **Load** — the raw CSVs are normalised into a **star schema SQLite**
   database (`jolpica.db`), with foreign key validation guaranteeing
   referential integrity. This database (~{{ total_rows_k }}K rows covering
   every F1 race since 1950) acts as a portable, version-controlled snapshot
   of the raw data, fully independent from any cloud service.
3. **Transform** — running in parallel with the publication step, the
   transformation job reshapes the raw schema into an analytics schema
   (`formula1.db`), adds derived fields (driver age, cumulative points,
   country flags), and applies **dbt** models and tests on top.
4. **Publish to Databricks** — each raw SQLite table is exported to Parquet,
   staged in a Unity Catalog volume, and loaded into **Delta tables** in
   Databricks via `COPY INTO`, with automatic type widening and row-count
   verification against the source. This gives a queryable copy of the raw
   dataset for exploratory analysis without needing to download the SQLite
   file.

The two branches of the pipeline are intentionally decoupled: a Databricks
outage cannot block the local SQLite build and release.

![Pipeline architecture: Jolpica → SQLite → dbt / Databricks](img/pipeline.png)
*Pipeline architecture: Jolpica → SQLite → dbt / Databricks.*

Two design decisions are worth highlighting, as they affect the reproducibility
of the analysis:

* **Full reload instead of incremental processing.** With roughly
  {{ total_rows_k }}K rows, reloading the entire dataset at each run is cheap,
  and — more importantly — safe: F1 stewards occasionally issue
  disqualifications or points adjustments *after* races, so append-only logic
  would silently miss retroactive corrections. This is particularly relevant
  for the historical quirks discussed in the [quick analysis](#sec-quick-analysis).
* **Release strategy.** The database is distributed via GitHub Releases under
  a mutable `data-latest` tag, overwritten at each run. Versioned immutable
  releases (`data-YYYYMMDD`) are a planned improvement; for this study, the
  dataset snapshot used for the analysis is documented together with the
  results to ensure reproducibility.

The pipeline consumes a single input: the Jolpica database dump, delivered as
a ZIP archive of 18 CSV files, one per table. The table below lists these
input files as recorded in the database inventory; each file corresponds
one-to-one with a table described in [the tables section](#sec-tables).

{{ tbl_dataset_files }}

## Tables {#sec-tables}

### Overview {#sec-tables-overview}

The Jolpica export consists of **18 tables** covering seasons, rounds,
circuits, sessions, results, teams, championships, scoring systems, lap times,
pit stops and staging tables. Note that the schema intentionally differs from
Ergast's: Jolpica splits the old monolithic races/results concepts into
fine-grained round, session and session_entry tables, which allows a modern
race weekend (practice, qualifying, sprint, race) to be modelled explicitly.

### Core season & race structure {#sec-core-tables}

The three tables below form the backbone of the temporal dimension: they
identify each season, each Grand Prix, and each physical circuit.

| Table    | Purpose |
|----------|---------|
| `season`  | Master record of every F1 season (1950–present). Contains year, championship system reference, and Wikipedia link. Primary time dimension for all temporal queries. |
| `round`   | Individual Grands Prix within seasons. Links to season and circuit, includes race number, official name, date, and Wikipedia reference. Represents the traditional race event concept. |
| `circuit` | Physical racetracks. Stores track metadata including location data and Wikipedia URL. Rarely changes over time — a dimensional lookup table. |

### Session-level detail {#sec-session-tables}

Modern Formula 1 weekends comprise multiple timed sessions (practice,
qualifying, sprint, race). Jolpica models this explicitly with two tables:

| Table          | Purpose |
|----------------|---------|
| `session`       | Granular timing sessions (Race, Qualifying, Sprint, Practice). Modern F1 structure where a round may have multiple sessions. Includes scheduled laps, timezone, and cancellation flags. |
| `session_entry` | Driver results per session. Contains grid position, finishing position, points scored, laps completed, time/difference, status codes, and classification eligibility. Most frequently queried results table. |

### Driver & constructor records {#sec-driver-team-tables}

Drivers and constructors are tracked both as profiles and as historical
pairings, alongside the legacy entry mechanism used before session-level
granularity:

| Table         | Purpose |
|---------------|---------|
| `driver`      | Driver profiles: names, nationality, date of birth and country. Core dimension for any driver-level aggregation; driver age at race date is derived from it during transformation. |
| `team`        | All constructor entries in history. Note: constructors evolve or rebrand — this tracks distinct legal entities, not just Ferrari/Mercedes/Red Bull brand names. |
| `team_driver` | Historical pairings of which driver drove for which team. Junction table linking drivers and teams, with validity periods implied by related records. |
| `roundentry`  | Which team-driver combination entered which round (before session granularity). Contains car number assignment. Legacy linkage from older schema design. |

### Championship standings {#sec-standings-tables}

Both championships are tracked cumulatively after every round, enabling
trajectory analysis over the course of a season:

| Table                   | Purpose |
|-------------------------|---------|
| `driver_championship` | Cumulative driver standings across the season. Tracks points accumulation after each round — enabling analysis of championship trajectories, comebacks, and mathematical elimination dates. |
| `team_championship`   | Equivalent constructor standings. Mirrors the driver championship table structure but for teams. Critical for analysing constructor battles and historic dominance patterns. |

### Scoring systems {#sec-scoring-tables}

Point allocation has changed repeatedly across F1 history. Three tables
document the rules governing how results translate into points:

| Table                     | Purpose |
|---------------------------|---------|
| `points_system`           | Historical point-allocation rules. Each row defines a unique scoring scheme used during a period, explaining why different eras award points differently. |
| `championship_system`     | Broader championship format definitions. May encompass tiebreaker rules, sprint weekend variants, or multi-season aggregations. |
| `championship_adjustment` | Special corrections to historical standings. Likely captures retroactive disqualifications, title rescissions, or corrections to original records. |

### Performance metrics {#sec-performance-tables}

Two high-cardinality tables capture on-track performance:

| Table      | Purpose |
|------------|---------|
| `lap`      | Per-lap timing data. The highest-cardinality table, containing individual lap times for every driver in every race session. Essential for pace analysis, fastest-lap identification, and tyre-strategy modelling. |
| `pit_stop` | Pit-stop events, including duration and timing within a race, and potentially crew performance data. Critical for race-strategy analysis and comparing pit-crew performance. |

### Staging tables (not used in analysis) {#sec-staging-tables}

Two tables exist as empty staging structures with no analytical value:

| Table       | Purpose |
|-------------|---------|
| `base_team` | Empty staging table — likely intended for ETL operations or future use. Currently contains no data. |
| `penalty`   | Intended for driver or constructor penalties but currently empty. It may be populated by future pipeline updates or used only when infractions occur. |

## Quick analysis {#sec-quick-analysis}

### A first look at the raw tables {#sec-first-look}

Before describing the issues hidden in the data, it is worth looking at the
tables themselves. The extracts below show the first rows of two tables —
`season`, one of the smallest tables in the schema, and `pit_stop`, a fact
table — chosen so that all their columns fit on the page.

First, the `season` table — with only a handful of rows and columns, it
defines the championship calendar:

{{ tbl_season_head }}

The extract below shows the first rows of the `pit_stop` table:

{{ tbl_pit_stop_head }}

### The `api_id` column {#sec-api-id}

The two extracts above reveal a common pattern: every table begins with an
`api_id` column. This identifier is present in **all 18 tables** of the
export — inspecting the remaining tables (not reproduced here) shows exactly
the same structure. It mirrors the primary key exposed by the Jolpica API and
is therefore *application specific*: it identifies records within Jolpica's
own infrastructure (and its Ergast-compatible endpoints) rather than
describing anything about the racing data itself.

Since it carries no analytical meaning, duplicates the information already
present in the pipeline's own keys, and wastes width in every table, **these
columns will be dropped from all tables during the dbt transformation step**;
the details are covered in [the transformation chapter](#transformation).

Dropping the columns from the analytical tables does not mean discarding the
information permanently. Should the values ever prove useful again — for
example, for tracing records back to Jolpica's endpoints or for debugging the
extraction process — they could be preserved in dedicated, application-level
lookup tables, kept strictly separate from the F1 data tables described above.

### Winner uniqueness {#sec-multi-winners}

The most basic integrity expectation for a results table is that each race
has exactly one winner. This expectation is, however, merely an assumption
made by the analyst — the raw export is never accompanied by a formal
definition of what constitutes a unique race winner — and is therefore worth
verifying explicitly.

Working directly from the Jolpica `results` table, a simple count of drivers
classified in first position per race confirms two things. First, no race in
the dataset lacks a winner altogether; second, several races list **more than
one** driver in first position:

{{ tbl_multi_winner_races }}

To identify the affected races, the races listing more than one winner are
then joined with the `races` and `drivers` tables — the joins serve purely
to attach human-readable context, not to derive the counts:

{{ tbl_multi_winner_details }}

At first glance this looks like a data-quality defect, but it turns out to be
a historically faithful representation of the sport's earliest era, as
[the next section](#sec-shared-drives) explains.

### Shared drives in the early years {#sec-shared-drives}

The multiple-winner phenomenon observed above is not an error in the export
but a consequence of a practice that was accepted in Formula One's formative
years: **car sharing**. In the early seasons, teams frequently entered
smaller fields than the grid size, and a single car could be driven by
several drivers over the course of one race — one driver starting the race
and another taking over later, in the manner of an endurance relay.

Under the regulations of the time, all drivers who took the wheel were
credited with the race result achieved by that car. Consequently, when a
shared car finished first, the results table records several drivers sharing
the win — exactly the pattern surfaced by
[the winner-uniqueness check](#sec-multi-winners). The same convention
extends beyond victories: position assignments, classifications, and
championship points accrued by such cars were likewise divided among the
participating drivers.

From a data-modelling perspective, this means the natural key of the results
table is not (race, position) alone, since a single finishing position can
legitimately be occupied by multiple driver rows. Any transformation or
analysis step must therefore account for this historical peculiarity rather
than treating duplicate positions as anomalies to be corrected.

### Fractional point values {#sec-fractional-points}

The shared-drive practice of [the previous section](#sec-shared-drives)
leaves an arithmetic fingerprint in the `points` column — but it is not the
only source of non-integer point values. Up to this point the integrity
checks have concerned the *structural* attributes of the export — keys,
positions, flags; the `points` column itself has not been inspected yet, even
though it encodes the accumulated effect of every historical scoring quirk.
Championship points are expected to be whole numbers — or, at worst, halves —
so a natural first check is to ask which values violate this expectation.
The query below surveys every non-integer value appearing anywhere in the
results and counts how many rows carry each fractional part:

{{ tbl_fractional_points_survey }}

The distribution is remarkably clean: the overwhelming majority of
fractional rows carry an exact half, while only two much finer fractions
appear at all. Several distinct, well-documented mechanisms can produce
exact halves, and they are worth enumerating before attempting to attribute
individual rows:

* **Abandoned races.** When a Grand Prix was halted before the full distance
  had been covered — typically by torrential rain or a serious accident, with
  the race unable to resume — drivers received **half** of the points attached
  to their finishing position. A driver classified fourth in such a race, a
  placement worth 3 points under the scoring systems that governed the sport
  for its first four decades, was consequently credited with 1.5 points.
  Rain-shortened editions appear irregularly across the entire history of the
  championship.
* **Shared drives.** Whenever *two* drivers shared one car that finished in a
  points-paying position, the points attached to that place were divided
  equally between them ([shared drives](#sec-shared-drives)), and a division
  of an integer by two again yields exactly one half.
* **Shared fastest-lap points.** Under the early scoring systems, the bonus
  point attached to the fastest lap could be **split** when two drivers
  recorded an identical fastest time — each taking half of the single point.
  A driver who finished in a points-paying position and co-held the fastest
  lap thus carries a half appended to an otherwise integral total: second
  place under the 1950–1959 system (6 points) plus half the bonus yields 6.5.
  This is the two-driver case of
  [the seven-way split](#sec-fine-fractions).

Attributing each individual half to its mechanism is more delicate than it
may seem, and naive heuristics fail quickly: a points value is the *sum* of
position points and a possible bonus share, so either component may be the
halved one, and the mechanisms are not mutually exclusive — a shared car in a
rain-shortened race is divided twice over, yielding quarters. Rather than
attempting a per-row classification, the survey above is treated as evidence
that all fractional values fall within a known, historically grounded set of
mechanisms. What *cannot* be explained by any of them are the values that are
neither integers nor exact halves, visible at the tail of the extract;
isolating them pins down only two affected races, which
[the next section](#sec-fine-fractions) inspects individually.

### Finer fractions from shared awards {#sec-fine-fractions}

Values that are neither integers nor exact halves resist the explanation of
[the previous section](#sec-fractional-points) and require a closer look.
Isolating them from the unique point values of the `session_entry` table
yields only two contaminated races:

{{ tbl_fine_fraction_rows }}

Both races illustrate points being **divided rather than awarded**, each in
its own way. At the 1954 British Grand Prix, every affected driver carries an
identical increment of 1/7 point on top of the points earned by finishing
position — the fastest-lap bonus point of the era's scoring system, awarded
jointly to seven drivers who set an identical fastest lap and thus shared its
single point seven ways. At the 1955 Argentine Grand Prix, three drivers
sharing one car finished jointly in third position; the four points attached
to that place were divided equally, each driver recording 4/3 points. Both
mechanisms are consequences of the shared-car and shared-award practices of
the period described in [the shared-drive section](#sec-shared-drives),
confined to the 1950s — confirming that these fractions are faithful
historical records rather than pipeline errors.

### The absent fastest lap {#sec-absent-fastest-lap}

Among the shared awards of [the previous section](#sec-fine-fractions), one
subset deserves a final inspection: the drivers who received 1/7 of the
fastest-lap point at the 1954 British Grand Prix. Their fractional increment
of ~0.14 makes them easy to isolate, and their rows are informative —
although a fastest-lap award is recorded in the `points` column, the
dedicated `fastest_lap_rank` column remains empty for every one of them:

{{ tbl_fastest_lap_shared_rows }}

The seven `NA` values in the extract are not an accidental omission of these
particular rows, but a coverage boundary of the source: the dataset contains
fastest-lap records only starting from the 1958 season, earlier editions of
the championship having no officially tracked fastest lap. The boundary can
be located precisely in the data: fastest-lap coverage begins with the
**{{ first_fastest_lap_season }}** season.

The situation is therefore somewhat ironic: the very drivers who *jointly*
set the fastest lap in 1954 cannot be recognised as such from the
`fastest_lap_rank` column. Closing this gap is a candidate for the
transformation work described in [the transformation chapter](#transformation):
fastest-lap data for the earlier seasons could be integrated from an external
source as part of the planned modifications, restoring complete coverage of
this statistic across the championship's history.

### Ineligible drivers who scored points {#sec-ineligible-scorers}

The last integrity check concerns the consistency between the eligibility
flag and the `points` column. Every row of the results carries an
`is_eligible_for_points` indicator, and the naive expectation is a strict
correspondence: drivers flagged as ineligible should record zero points. The
export violates this expectation exactly once:

{{ tbl_ineligible_scorers }}

Consulting the historical record resolves the apparent contradiction, and it
involves the shared-drive practice of [the previous sections](#sec-shared-drives)
twice over. At the 1956 Monaco Grand Prix, Juan Manuel Fangio drove two cars:
he shared the car number 26, which finished second, with Peter Collins, and
the car number 20, which finished fourth, with Eugenio Castellotti. Under the
regulations of the time, the points of a shared car were divided among its
drivers — but a driver who had already received points from one car was
**not entitled to collect points from a second one**. Fangio therefore took
his half of the second-place points (three of six, shared with Collins),
while his would-be share of the fourth place — three points divided by two,
the 1.5 recorded in the extract — went uncollected.

The extract below places this single violating row in its full context by
listing every Ferrari entry of that race:

{{ tbl_ferrari_monaco_1956 }}

The table rewards a careful reading. The second row pair shows the shared
second place: Collins and Fangio both completed 100 laps in car number 26,
yet Fangio records one point more than his co-driver — the fastest-lap bonus
of the era's scoring system ([finer fractions](#sec-fine-fractions)), set by
Fangio that afternoon, appended to his half of the position points. The
fourth row pair shows the shared fourth place at one lap behind (`+1 Lap`,
99 laps completed): Castellotti's 1.5 was awarded, while the identical figure
next to Fangio's name — flagged ineligible, and singled out by the check at
the top of this section — records the *notional* share that the regulations
denied him. The two remaining rows complete the picture of the team's
afternoon: Castellotti's own car, sidelined by clutch failure after 14 laps
but still classified eleventh, and Musso's, eliminated in an accident after
two laps and classified fourteenth — a reminder that retirement and
classification are independent attributes in this export, exactly as the
classifications of [the next section](#sec-unclassified-scorers)
presuppose.

The row is thus internally coherent once both columns are read together: the
`points` column preserves the notional share attached to the fourth-place
finish, exactly as the sharing arithmetic would assign it, while the
`is_eligible_for_points` flag correctly records that this share was not
awarded. Far from being a data defect, the combination demonstrates that the
export encodes a subtle piece of period regulation — and, since it is unique
across the entire dataset, any transformation step can handle it as an
explicitly documented single case rather than a systematic issue.

### Unclassified drivers who scored points {#sec-unclassified-scorers}

The mirror image of the eligibility check of
[the previous section](#sec-ineligible-scorers) concerns the classification
flag. The naive expectation is again a strict correspondence: a driver
flagged as unclassified — one who did not complete a sufficient portion of
the race distance — should record zero points. The export contains a sizeable
group of violations of exactly this shape:

{{ tbl_unclassified_scorers }}

The pattern in the extract admits a single coherent explanation: the
**fastest-lap bonus point**. Every row in the table records exactly one
point — the value traditionally attached to the fastest lap — and every
`detail` describes a retirement: a mechanical failure, an accident, or, in
one case, a disqualification. A driver who sets the fastest lap and then
abandons the race cannot be classified, yet the bonus point earned before
the retirement remains attached to his name. The rows from 1958 onwards make
the mechanism directly visible, since they carry `fastest_lap_rank = 1` in
the column whose coverage gap was analysed in
[the absent fastest lap](#sec-absent-fastest-lap); the earlier rows show the
same one-point signature, but the rank column — not populated before 1958 —
cannot corroborate them.

The extract also contains a historical curiosity: at the 1959 French Grand
Prix, Stirling Moss was disqualified after setting the fastest lap of the
race. Stripped of his classification but not of his bonus point, he appears
in this table as the only disqualified driver of the period to score a
championship point — a memorable edge case that the export preserves
faithfully through the combination of `is_classified = f`, a positive point
value, and the `Disqualified` detail.

### Country or nationality {#sec-nationality}

The `team` table attaches a single `nationality` attribute to every
constructor. A first extract suffices to raise a question about how that
attribute is assigned:

{{ tbl_team_nationality_head }}

Alfa Romeo — one of the most famous Italian carmakers, and almost certainly
an Italian team in the championship's early years — appears here as Swiss.
The situation is in fact stricter than a mere ambiguity: Alfa Romeo is
recorded as Swiss **for all of its races**, including the very first seasons
of the championship, when the team was run as an Italian works outfit. The
dataset therefore does not merely store a single nationality per team — it
*retrojects the most recent one onto the entire history*. The schema cannot
express that the nationality attached to an entity changed over the decades
the data spans: whatever value the source associates with Alfa Romeo today
(likely reflecting later changes of ownership) silently overwrites the
Italian identity the team carried in 1950.

The same limitation, in an even more striking form, affects drivers. A
driver may hold and compete under different nationalities during his career,
but the export allows only one value per person. Bertrand Gachot is a
confirmed case: he entered Grands Prix under a Belgian flag as well as a
French flag, yet the `driver` table can record only one of them. The Renault
team may present a similar ambiguity, having arguably raced under both
French and British identities depending on the period considered.

For the analytical purposes of this work the impact is limited — nationality
is used mainly for descriptive statistics rather than as a join key — but
the limitation is now confirmed rather than suspected: any temporal analysis
of team or driver nationality built on this dataset would wrongly describe
the 1950 Alfa Romeo entries as Swiss achievements. This gap is addressed in
[the transformation chapter](#transformation), where a transformation
introduces **season-scoped nationality tables** for teams and drivers,
restoring the ability to represent a nationality as it was at the time of
each season rather than in its most recent state.

# The analytical schema {#transformation}

## Principles {#sec-principles}

The quality review of [the data-quality chapter](#analysis) leads to a
conclusion that shapes every decision described in this chapter: the Jolpica
export is not a dirty dataset in need of cleaning, but a faithful historical
record whose apparent anomalies — shared drives, divided points,
unclassified but scored drivers — reflect the regulations of the periods they
describe. Editing such values would not improve the data; it would destroy
it. The transformation work presented here is therefore governed by a
deliberately restrictive principle:

> **Jolpica data is preserved as-is. Structural changes (renaming, reshaping,
> removing redundant columns) are permitted freely; editorial changes to the
> values themselves are permitted only where the source is demonstrably wrong,
> and are always documented as explicit corrections.**

Three modifications satisfy this criterion and constitute the analytical
schema (`formula1.db`) built with **dbt** on top of the raw `jolpica.db`:

1. the removal of the application-specific `api_id` column from all tables
   ([removing the `api_id` columns](#sec-api-id-removal));
2. the introduction of **season-scoped nationality tables** for drivers and
   teams, correcting the retrojection problem identified in
   [the nationality section](#sec-nationality)
   ([season-scoped nationalities](#sec-nationality-corrections));
3. the restoration of fastest-lap coverage for the seasons 1950–1957 from an
   external source, closing the gap documented in
   [the absent fastest lap](#sec-absent-fastest-lap)
   ([restoring fastest-lap coverage](#sec-fastest-lap-enrichment)).

Everything else passes through unchanged. The historical quirks analysed in
the [quick analysis](#sec-quick-analysis) are carried into the analytical
schema deliberately, and [what is deliberately not changed](#sec-not-changed)
records this decision explicitly so that future readers do not mistake
preserved history for uncorrected defects.

## The dbt layer {#sec-dbt-layer}

The transformation is implemented with **dbt** and executed on the local
SQLite database (`jolpica.db`) produced by the pipeline's load step. Each raw
table is declared as a dbt source, and models are organised in the customary
staging → mart progression. The lineage of the current implementation is
shown below.

![Transformation lineage: Jolpica source tables (left) mapped through dbt to the analytical tables (right)](img/dbt-dag.png)
*Transformation lineage: Jolpica source tables (left) mapped through dbt to
the analytical tables (right). This figure is a snapshot; the full,
interactive and always up-to-date diagram is available in the project's
[online dbt documentation](dbt/index.html).*

Two observations about the shape of this graph summarise the philosophy of
[the principles section](#sec-principles). First, the large majority of
source tables map one-to-one to their analytical counterparts with no
intermediate logic: they are renamed, stripped of `api_id`, and passed
through. Second, the deviations from this pattern are few and concentrated —
the nationality corrections feed two dedicated tables, the external
fastest-lap source feeds the enriched results model, and a single derived
view exists at present. The transformation layer is intentionally thin, and
it is expected to grow slowly: as new analytical views are added, the online
documentation will diverge from the snapshot reproduced here, which is
precisely why the authoritative version is published alongside the
dbt-generated documentation rather than frozen in this document.

## Removing the `api_id` columns {#sec-api-id-removal}

As established in [the `api_id` analysis](#sec-api-id), every table of the
export begins with an `api_id` column that identifies records within
Jolpica's own infrastructure but carries no analytical meaning. All such
columns are dropped during the staging step. The removal is purely
structural — it affects no values, no joins and no row counts — and is
verified by the row-count checks described in
[the pipeline section](#sec-pipeline).

It should be stressed that this is a **deferral, not a rejection**, of the
underlying information. Should a need ever arise to trace analytical records
back to Jolpica's API endpoints — for example, for debugging the extraction
process or reconciling against future revisions of the dump — the original
identifiers can be recovered from the raw SQLite snapshot, which is itself
version-controlled and distributed with the pipeline. Introducing dedicated
application-level lookup tables now would add joins and maintenance surface
for a use case that does not currently exist; the decision is therefore
recorded here and revisited only if that use case materialises.

## Season-scoped nationalities {#sec-nationality-corrections}

[The nationality section](#sec-nationality) documented the central limitation
of the raw schema regarding nationality: a single, current-day value is
retrojected onto the entire history of each driver and team, so that the 1950
Alfa Romeo works outfit — unambiguously Italian at the time — is recorded as
Swiss, and drivers who competed under more than one nationality, such as
Bertrand Gachot, can exhibit only one of them.

Fixing this properly would mean recording the nationality of every entity in
every season. For roughly 800 drivers and several hundred constructor
entities spanning three quarters of a century, such a complete mapping cannot
be reliably constructed from public records, and fabricating coverage would
violate the principle of [the principles section](#sec-principles). The
transformation therefore takes a narrower and more honest form:

* the original `country_code` attributes on `driver` and `team` are retained
  unchanged and continue to serve as the **default** nationality;
* two dedicated correction tables, `driver_nationality_corrections` and
  `team_nationality_corrections`, associate a country with an entity **over
  an explicit season interval** (`season_id_start` to `season_id_end`),
  overlaying the default wherever a correction exists.

The resulting model restores temporal resolution exactly where it is needed:
a query about a driver's or team's nationality in a given season resolves
against the correction table first, and falls back to the source value
otherwise. Corrections are applied only to the cases documented in
[the nationality section](#sec-nationality) — Alfa Romeo's Italian identity
prior to its post-war reorganisation, Renault's dual French/British
identity, and drivers with confirmed multi-nationality careers such as
Gachot — each entry traceable to the historical evidence discussed in
[the data-quality chapter](#analysis).

The driver-level corrections are shown first, illustrating the
multi-nationality career case that the raw schema cannot express:

{{ tbl_driver_nat_corr_head }}

The team-level corrections follow, covering the two constructor cases —
Alfa Romeo's pre-reorganisation Italian identity and Renault's
French/British duality:

{{ tbl_team_nat_corr_head }}

The distinction from the raw schema is worth making explicit: where Jolpica
can only state what an entity's nationality *is*, the analytical schema can
state what it *was at the time of a given season*. Temporal analyses of
nationality built on `formula1.db` now describe the 1950 Alfa Romeo entries
as Italian, at the cost of a single join and a documented, extendable
correction mechanism.

## Restoring fastest-lap coverage, 1950–1957 {#sec-fastest-lap-enrichment}

[The absent fastest lap](#sec-absent-fastest-lap) located a precise coverage
boundary in the source: the `fastest_lap_rank` column is empty for every
session before the 1958 season, because officially tracked fastest laps were
not part of the championship's recordkeeping before then. The irony
highlighted there — that the seven drivers who jointly set the fastest lap at
the 1954 British Grand Prix carry their 1/7-point award in `points` but
cannot be recognised by the dedicated column — is preserved verbatim by the
pass-through philosophy of this chapter.

However, unlike the other quirks of the data-quality chapter, this gap is a
genuine *absence* of data rather than a period-accurate encoding, and the
missing information is recoverable: an external dataset records the
fastest-lap achievers for the seasons 1950–1957. As part of the imminent
modifications to the pipeline, this external table will be joined onto the
results model, populating `fastest_lap_rank` (and the related fastest-lap
attributes) for the affected seasons. The enrichment is applied exclusively
where the source is empty, so the original values from 1958 onwards remain
untouched and traceable to Jolpica; provenance of the enriched values is
recorded separately, in keeping with the audit practices of the pipeline.

For the shared-award cases of [finer fractions](#sec-fine-fractions), the
enrichment deliberately records the joint achievement as it stands in the
historical record rather than electing a single fastest driver — consistent
with the treatment of multi-winner races in
[shared drives](#sec-shared-drives).

<!-- TODO: once the enrichment lands, add a verification extract here, e.g.
     the 1954 British GP rows now showing fastest_lap_rank, mirroring the
     absent-fastest-lap section. -->

With this change, fastest-lap coverage becomes complete across the entire
championship history, and the "absent fastest lap" ceases to be a limitation
of the analytical dataset — while remaining faithfully absent from the raw
snapshot, which is never modified.

## A convenience view: `f1summary` {#sec-f1summary}

The analytical schema is normalised: answering even a simple question —
*who finished where, in which car, scoring how many points?* — requires
joining `session_entry`, `round`, `season`, `circuit`, `driver`, `team` and
the nationality resolution logic of
[season-scoped nationalities](#sec-nationality-corrections). Writing these
joins anew for every query or visualisation is error-prone and obscures the
analysis itself. To make day-to-day access to the dataset frictionless, the
transformation therefore includes **convenience views**: flat, de-normalised
tables that pre-resolve the most common joins and expose the data ready for
display.

The principal view is `f1summary`, one row per race result, whose columns
are listed below.

| Column                  | Description |
|-------------------------|-------------|
| `resultId`              | Unique identifier for each result |
| `grid`                  | The driver's starting grid position |
| `positionOrder`         | The driver's finishing position in order |
| `points`                | Points scored by the driver in the race |
| `laps`                  | Number of laps completed by the driver |
| `rank`                  | The rank of the driver's fastest lap |
| `statusId`              | Foreign key to status.csv |
| `year`                  | The year of the race |
| `round`                 | The round number of the race in the season |
| `circuit`               | The official name of the circuit |
| `driverNationality`     | The driver's nationality |
| `constructorName`       | The full name of the constructor |
| `constructorNationality`| The nationality of the constructor |
| `status`                | A description of the finishing status |
| `driverAge`             | The driver's age at the time of the race |
| `driverName`            | The driver's full name |

An extract of the view illustrates the outcome: each row combines result,
context and human-readable attributes into a single, display-ready record.

{{ tbl_f1summary_head }}

Two details of the view deserve emphasis. First, the nationality columns
(`driverNationality`, `constructorNationality`) are **not** a verbatim copy
of the source attributes: they are resolved through the season-scoped
correction mechanism of [season-scoped nationalities](#sec-nationality-corrections),
so the 1950 entries display Alfa Romeo as Italian rather than Swiss. This is
precisely the kind of logic that belongs inside a view rather than being
reimplemented (or forgotten) in every downstream query. Second, derived
attributes computed during transformation — `driverAge` among them — appear
alongside the raw passthrough columns, giving the view everything needed for
descriptive analysis without touching the normalised tables.

The view is intentionally materialised as a thin projection over the
analytical tables rather than a replacement for them: any measure beyond its
fixed column set (per-lap timings, pit stops, championship trajectories)
still queries the underlying schema directly. As the transformation layer
grows, additional views following the same pattern will be added; the online
[dbt documentation](dbt/index.html) remains the authoritative record of what
currently exists.

## The resulting schema {#sec-resulting-schema}

The outcome of the transformation is the analytical database `formula1.db`,
whose structure is shown below. The raw tables appear in the schema largely
unchanged, grouped by domain; the additions described in
[season-scoped nationalities](#sec-nationality-corrections) are visible as
the two `*_nationality_corrections` tables together with the `countries`
lookup, and the season-scoped `season_driver` and `season_team` associations.

![Entity-relationship diagram of the analytical database formula1.db after transformation](img/formula1_erd.png)
*Entity-relationship diagram of the analytical database `formula1.db`
after transformation.*

<!-- TODO: optionally add a summary table of the analytical schema
     (table, rows, delta vs. jolpica.db), reusing the inventory pattern of
     the data-quality chapter. -->

## What is deliberately not changed {#sec-not-changed}

Completeness requires stating the inverse of the preceding sections: the
anomalies of the data-quality chapter that survive the transformation **on
purpose**.

The multiple-winner races arising from
[shared drives](#sec-shared-drives) and the
[fractional points](#sec-fine-fractions) they produce are preserved as-is;
any "deduplication" would erase the only record that several drivers
jointly achieved a result. The driver whose eligibility flag contradicts a
positive point total ([ineligible drivers who scored
points](#sec-ineligible-scorers)) is likewise preserved — the combination
of `is_eligible_for_points` and the notional point share encodes a genuine
period regulation, and separating the two columns would lose it.
Unclassified drivers carrying a fastest-lap point
([unclassified drivers who scored points](#sec-unclassified-scorers)) are
retained, including the singular case of Stirling Moss at the 1959 French
Grand Prix. Finally, the legacy `roundentry` linkage and the empty staging
tables (`base_team`, `penalty`) are carried through unchanged: they cost
nothing, document the source's own evolution, and removing them would couple
the analytical schema to assumptions about Jolpica's future development.

Further integrity inconsistencies identified in the data-quality chapter
that do not admit a verified correction at present are explicitly deferred:
as with the application-level identifier lookup tables of
[removing the `api_id` columns](#sec-api-id-removal), the guiding rule is
that a documented limitation is preferable to a silent or speculative "fix".
The corrections mechanism of [season-scoped
nationalities](#sec-nationality-corrections) and the enrichment of
[restoring fastest-lap coverage](#sec-fastest-lap-enrichment) establish the
pattern by which such fixes will be introduced as evidence becomes
available — narrowly scoped, individually documented, and never at the
expense of the raw snapshot.
