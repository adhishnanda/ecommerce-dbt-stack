-- Fails if any delivered or shipped order has a negative total payment value.
-- total_payment_value maps to what is conceptually "gross order value" —
-- the sum of all payment entries for the order. Negative values indicate
-- a data corruption issue upstream in the payments pipeline.
select
    order_id,
    total_payment_value
from {{ ref('fct_orders') }}
where total_payment_value < 0
