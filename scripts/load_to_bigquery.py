from google.cloud import bigquery
import os

os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = os.path.expanduser(r"C:\Users\Adhish\.dbt\ecommerce-dbt-stack-0bfba696cca0.json")

client = bigquery.Client(project="ecommerce-dbt-stack")

tables = {
    "orders": r"C:\Users\Adhish\Downloads\olist_data\olist_orders_dataset.csv",
    "customers": r"C:\Users\Adhish\Downloads\olist_data\olist_customers_dataset.csv",
    "order_items": r"C:\Users\Adhish\Downloads\olist_data\olist_order_items_dataset.csv",
    "products": r"C:\Users\Adhish\Downloads\olist_data\olist_products_dataset.csv",
    "sellers": r"C:\Users\Adhish\Downloads\olist_data\olist_sellers_dataset.csv",
    "order_payments": r"C:\Users\Adhish\Downloads\olist_data\olist_order_payments_dataset.csv",
    "geolocation": r"C:\Users\Adhish\Downloads\olist_data\olist_geolocation_dataset.csv",
    "product_category_translation": r"C:\Users\Adhish\Downloads\olist_data\olist_product_category_name_translation.csv",
}

for table_name, filepath in tables.items():
    table_id = f"ecommerce-dbt-stack.raw_ecommerce.{table_name}"
    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.CSV,
        skip_leading_rows=1,
        autodetect=True,
        write_disposition="WRITE_TRUNCATE",
        max_bad_records=10,
        encoding="UTF-8",
    )
    with open(filepath, "rb") as f:
        job = client.load_table_from_file(f, table_id, job_config=job_config)
        job.result()
    print(f"✅ Loaded {table_name}")

print("🎉 All tables loaded!")

import pandas as pd
df = pd.read_csv(
    r"C:\Users\Adhish\Downloads\olist_data\olist_order_reviews_dataset.csv",
    encoding="latin-1"
)
df.to_gbq(
    "raw_ecommerce.order_reviews",
    project_id="ecommerce-dbt-stack",
    if_exists="replace"
)
print("✅ Loaded order_reviews")