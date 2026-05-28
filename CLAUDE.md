# Project Context

## Stack
- **dbt Core** 1.11 with **dbt-bigquery** adapter 1.11.1
- **BigQuery** project: `ecommerce-dbt-stack`, location: `europe-west10`
- **Python** 3.11, virtual environment already activated
- **Package:** `dbt-labs/dbt_utils` >=1.0.0, <2.0.0

## dbt Project
- Project name: `ecommerce_dbt`
- Profile: `ecommerce_dbt` (credentials at `~/.dbt/ecommerce-dbt-stack-0bfba696cca0.json`)

## BigQuery Datasets
| Dataset | Purpose |
|---|---|
| `raw_ecommerce` | Source tables loaded from Olist CSV files |
| `staging` | `stg_*` models — rename and cast only |
| `intermediate` | `int_*` models — joins and business logic |
| `marts` | `dim_*` and `fct_*` models — star schema for BI |

## Data Model (Star Schema)
```
fct_orders ──── dim_customers  (join on customer_key)
           ──── dim_products   (no direct FK; join via order items)
```

## Source Data
Olist Brazilian E-Commerce dataset, 9 raw tables:
`orders`, `customers`, `order_items`, `products`, `sellers`,
`order_payments`, `order_reviews`, `geolocation`, `product_category_translation`

## Critical Gotchas
- **Two customer IDs:** `customer_id` is order-scoped (changes per order);
  `customer_unique_id` is the stable shopper identifier. Always use
  `customer_unique_id` for customer-level metrics.
- **product_category_translation** raw columns are named `string_field_0`
  (Portuguese name) and `string_field_1` (English name). BigQuery autodetect
  skipped the CSV header row — do not rename these in the raw source.
- **review_id is not unique** in the raw source (~789 duplicates). No `unique`
  test exists on this column. Handle in intermediate models if exact counts matter.
- **dbt 1.9+ test syntax:** all generic test arguments must be nested under
  an `arguments:` property, e.g. `accepted_values: arguments: values: [...]`.
- **accepted_values on INT64 columns** requires `quote: false` in arguments
  to prevent dbt from wrapping integer values in single quotes.

## Common Commands
```bash
dbt run                          # build all models
dbt test                         # run all tests
dbt run --select staging         # build only staging layer
dbt test --select marts          # test only mart models
dbt build --select +fct_orders   # build fct_orders and all its upstream deps
```
