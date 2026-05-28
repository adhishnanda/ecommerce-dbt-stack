with products as (
    select * from {{ ref('stg_products') }}
),

-- reuse the same source alias pattern as int_order_items_enriched
category_translations as (
    select
        string_field_0 as product_category_name,
        string_field_1 as product_category_name_english
    from {{ source('raw_ecommerce', 'product_category_translation') }}
),

order_items_agg as (
    select
        product_id,
        count(*)       as times_ordered,
        round(avg(price), 2) as avg_selling_price
    from {{ ref('stg_order_items') }}
    group by product_id
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['p.product_id']) }} as product_key,

        p.product_id,
        p.product_category_name,
        ct.product_category_name_english,
        p.product_name_length,
        p.product_description_length,
        p.product_photos_qty,
        p.product_weight_g,
        p.product_length_cm,
        p.product_height_cm,
        p.product_width_cm,

        coalesce(oia.times_ordered, 0)  as times_ordered,
        oia.avg_selling_price

    from products p
    left join category_translations ct
        on p.product_category_name = ct.product_category_name
    left join order_items_agg oia
        on p.product_id = oia.product_id
)

select * from final
