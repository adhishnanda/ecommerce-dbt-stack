"""
Generates docs/architecture.png — the pipeline diagram for the README.
Run from the project root: python docs/generate_architecture.py
Requires: pip install graphviz  (Python package)
          graphviz system binary (https://graphviz.org/download/)
"""

import os
from graphviz import Digraph

OUTPUT_PATH = os.path.join(os.path.dirname(__file__), "architecture")


def build_diagram() -> Digraph:
    dot = Digraph(comment="Olist E-Commerce Analytics Stack", format="png")

    # ── global graph attributes ───────────────────────────────────────────────
    dot.attr(
        rankdir="TB",
        size="14,10",
        dpi="150",
        fontname="Arial",
        bgcolor="white",
        pad="0.6",
        nodesep="0.7",
        ranksep="0.9",
    )

    # ── default node style ────────────────────────────────────────────────────
    dot.attr(
        "node",
        shape="box",
        style="rounded,filled",
        fontname="Arial",
        fontsize="11",
        margin="0.3,0.18",
        width="4.2",
        penwidth="1.5",
    )

    # ── default edge style ────────────────────────────────────────────────────
    dot.attr(
        "edge",
        fontname="Arial",
        fontsize="10",
        arrowsize="0.9",
        color="#546E7A",
        fontcolor="#37474F",
    )

    # ── title (plain text, no box) ────────────────────────────────────────────
    dot.node(
        "title",
        "Olist E-Commerce Analytics Stack",
        shape="none",
        style="",
        fontsize="20",
        fontname="Arial",
        fontcolor="#1A237E",
        width="0",
        margin="0",
    )

    # ── SOURCE layer (light yellow) ───────────────────────────────────────────
    dot.node(
        "source",
        "Kaggle Olist Dataset\n9 CSV files · 100k+ orders",
        fillcolor="#FFFDE7",
        color="#F9A825",
    )

    # ── INGESTION layer (light orange) ────────────────────────────────────────
    dot.node(
        "ingestion",
        "Python Ingestion Script\ngoogle-cloud-bigquery",
        fillcolor="#FFF3E0",
        color="#EF6C00",
    )

    # ── RAW layer (light grey) ────────────────────────────────────────────────
    dot.node(
        "raw",
        "BigQuery: raw_ecommerce\n9 source tables · autodetected schema",
        fillcolor="#F5F5F5",
        color="#9E9E9E",
    )

    # ── STAGING layer (light blue) ────────────────────────────────────────────
    dot.node(
        "staging",
        "dbt Staging Layer\n7 views · stg_orders, stg_customers,\n"
        "stg_products, stg_order_items,\n"
        "stg_sellers, stg_order_reviews,\nstg_order_payments",
        fillcolor="#E3F2FD",
        color="#1565C0",
    )

    # ── CI/CD side node (light green, dashed border) ──────────────────────────
    dot.node(
        "cicd",
        "GitHub Actions CI\ndbt test on every PR",
        fillcolor="#E8F5E9",
        color="#2E7D32",
        style="rounded,filled,dashed",
        width="2.8",
    )

    # ── INTERMEDIATE layer (medium blue) ─────────────────────────────────────
    dot.node(
        "intermediate",
        "dbt Intermediate Layer\n3 views · int_orders_with_delivery,\n"
        "int_order_items_enriched, int_customer_orders",
        fillcolor="#BBDEFB",
        color="#0D47A1",
    )

    # ── MARTS cluster (dark blue nodes, side by side) ─────────────────────────
    with dot.subgraph(name="cluster_marts") as c:
        c.attr(
            label="dbt Marts  ·  Star Schema",
            style="rounded,filled",
            fillcolor="#E8EAF6",
            color="#283593",
            fontname="Arial",
            fontsize="13",
            penwidth="2",
            margin="22",
        )
        c.attr(
            "node",
            shape="box",
            style="rounded,filled",
            fillcolor="#283593",
            fontcolor="white",
            color="#1A237E",
            fontname="Arial",
            fontsize="11",
            penwidth="1",
            width="2.6",
        )
        c.node("fct_orders", "fct_orders\n(fact table)")
        c.node("dim_customers", "dim_customers\n(dimension)")
        c.node("dim_products", "dim_products\n(dimension)")
        # force side-by-side layout
        with c.subgraph() as same:
            same.attr(rank="same")
            same.node("fct_orders")
            same.node("dim_customers")
            same.node("dim_products")

    # ── DASHBOARD (light purple) ──────────────────────────────────────────────
    dot.node(
        "dashboard",
        "Looker Studio Dashboard\nRevenue · Delivery · Categories · Geo",
        fillcolor="#F3E5F5",
        color="#7B1FA2",
    )

    # ── rank constraints ──────────────────────────────────────────────────────
    # Title sits above everything
    with dot.subgraph() as s:
        s.attr(rank="source")
        s.node("title")

    # CI/CD floats beside the staging node
    with dot.subgraph() as s:
        s.attr(rank="same")
        s.node("staging")
        s.node("cicd")

    # ── main flow edges ───────────────────────────────────────────────────────
    dot.edge("title", "source", style="invis")
    dot.edge("source", "ingestion", label="  download  ")
    dot.edge("ingestion", "raw", label="  load via Python  ")
    dot.edge("raw", "staging", label="  dbt staging  ")
    dot.edge("staging", "intermediate", label="  dbt intermediate  ")

    dot.edge("intermediate", "fct_orders", label="  dbt marts  ")
    dot.edge("intermediate", "dim_customers")
    dot.edge("intermediate", "dim_products")

    dot.edge("fct_orders", "dashboard", label="  connects to  ")
    dot.edge("dim_customers", "dashboard")
    dot.edge("dim_products", "dashboard")

    # ── CI/CD dashed side edge ────────────────────────────────────────────────
    dot.edge(
        "cicd",
        "staging",
        label="  validates  ",
        style="dashed",
        color="#2E7D32",
        fontcolor="#2E7D32",
        constraint="false",
        arrowhead="open",
    )

    return dot


if __name__ == "__main__":
    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    diagram = build_diagram()
    diagram.render(OUTPUT_PATH, cleanup=True)
    print(f"Done. Saved to {OUTPUT_PATH}.png")
