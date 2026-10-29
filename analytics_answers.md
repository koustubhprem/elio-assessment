## Analytics Answers

## Part A - Frame and Explore

A1: Question selected to answer: 
Question - What drives a bad review, and which of those drivers can the business actually control?

Reasoning for choosing this question to answer - 
Out of all the orders placed, ~97% of users only order once. Only 3% order more than once, and that is a very small base(target value is too small) to understand which customers are most likely to buy again, and is it worth targeting them?. Similarly, a LTV is not possible because if the user is purchasing only one product, the lifetime value will be equal to the price of their first order.

Whereas, there are roughly 14% of reviews that are bad(considering only 1 and 2 review, treating 3 as neutral and 4,5 as good review). And roughly 54% of late deliveries have bad reviews. Poor ratings will in general, result in poor seller ratings, and if the customer is unhappy in first purchase, the chances of them buying again are very low. That's why this question matters.

Decision it informs: to make the question actionable, it is framed as a prediction: which orders are likely to get a bad review, scored when the seller hands the parcel to the carrier. At that point there are still several days before delivery, so the business can decide which orders to step in on, and the model's drivers show which causes are controllable.

A2: Build the modelling dataset:

- **Unit of analysis:** one delivered order with a review (95,392 orders).
- **Target:** `bad_review` = 1 if the order's earliest review is 1-2 stars, otherwise 0 (12.8% overall).
- **Point in time:** each row is observed at carrier handover, when the seller hands the parcel to the carrier. Every feature uses only information available at that moment: dispatch timing against the seller's deadline, the delivery promise, basket details, same-state shipping, product category and the seller's track record.
- **Avoiding future information:** the actual delivery date, whether the order arrived late, and the review text are excluded. The seller's track record counts an earlier order's lateness only if it had already been delivered, and its review only if it had already been submitted, before the current order's handover. Seller rates are smoothed towards the training-period averages (9% late, 14% bad reviews) so sellers with few orders don't get extreme values.
- **Time window:** handovers from 1 Jan 2017 to 31 Aug 2018. Training uses Jan 2017-Mar 2018 (62,833 orders) and testing Apr-Aug 2018 (32,559 orders).
- **SQL:** `sql/clean_orders.sql` (one row per delivered order), `sql/seller_history.sql` (point-in-time seller record), `sql/feature_table.sql` (features and target).

A3: Explore and check the data:
1. **Repeat buyers are rare.** 96.9% of customers placed one order, so customer-level questions (repeat purchase, lifetime value) are not answerable well. The unit of analysis is the order instead.
2. **The target is imbalanced but well populated.** 14.7% of reviewed orders get 1-2 stars (13.2% of delivered orders), which gives over 12,000 bad reviews to learn from.
3. **Late delivery is the main driver.** 54% of late orders get a bad review against 9% of on-time orders, rising from 32% at 1-3 days late to 79% at 8+ days late.
4. **Late seller dispatch can act as an early warning.** 9% of orders reach the carrier after the shipping deadline; these get bad reviews twice as often (24% vs 12%) and arrive late almost four times as often (24% vs 6%). This is known at handover, so it can be used for prediction.
5. **Most sellers are small.** The median seller has 7 orders and 59% have fewer than 10, so seller track records are smoothed to avoid unreliable rates.
6. **The bad review rate moves over time.** It is 10-12% in most months but spikes in Nov 2017 (17%) and Feb-Mar 2018 (19-21%), tracking late deliveries closely (correlation 0.88). The model is therefore evaluated on a later period rather than a random sample.


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
| Sept-Dec 2016 and Sept-Oct 2018 have very few orders| analysis limited to Jan 2017-Aug 2018 |
| 1.3% of orders have more than one seller| each order linked to its first item's seller |
| Payment totals equal price plus freight for 99.5% of orders| payment data not used as a feature |


**What the data can't tell us**
- Why customers were unhappy beyond delivery timing: there is no data on product quality, damage or the courier's last mile, so part of the risk can't be explained. This can be analysed by reveiweing the comments.
- What would happen if the business intervened: the data only shows outcomes with no action taken, so a campaign's effect has to be measured with an experiment.
- Returns and refunds are not in the dataset.

## Part B - Model

### Model choice
Logistic regression, because the main drivers are simple, the coefficients can be explained in plain terms, and the scores can be read as probabilities for estimating impact. It uses the numeric features plus customer state and product category. Before fitting:
- **Multicollinearity:** days_left_to_promise, promised_days and days_to_handover had VIFs above 250, because promised days equal days to handover plus days left. days_left_to_promise was dropped, after which every VIF was below 2.3.


### B1. Evaluation
The campaign will only contact the riskiest orders, so the main metric is precision among the top-scored orders, compared with a simple rule and with random targeting. All results are on the test period (Apr-Aug 2018), which the model did not see.

| Approach (same 7.9% of orders contacted) | Precision | Recall |
|---|---|---|
| Random | 10.7% | 7.9% |
| Baseline rule: flag late dispatch | 21.1% | 15.6% |
| **Model** | **31.6%** | **23.3%** |

