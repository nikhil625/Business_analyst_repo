#  Metric Definitions

This document defines all key product and business metrics used in the analysis, along with formulas and interpretations.

---

#  1. Product Adoption Rate

### Definition:

Percentage of total customers who have used at least one feature.

### Formula:

```
Adoption Rate (%) = (Active Customers / Total Customers) × 100
```

### SQL Logic:

* Active Customers → DISTINCT customers in `raw_feature_usage`
* Total Customers → COUNT from `raw_customers`

### Interpretation:

Measures overall product reach and onboarding success.

---

# 2. Feature Penetration Rate

### Definition:

Percentage of customers within a plan who use a specific feature.

### Formula:

```
Penetration (%) = (Feature Users in Plan / Total Customers in Plan) × 100
```

### Interpretation:

Helps identify:

* High-value features
* Underutilized features
* Opportunities for upsell

---

#  3. Customer Health Score (0–100)

### Definition:

Composite score representing customer engagement, satisfaction, and retention risk.

### Components & Weights:

| Component            | Description               | Weight |
| -------------------- | ------------------------- | ------ |
| Feature Usage        | Number of interactions    | 30     |
| Login Activity       | Session duration          | 20     |
| Support Experience   | Ticket volume & sentiment | 20     |
| Payment Behavior     | Churn / renewal status    | 15     |
| New Feature Adoption | Usage of key features     | 15     |

### Formula:

```
Health Score = (Weighted Sum of Components / 80) × 100
```

### Segments:

| Score Range | Tier            |
| ----------- | --------------- |
| 0 – 40      | At Risk         |
| 41 – 65     | Needs Attention |
| 66 – 85     | Healthy         |
| 86 – 100    | Champions       |

### Interpretation:

Used to:

* Identify churn risk
* Prioritize customer success efforts

---

#  4. Churn Rate

### Definition:

Percentage of customers who canceled subscription.

### Formula:

```
Churn Rate (%) = (Churned Customers / Total Customers) × 100
```

### Interpretation:

Key indicator of retention performance.

---

#  5. Revenue Impact by Feature Usage

### Definition:

Average MRR segmented by feature usage intensity.

### Buckets:

* High Usage (≥5 features)
* Medium Usage (3–4 features)
* Low Usage (<3 features)

### Interpretation:

Measures correlation between:

* Product usage
* Revenue generation

---

#  6. Multi-Feature Adoption Rate (North Star KPI)

### Definition:

Percentage of customers using 2 or more features.

### Formula:

```
Multi-Feature Adoption (%) = 
(Customers using ≥2 features / Total Customers) × 100
```

### Interpretation:

Indicates product stickiness and engagement depth.

---

#  7. WAU / MAU Ratio (Engagement KPI)

### Definition:

Weekly Active Users divided by Monthly Active Users.

### Formula:

```
WAU/MAU = Average Weekly Active Users / Monthly Active Users
```

### Interpretation:

* Measures engagement consistency
* Preferred over DAU due to sparse daily data

---

# 8. Feature-to-Upgrade Conversion

### Definition:

Percentage of feature users who upgraded their plan.

### Formula:

```
Conversion (%) = (Upgraded Users of Feature / Total Feature Users) × 100
```

### Interpretation:

Identifies:

* Monetizable features
* Upgrade drivers

---

# 9. Average Customer Health Score

### Definition:

Average health score across all customers.

### Formula:

```
Avg Health Score = AVG(health_score)
```

### Interpretation:

* Overall product health indicator
* Early warning for churn trends

---

# 10. Feature Usage vs MRR

### Definition:

Relationship between number of features used and revenue.

### Formula:

```
Avg MRR by Feature Count
```

### Interpretation:

Validates:

* Product-led growth
* Value perception

---

# 11. Net Revenue Retention (NRR)

### Definition:

Measures revenue retained from existing customers including expansions.

### Formula:

```
NRR (%) = (Current Revenue / Initial Revenue) × 100
```

### Interpretation:

* > 100% → Growth from existing users
* Most critical SaaS metric

---

#  Summary

These metrics collectively measure:

* Product adoption
* Engagement depth
* Customer health
* Revenue impact
* Growth efficiency

They form the foundation for data-driven product and business decisions.
