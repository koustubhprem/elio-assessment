-- seller track record known at each order's handover:
-- late rate from earlier orders already delivered, bad review rate from reviews already submitted
create or replace table seller_history as
with pairs as (
    select cur.order_id,
           prev.delivered_ts <= cur.handover_ts as delivery_known,
           prev.delivered_ts > prev.promised_ts as prev_late,
           prev.review_answer_timestamp <= cur.handover_ts as review_known,
           prev.review_score <= 2 as prev_bad
    from clean_orders cur
    join clean_orders prev
      on prev.seller_id = cur.seller_id
     and prev.order_id <> cur.order_id
     and prev.handover_ts < cur.handover_ts
)
select order_id,
       count(*) filter (where delivery_known) as seller_past_orders,
       count(*) filter (where delivery_known and prev_late) as seller_past_late,
       count(*) filter (where review_known) as seller_past_reviews,
       count(*) filter (where review_known and prev_bad) as seller_past_bad
from pairs
group by order_id;