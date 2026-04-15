# Methodology

## Health Score Design

The customer health score is designed as an explainable weighted score rather than a black-box model. It combines product engagement, support experience, payment behavior, and new feature adoption into a 0-100 score.

## Components

Feature usage intensity receives the highest weight because active product usage is the strongest available behavioral signal. Support experience captures friction and sentiment. Session frequency approximates login behavior. Payment history captures churn, downgrade, renewal, and reactivation signals. New feature engagement measures whether customers are adopting recently launched product capabilities.

## Weights

```text
Feature Usage Intensity: 35%
Support Experience: 20%
Session Frequency: 15%
Payment History: 15%
New Feature Engagement: 15%
```

## Validation

The score is validated by comparing churn rates across health segments and by creating a confusion matrix where `At Risk` customers are treated as predicted churn-risk customers.

Recommended validation checks:

```text
Churn rate by health segment
Health distribution by tier
False positives for churn prediction
False negatives for churn prediction
Upgrade rate by health segment
```

## Limitations

The score is based on available behavioral and operational data only. It does not include survey text, account notes, competitive pressure, contract dates, or qualitative CSM feedback. It should be used as a prioritization tool, not as a definitive customer outcome prediction.
