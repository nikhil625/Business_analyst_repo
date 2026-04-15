# Methodology: Customer Health Score Design

---

## Overview

The Customer Health Score was designed to quantify user engagement and risk on a scale of 0 to 100. The goal was to create a simple, explainable metric that combines multiple behavioral signals into a single score that can be used for monitoring, segmentation, and decision-making.

Rather than using a black-box model, the score is built using a weighted approach so that each component is transparent and easy to interpret.

---

## Data Sources

The score is derived using the following datasets:

* `feature_usage` → captures product engagement and session activity
* `support_tickets` → reflects user experience and friction
* `subscription_events` → indicates payment behavior and churn
* `customers` → provides customer-level attributes

---

## Components of the Health Score

The score is composed of five key components, each representing a different aspect of customer behavior.

---

### 1. Feature Usage Intensity (Weight: 30%)

This measures how actively a customer uses the product.

* Calculated using the number of feature interactions
* Higher usage indicates stronger engagement and product dependency

**Rationale:**
Users who frequently use multiple features are more likely to derive value and remain retained.

---

### 2. Login Activity / Session Engagement (Weight: 20%)

This captures how often and how long users engage with the platform.

* Derived from total session duration
* Higher session time implies deeper interaction

**Rationale:**
Frequent and longer sessions indicate habitual usage, which is a strong retention signal.

---

### 3. Support Interaction (Weight: 20%)

This evaluates both the volume and sentiment of support tickets.

* More tickets reduce the score
* Positive sentiment improves the score
* Negative sentiment reduces the score

**Rationale:**
Frequent issues or negative experiences increase churn risk, while positive interactions indicate satisfaction.

---

### 4. Payment Behavior (Weight: 15%)

This reflects subscription stability and churn behavior.

* Customers who churn receive the lowest score
* Active customers with no churn signals receive higher scores

**Rationale:**
Payment continuity is a direct indicator of customer retention.

---

### 5. New Feature Adoption (Weight: 15%)

This measures how many newly introduced features a customer has adopted.

* Encourages tracking of innovation adoption
* Rewards users exploring new capabilities

**Rationale:**
Customers who adopt new features are more engaged and less likely to churn.

---

## Score Calculation

Each component is normalized and combined into a weighted sum:

* Feature Usage → up to 30 points
* Login Activity → up to 20 points
* Support Interaction → up to 20 points
* Payment Behavior → up to 15 points
* New Feature Adoption → up to 15 points

The total raw score is then scaled to a 0–100 range.

---

## Health Score Segmentation

Customers are grouped into four tiers based on their score:

| Tier            | Score Range | Meaning                                 |
| --------------- | ----------- | --------------------------------------- |
| At Risk         | 0 – 40      | High churn risk, low engagement         |
| Needs Attention | 41 – 65     | Moderate engagement, improvement needed |
| Healthy         | 66 – 85     | Good engagement and stability           |
| Champions       | 86 – 100    | Highly engaged and valuable users       |

---

## Validation Approach

The effectiveness of the health score was validated using multiple methods:

1. **Distribution Check**
   Ensured scores are spread across tiers and not concentrated in a single range.

2. **Tier Consistency**
   Verified that average scores increase logically from At Risk → Champions.

3. **Churn Alignment**
   Observed that lower scores are associated with churned or inactive users.

4. **Business Interpretability**
   Ensured each component contributes meaningfully and aligns with real-world behavior.

---

## Key Observations

* Most users fall into the “Needs Attention” segment, indicating moderate engagement
* The score successfully captures differences in engagement levels
* High-score users show stronger product usage and higher value

---

## Limitations

* The model uses fixed weights, which may not capture all behavioral nuances
* External factors (pricing changes, market conditions) are not included
* Limited historical data may impact long-term accuracy

---

## Future Improvements

* Introduce machine learning models for dynamic weighting
* Incorporate time-based trends (e.g., recent activity vs historical)
* Add more behavioral signals (e.g., feature depth, frequency patterns)

---

## Conclusion

The Customer Health Score provides a clear and interpretable way to measure engagement and risk. It enables teams to identify at-risk users, prioritize retention efforts, and better understand how customer behavior impacts business outcomes.

---
