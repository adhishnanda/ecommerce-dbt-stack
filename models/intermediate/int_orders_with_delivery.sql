with orders as (
    select * from {{ ref('stg_orders') }}
),

payments_agg as (
    select
        order_id,
        sum(payment_value)                                       as total_payment_value,
        string_agg(distinct payment_type order by payment_type) as payment_types,
        count(*)                                                 as payment_method_count
    from {{ ref('stg_order_payments') }}
    group by order_id
),

-- review_id has duplicates in the raw source; averaging across all rows per order
-- is still meaningful since duplicate rows carry the same score
reviews_agg as (
    select
        order_id,
        round(avg(review_score), 2)    as avg_review_score,
        count(*)                       as review_count
    from {{ ref('stg_order_reviews') }}
    group by order_id
),

joined as (
    select
        o.order_id,
        o.customer_id,
        o.order_status,
        o.order_purchased_at,
        o.order_approved_at,
        o.order_delivered_carrier_at,
        o.order_delivered_customer_at,
        o.order_estimated_delivery_at,

        p.total_payment_value,
        p.payment_types,
        p.payment_method_count,

        r.avg_review_score,
        r.review_count,

        timestamp_diff(
            o.order_delivered_carrier_at, o.order_purchased_at, day
        )                              as days_to_ship,

        timestamp_diff(
            o.order_delivered_customer_at, o.order_purchased_at, day
        )                              as days_to_delivery,

        -- positive = late, negative = early, null = not yet delivered
        timestamp_diff(
            o.order_delivered_customer_at, o.order_estimated_delivery_at, day
        )                              as delivery_delay_days,

        case
            when o.order_delivered_customer_at is null          then null
            when o.order_delivered_customer_at
                 <= o.order_estimated_delivery_at               then true
            else false
        end                            as delivered_on_time

    from orders o
    left join payments_agg p    on o.order_id = p.order_id
    left join reviews_agg r     on o.order_id = r.order_id
)

select * from joined