- **What the model adds:** at the same campaign size as the rule, precision rises from 21% to 32%, about 50% more bad reviews found for the same effort.
- **Choosing the campaign size:** precision falls steeply up to about 10% of orders contacted (29%), then flattens slowly towards the random rate. The top 10% captures most of the concentrated risk.
- **At the chosen cut-off** (the score that flags the top 10% of training orders, applied unchanged to test): precision 27.4%, recall 28.6%. The model reaches 994 bad reviews, against about 390 by contacting the same number of orders at random.
- **No overfitting:** train and test results are close (AUC 0.671 vs 0.668, F1 0.29 vs 0.28).
- **Calibration:** predictions match reality in training (13.9% predicted vs 13.9% actual) but run high in the calmer test period (14.5% vs 10.7%). The ranking still holds in every decile, with the actual rate rising from 5.5% to 28.8%, so the scores are used to choose whom to contact, while impact estimates use the actual rates.
- **Not used:** accuracy, because 89% of orders get no bad review, so predicting "no bad review" for every order would score 89% while finding none.

### B2. Explanation

**What drives the predictions** (percentage change in the odds of a bad review for a one standard deviation increase in each feature, from an unregularised refit with p-values):
- **Slow handover by the seller** raises the risk most: odds up 24% (p < 0.001). Dispatching after the shipping deadline adds to this.
- **Bigger baskets:** more items (up 21%) and more sellers in the order (up 17%).
- **A seller's history of bad reviews:** up 19%.
- **Higher price and freight cost** raise the risk slightly (up 5% and 3%).
- **Same-state shipping** lowers the risk by 21%, and **a longer delivery promise** by 8%.
- **Not significant once the others are known:** the seller's past late rate (p = 0.59), a missing product listing (p = 0.11) and the number of product photos (p = 0.05). What the seller does on this order matters more than their history of lateness.
- **Category and region** also matter (for example audio is riskier, books and food safer), but these can't be changed by the business.


**What the business can control:** how fast sellers dispatch, and which sellers have a poor review history. These point to dispatch alerts and seller monitoring alongside the customer campaign.

**What the business can control:** how fast sellers dispatch, and which sellers have a poor review history. These point to dispatch alerts and seller monitoring alongside the customer campaign.

**Where the model is weak**
- It can't see causes after handover or not recorded (product quality, damage, the last mile). Even with perfect knowledge of late delivery, top-10% precision would only reach about 39%.
- It over-predicts in calmer periods, so probabilities need recalibrating before they are used to estimate volumes.
- New sellers have no track record, so their seller rates default to the average.
- Multi-seller orders (1.3%) are linked to the first item's seller.
- The seller's past late rate is not significant once current dispatch timing and bad review history are known.


**Checks that the model has no leakage**
- The seller history only uses outcomes known at each handover, checked by hand for one seller.
- Scaling, smoothing averages and the cut-off all come from training data only.
- Leakage test: adding the actual late delivery flag, only known after handover, lifts AUC from 0.67 to 0.72. The model deliberately leaves it out.


## Part C - Recommend and test

### C1. The recommendation
**Target segment:** each week, score every order when the seller hands it to the carrier and select the riskiest 10% by model score. At recent volumes this is about 650 orders a month, of which 28.8% would otherwise get a bad review (about 188 a month), almost three times the average rate.

**Mechanic:** send these customers a proactive message before delivery (acknowledging the order and giving a direct contact if anything goes wrong), together with a $5 goodwill voucher for their next purchase. The aim is to reach the customer before they are disappointed and turn a likely 1-2 star review into a neutral or good one.

**Expected impact** (assumptions: the campaign prevents 10%, 20% or 30% of bad reviews among contacted orders; every contacted order gets a $5 voucher; the message is automated and free):

| Scenario | Bad reviews prevented per month | Monthly cost | Cost per bad review prevented |
|---|---|---|---|
| Low (10%) | ~19 | ~$3,255 | ~$174 |
| Mid (20%) | ~38 | ~$3,255 | ~$87 |
| High (30%) | ~56 | ~$3,255 | ~$58 |

Targeted orders have a median value of $164, and in the mid case preventing a bad review costs about half the value of one order. The campaign pays off if a bad review costs the business at least that much in lost repeat purchases and weaker seller ranking. Amounts are in the dataset's currency (Brazilian reais), shown as $ for simplicity.

### C2. The experiment design
- **Groups:** orders in the riskiest 10% at handover are randomly split 50/50 into treatment (message and voucher) and control (no contact). Randomising within the eligible group means the campaign is the only systematic difference between the groups, so a difference in bad reviews can be attributed to it. Both groups run over the same weeks, so seasonal swings affect both equally.
- **Primary metric:** bad review rate (1-2 stars) in treatment vs control.
- **Guardrail metrics:** review response rate (fewer reviews could look like fewer bad reviews), repeat purchase within 90 days, and voucher cost per order.
- **Sample size and duration:** to detect a 20% drop in bad reviews (from 28.8% to 23.1%) with 80% power at 5% significance, the test needs 906 orders per group (1,812 in total), about 2.8 months at 650 eligible orders a month. A 10% drop would need nearly a year, so the test is planned around a 20% effect.
- **Decision rule:**
  - **Roll out:** bad reviews fall significantly, the guardrails hold, and the cost per bad review prevented is below the business's estimate of what a bad review costs.
  - **Change it:** bad reviews fall but the cost is too high, so test a message without the voucher.
  - **Stop:** no significant difference after three months.

### C3. Caveats
The impact range rests on assumed effect sizes and costs rather than measured ones, and the model's probabilities run high in calmer periods, so the estimates use actual bad review rates and should be treated as indicative. The model predicts which orders are likely to get a bad review; it does not show that contacting them will change the outcome, since some customers will be unhappy whatever is done. Only the experiment can measure what the campaign actually causes.


