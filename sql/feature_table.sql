-- modelling table: one row per delivered order, observed at carrier handover
create or replace table feature_table as
select o.order_id,
       o.handover_ts,

       -- seller dispatch timing, capped at 30 days either way
       greatest(least(date_diff('hour', o.shipping_limit_date, o.handover_ts) / 24.0, 30), -30) as dispatch_days_late,
       (o.handover_ts > o.shipping_limit_date)::int as dispatch_late,
       date_diff('hour', o.purchase_ts, o.handover_ts) / 24.0 as days_to_handover,

       -- delivery promise
       date_diff('day', o.purchase_ts, o.promised_ts) as promised_days,
       date_diff('hour', o.handover_ts, o.promised_ts) / 24.0 as days_left_to_promise,

       -- order basket
       o.n_items,
       o.n_sellers,
       o.total_price,
       o.total_freight / nullif(o.total_price, 0) as freight_ratio,

       -- geography
       (o.customer_state = s.seller_state)::int as same_state,
       o.customer_state,

       -- product
       coalesce(t.product_category_name_english, p.product_category_name, 'unknown') as category,
       (p.product_category_name is null)::int as missing_listing,
       coalesce(p.product_photos_qty, 0) as photos,

       -- seller track record, smoothed towards the training-period average with a weight of 10 orders
       coalesce(h.seller_past_orders, 0) as seller_past_orders,
       (coalesce(h.seller_past_late, 0) + 0.09 * 10) / (coalesce(h.seller_past_orders, 0) + 10) as seller_past_late_rate,
       (coalesce(h.seller_past_bad, 0) + 0.14 * 10) / (coalesce(h.seller_past_reviews, 0) + 10) as seller_past_bad_rate,

       -- target
       (o.review_score <= 2)::int as bad_review
from clean_orders o
join olist_sellers_dataset s on o.seller_id = s.seller_id
left join olist_products_dataset p on o.product_id = p.product_id
left join product_category_name_translation t on p.product_category_name = t.product_category_name
left join seller_history h on o.order_id = h.order_id
where o.handover_ts >= timestamp '2017-01-01'
  and o.handover_ts < timestamp '2018-09-01';