## Analytics Answers

## Part A - Frame and Explore

A1: Question selected to answer: 
Question - What drives a bad review, and which of those drivers can the business actually control?

Reasoning for choosing this question to answer - 
Out of all the orders placed, ~97% of users only order once. Only 3% order more than once, and that is a very small base(target value is too small) to understand which customers are most likely to buy again, and is it worth targeting them?. Similarly, a LTV is not possible because if the user is purchasing only one product, the lifetime value will be equal to the price of their first order.

Whereas, there are roughly 14% of reviews that are bad(considering only 1 and 2 review, treating 3 as neutral and 4,5 as good review). And roughly 54% of late deliveries have bad reviews. Poor ratings will in general, result in poor seller ratings, and if the customer is unhappy in first purchase, the chances of them buying again are very low. That's why this question matters.

A2: Build the modelling dataset:

A3: Explore and check the data:
1. **Repeat buyers are rare.** 96.9% of customers placed one order, so customer-level questions (repeat purchase, lifetime value) are not answerable well. The unit of analysis is the order instead.
2. **The target is imbalanced but well populated.** 14.7% of reviewed orders get 1-2 stars (13.2% of delivered orders), which gives over 12,000 bad reviews to learn from.
3. **Late delivery is the main driver.** 54% of late orders get a bad review against 9% of on-time orders, rising from 32% at 1-3 days late to 79% at 8+ days late.
4. **Late seller dispatch can act as an early warning.** 9% of orders reach the carrier after the shipping deadline; these get bad reviews twice as often (24% vs 12%) and arrive late almost four times as often (24% vs 6%). This is known at handover, so it can be used for prediction.


**Data quality issues and handling**
| Issue | Handling Approach|
|---|---|
| customer_id is new for every order (99,441 IDs, 96,096 people) | customer_unique_id used for any customer-level count |
| 547 orders have more than one review | earliest review per order kept |
| Missing delivery dates are mostly undelivered orders; 8 delivered orders have none | only delivered orders with valid dates will be used for modelling |
| 4 orders have shipping deadlines in 2020 | excluded as data-entry errors |
| 610 products have no category or listing details | Will label these as 'unknown' and will add a missing-listing flag|
| 2 categories have no English translation | Portuguese name will be kept |
| Orders can have several items and payments | summarised per order before joining, to avoid duplicating orders |
| Geolocation has about 262k duplicate rows| bad reviews are dependent on seller deadlines and late delivery that is captured in date  |


