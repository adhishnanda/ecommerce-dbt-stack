with orders as (
    select * from {{ ref('int_orders_with_delivery') }}
),

customers as (
    select
        customer_id,
        customer_unique_id
    from {{ ref('stg_customers') }}
),

dim_customers as (
    select
        customer_key,
        customer_unique_id
    from {{ ref('dim_customers') }}
),

order_items_agg as (
    select
        order_id,
        count(*)                        as item_count,
        count(distinct product_id)      as distinct_product_count,
        count(distinct seller_id)       as distinct_seller_count,
        round(sum(total_item_value), 2) as total_items_value,
        round(sum(freight_value), 2)    as total_freight_value
    from {{ ref('int_order_items_enriched') }}
    group by order_id
),

final as (
    select
        -- keys
        o.order_id,
        dc.customer_key,
        c.customer_unique_id,

        -- date dimensions
        date(o.order_purchased_at)                          as order_date,
        extract(year from o.order_purchased_at)             as order_year,
        extract(month from o.order_purchased_at)            as order_month,
        format_date('%Y-%m', date(o.order_purchased_at))    as order_year_month,

        -- order attributes
        o.order_status,

        -- timestamps
        o.order_purchased_at,
        o.order_approved_at,
        o.order_delivered_carrier_at,
        o.order_delivered_customer_at,
        o.order_estimated_delivery_at,

        -- payment
        o.total_payment_value,
        o.payment_types,
        o.payment_method_count,

        -- review
        o.avg_review_score,
        o.review_count,

        -- delivery performance
        o.days_to_ship,
        o.days_to_delivery,
        o.delivery_delay_days,
        o.delivered_on_time,

        -- item rollups
        oia.item_count,
        oia.distinct_product_count,
        oia.distinct_seller_count,
        oia.total_items_value,
        oia.total_freight_value

    from orders o
    left join customers c
        on o.customer_id = c.customer_id
    left join dim_customers dc
        on c.customer_unique_id = dc.customer_unique_id
    left join order_items_agg oia
        on o.order_id = oia.order_id
)

select * from final
