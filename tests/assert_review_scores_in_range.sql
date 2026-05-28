-- Fails if any order has an avg_review_score outside the valid 1–5 range.
-- Scores are collected on a 1–5 integer scale; an average outside this range
-- indicates either corrupt source data or an aggregation error upstream.
-- Orders with no review (avg_review_score IS NULL) are excluded intentionally.
select
    order_id,
    avg_review_score
from {{ ref('fct_orders') }}
where avg_review_score is not null
  and avg_review_score not between 1 and 5
