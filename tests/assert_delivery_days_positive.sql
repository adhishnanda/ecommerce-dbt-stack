-- Fails if any order marked as delivered has a negative days_to_delivery.
-- A negative value would mean the order was recorded as delivered before
-- it was purchased, which is physically impossible and signals a timestamp error.
-- Non-delivered orders are excluded because days_to_delivery is null for them.
select
    order_id,
    order_purchased_at,
    order_delivered_customer_at,
    days_to_delivery
from {{ ref('fct_orders') }}
where order_status = 'delivered'
  and days_to_delivery < 0
