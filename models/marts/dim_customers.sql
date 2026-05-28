with customer_orders as (
    select * from {{ ref('int_customer_orders') }}
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['customer_unique_id']) }} as customer_key,

        customer_unique_id,
        total_orders,
        first_order_at,
        last_order_at,
        lifetime_value,
        avg_order_value,
        avg_satisfaction_score,
        acquisition_cohort,

        case
            when lifetime_value >= 1000 then 'High Value'
            when lifetime_value >= 300  then 'Mid Value'
            else                             'Low Value'
        end as value_segment,

        case
            when total_orders >= 3 then 'Repeat'
            when total_orders  = 2 then 'Returning'
            else                        'One-Time'
        end as loyalty_segment

    from customer_orders
)

select * from final
