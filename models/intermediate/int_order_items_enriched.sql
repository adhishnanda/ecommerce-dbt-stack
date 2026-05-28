with order_items as (
    select * from {{ ref('stg_order_items') }}
),

products as (
    select * from {{ ref('stg_products') }}
),

sellers as (
    select * from {{ ref('stg_sellers') }}
),

-- raw source used directly: autodetect skipped the CSV header, so columns are
-- string_field_0 (product_category_name) and string_field_1 (product_category_name_english)
category_translations as (
    select
        string_field_0 as product_category_name,
        string_field_1 as product_category_name_english
    from {{ source('raw_ecommerce', 'product_category_translation') }}
),

joined as (
    select
        oi.order_id,
        oi.order_item_id,
        oi.product_id,
        oi.seller_id,
        oi.shipping_limit_at,
        oi.price,
        oi.freight_value,
        oi.price + oi.freight_value    as total_item_value,

        p.product_category_name,
        ct.product_category_name_english,
        p.product_weight_g             as weight_grams,

        s.seller_city,
        s.seller_state
    from order_items oi
    left join products p
        on oi.product_id = p.product_id
    left join category_translations ct
        on p.product_category_name = ct.product_category_name
    left join sellers s
        on oi.seller_id = s.seller_id
)

select * from joined
