# Metric Definitions

## Feature Adoption Rate

Share of eligible customers who used a feature at least once.

```text
Adoption Rate = Customers with usage_count > 0 / Eligible Customers
```

## DAU/MAU Ratio

Measures feature stickiness.

```text
DAU/MAU = Average Daily Active Feature Users / Monthly Active Feature Users
```

## Time To First Use

Days between feature release date and the first recorded customer usage.

```text
Time To First Use = First Usage Date - Feature Release Date
```

## Power Users

Customers who use a feature on 10 or more distinct days in a month.

```text
Power Users = COUNT(customers with active feature days >= 10 per month)
```

## Activation Rate

Share of eligible customers who used the feature within seven days of release.

```text
Activation Rate = Customers first using feature within 7 days / Eligible Customers
```

## Customer Health Score

Explainable score from 0 to 100.

```text
Health Score =
  35% Feature Usage Intensity
+ 20% Support Experience
+ 15% Login/Session Frequency
+ 15% Payment History
+ 15% New Feature Engagement
```

## Health Segments

```text
At Risk: 0-40
Needs Attention: 41-65
Healthy: 66-85
Champions: 86-100
```

## Logo Retention

Share of customers from a signup cohort still active at a later month.

```text
Logo Retention = Active Customers in Month N / Cohort Customers
```

## Net Revenue Retention

Revenue retained from an existing cohort after expansion, downgrade, and churn.

```text
NRR = Ending Cohort MRR / Starting Cohort MRR
```

## Upgrade Lift

Difference in upgrade rate between feature users and non-users.

```text
Upgrade Lift = Upgrade Rate for Feature Users - Upgrade Rate for Non-Users
```

## Estimated ARR Impact

Correlational estimate of annualized revenue impact from a feature adoption lift.

```text
Estimated ARR Impact =
(Average MRR of Adopters - Average MRR of Non-Adopters)
* Incremental Adopters
* 12
```
