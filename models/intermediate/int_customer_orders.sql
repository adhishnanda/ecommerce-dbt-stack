with orders as (
    select * from {{ ref('int_orders_with_delivery') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

customer_orders as (
    select
        c.customer_unique_id,

        count(o.order_id)                                           as total_orders,
        min(o.order_purchased_at)                                   as first_order_at,
        max(o.order_purchased_at)                                   as last_order_at,

        round(sum(o.total_payment_value), 2)                        as lifetime_value,
        round(avg(o.total_payment_value), 2)                        as avg_order_value,
        round(avg(o.avg_review_score), 2)                           as avg_satisfaction_score,

        -- e.g. "2017-Q3" — quarter in which the customer placed their first order
        format_date('%Y-Q%Q', date(min(o.order_purchased_at)))      as acquisition_cohort

    from orders o
    inner join customers c on o.customer_id = c.customer_id
    group by c.customer_unique_id
)

select * from customer_orders
