# Design Decisions

---

### 1. Why the Olist dataset

**Decision:** Use the Olist Brazilian E-Commerce public dataset from Kaggle.
**Why:** It is a real, relational dataset with 9 linked tables and 100k+ orders — large enough to surface genuine performance and modelling concerns, not a toy example. It is free, well-documented, and reflects realistic data quality issues (duplicate review IDs, null delivery timestamps, encoding quirks).
**Alternative considered:** Synthetic datasets (e.g. Jaffle Shop), TPC-H benchmarks.
**Tradeoff:** The dataset is static (cut off mid-2018), so there is no incremental load to demonstrate. All models run as full refreshes.

---

### 2. Why BigQuery free tier

**Decision:** Use BigQuery on the Google Cloud free tier with the `europe-west10` (Berlin) region.
**Why:** The free tier is production-identical to paid BigQuery — same SQL dialect, same query engine, same IAM model. It handles 100k-row tables without hitting any limits. `europe-west10` satisfies GDPR data residency requirements for EU-based organisations.
**Alternative considered:** DuckDB (local), Snowflake trial, PostgreSQL.
**Tradeoff:** Requires a Google Cloud project and service account setup. DuckDB would have been zero-config but is not a cloud warehouse, which limits the portfolio signal.

---

### 3. Why dbt Core over dbt Cloud

**Decision:** Use dbt Core (open source CLI) instead of dbt Cloud.
**Why:** dbt Core is free, runs locally and in CI, and covers all features used in this project. Deploying through GitHub Actions demonstrates CI/CD skills directly, which is more relevant to most Analytics Engineer roles than clicking through a managed UI.
**Alternative considered:** dbt Cloud Developer tier (free for one developer).
**Tradeoff:** No hosted lineage UI or scheduler out of the box. `dbt docs serve` covers lineage locally; scheduling is out of scope for this project.

---

### 4. Why a 3-layer architecture (staging / intermediate / marts)

**Decision:** Transform data through three discrete layers: staging → intermediate → marts.
**Why:** Each layer has a single responsibility. Staging cleans and renames; intermediate encodes business logic and joins; marts expose final models to BI tools. Logic defined once in intermediate (e.g. delivery delay, payment aggregation) is reused by multiple mart models without copy-paste.
**Alternative considered:** Staging directly to marts (two layers).
**Tradeoff:** More files and models to maintain. Justified here because delivery delay and customer lifetime metrics are each referenced by more than one downstream model.

---

### 5. Why Kimball star schema over a One Big Table

**Decision:** Materialise marts as a fact table (`fct_orders`) and two dimension tables (`dim_customers`, `dim_products`) rather than a single wide table.
**Why:** A star schema lets BigQuery prune irrelevant columns at query time and allows BI tools to join only the dimensions needed for a given chart. It also maps naturally to how business questions are phrased: revenue by customer segment is a join of `fct_orders` and `dim_customers`, not a scan of 50+ columns.
**Alternative considered:** One Big Table joining all dimensions upfront.
**Tradeoff:** Looker Studio must join tables rather than querying a single source. On 100k rows this is negligible; on billions of rows the star schema pays back significantly.

---

### 6. Why views for staging/intermediate and tables for marts

**Decision:** Staging and intermediate models are materialised as views; mart models are materialised as BigQuery tables.
**Why:** Staging and intermediate are lightweight transformations over already-stored source data — materialising them as views costs nothing and keeps data always fresh. Marts are the direct query target for Looker Studio, which runs aggregations over the full dataset on every dashboard load. A physical table eliminates repeated view chaining and keeps load times fast.
**Alternative considered:** Tables everywhere (higher cost); views everywhere (slow dashboards).
**Tradeoff:** Mart tables require an explicit `dbt run` to refresh after source data changes. Acceptable because the Olist dataset is static.

---

### 7. Why surrogate keys in dimension tables

**Decision:** Use `dbt_utils.generate_surrogate_key` to create `customer_key` and `product_key` in the dimension tables rather than using the natural source IDs directly.
**Why:** Surrogate keys decouple the fact table join from source system identifiers. If Olist ever changed their ID scheme, only the dimension model would need updating. They also handle the case where `customer_unique_id` could theoretically appear in multiple source systems.
**Alternative considered:** Use `customer_unique_id` and `product_id` directly as primary keys in the dimension tables.
**Tradeoff:** An extra hashing step at build time and a slightly less readable key column. The tradeoff is worth it for join stability.

