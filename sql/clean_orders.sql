-- earliest review per order
create or replace table first_review as
select order_id, review_score, review_answer_timestamp
from olist_order_reviews_dataset
qualify row_number() over (partition by order_id order by review_answer_timestamp) = 1;

-- items summarised per order
create or replace table order_items_agg as
select order_id,
       count(*) as n_items,
       count(distinct seller_id) as n_sellers,
       sum(price) as total_price,
       sum(freight_value) as total_freight,
       max(shipping_limit_date) as shipping_limit_date,
       arg_min(seller_id, order_item_id) as seller_id,
       arg_min(product_id, order_item_id) as product_id
from olist_order_items_dataset
group by order_id;

-- payments summarised per order
create or replace table order_payments_agg as
select order_id,
       sum(payment_value) as total_payment,
       max(payment_installments) as installments
from olist_order_payments_dataset
group by order_id;

-- one row per delivered order with valid dates and a review
create or replace table clean_orders as
select o.order_id,
       c.customer_state,
       o.order_purchase_timestamp as purchase_ts,
       o.order_delivered_carrier_date as handover_ts,
       o.order_delivered_customer_date as delivered_ts,
       o.order_estimated_delivery_date as promised_ts,
       i.n_items, i.n_sellers, i.total_price, i.total_freight, i.shipping_limit_date,
       i.seller_id, i.product_id,
       p.total_payment, p.installments, r.review_score, r.review_answer_timestamp
from olist_orders_dataset o
join olist_customers_dataset c on o.customer_id = c.customer_id
join order_items_agg i on o.order_id = i.order_id
join first_review r on o.order_id = r.order_id
left join order_payments_agg p on o.order_id = p.order_id
where o.order_status = 'delivered'
  and o.order_delivered_customer_date is not null
  and o.order_delivered_carrier_date is not null
  and o.order_delivered_carrier_date >= o.order_purchase_timestamp
  and i.shipping_limit_date <= timestamp '2018-12-31';