---

### 8. Why latin-1 encoding for order_reviews

**Decision:** Read the `olist_order_reviews_dataset.csv` file with `encoding='latin-1'` in the ingestion script.
**Why:** The raw file contains Portuguese text with accented characters (e.g. "ótimo", "não") encoded in latin-1. Python's default UTF-8 reader raises a `UnicodeDecodeError` on these bytes. Latin-1 (ISO-8859-1) is the correct encoding for this file.
**Alternative considered:** `encoding='utf-8-sig'`, stripping non-ASCII characters.
**Tradeoff:** None — latin-1 is the correct encoding. Stripping characters would silently corrupt the review text.

---

### 9. Why `customer_unique_id` over `customer_id`

**Decision:** Use `customer_unique_id` as the stable shopper identifier throughout all intermediate and mart models.
**Why:** Olist assigns a new `customer_id` for every order placed. A single shopper who places three orders will have three different `customer_id` values. `customer_unique_id` is the consistent identifier across orders and is the correct grain for customer-level metrics like lifetime value and loyalty segment.
**Alternative considered:** Using `customer_id` as the customer key.
**Tradeoff:** Requires an extra join through `stg_customers` in `fct_orders` to resolve `customer_unique_id` → `customer_key`. The join is small and the correctness gain is essential.

---

### 10. Why staging-only tests in CI

**Decision:** The GitHub Actions workflow runs `dbt test --select staging` rather than `dbt test` (all layers).
**Why:** Staging tests cover all 9 source tables with `not_null`, `unique`, and `accepted_values` checks — catching bad source data before it propagates. Running the full test suite in CI would require building all 13 models, which adds cost (BigQuery write operations) and time (2–3 minutes vs under 60 seconds).
**Alternative considered:** Full `dbt build` in CI; no CI tests at all.
**Tradeoff:** Intermediate and mart tests are not validated on every PR. Mitigated by running `dbt test` locally before every merge.

---

### 11. Why `delivered_on_time` as a boolean

**Decision:** Add a `delivered_on_time` boolean column to `fct_orders` rather than requiring BI tools to compute it from `delivery_delay_days`.
**Why:** Looker Studio cannot define calculated boolean fields as easily as filtering on a pre-computed column. A boolean enables one-click SLA reporting (filter `delivered_on_time = TRUE`) without any expression logic in the dashboard layer.
**Alternative considered:** Expose only `delivery_delay_days` and let the BI layer derive on-time status.
**Tradeoff:** Minor denormalisation. The column is derived from `delivery_delay_days` which is also present, so the logic is transparent and auditable.

---

### 12. Why `APPROX_TOP_COUNT` for `primary_category`

**Decision:** Use BigQuery's `APPROX_TOP_COUNT(product_category_name_english, 1)[SAFE_OFFSET(0)].value` to find the most frequent category per order.
**Why:** BigQuery has no native `MODE()` aggregate function. `APPROX_TOP_COUNT` is the idiomatic BigQuery solution — it is designed for this use case, runs efficiently on large datasets, and returns a typed result without a subquery.
**Alternative considered:** `ARRAY_AGG ... ORDER BY COUNT(*) DESC LIMIT 1` in a subquery; a window function with `ROW_NUMBER()`.
**Tradeoff:** `APPROX_TOP_COUNT` is approximate (hence the name), but the approximation error is negligible on order-level category counts of 1–5 items.

---

### 13. Why Python 3.11 virtual environment

**Decision:** Pin the project to Python 3.11 and document it as a prerequisite.
**Why:** `dbt-bigquery==1.11.1` is not compatible with Python 3.13 or 3.14 due to dependency conflicts in `protobuf` and `grpcio`. Python 3.11 is the latest version with full, tested compatibility across the dbt-bigquery dependency tree.
**Alternative considered:** Python 3.12 (works), Python 3.13/3.14 (breaks at install time).
**Tradeoff:** Users on newer Python versions must install 3.11 separately or use a version manager like `pyenv`. The CI pipeline pins `python-version: "3.11"` explicitly to guarantee reproducibility.
