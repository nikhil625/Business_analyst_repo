#  SaaS Product Analytics Case Study

---

#  Executive Summary

This project analyzes customer behavior, feature adoption, retention, and revenue drivers for a SaaS product. The objective is to identify key growth levers, reduce churn, and improve monetization through data-driven insights.

###  Key Highlights:

* **Adoption Rate:** ~71.5% of customers actively use the product
* **Engagement Gap:** Average health score (~59) indicates moderate engagement
* **Revenue Driver:** High feature usage strongly correlates with higher MRR
* **Upgrade Drivers:** Dashboard, Mobile App, and Team Collaboration features (~12% conversion)
* **Churn Risk:** Significant portion of users in "Needs Attention" segment

---

#  Project Structure

```
submission/
├── README.md
├── metric_definitions.md
├── sql/
│   ├── 01_feature_adoption.sql
│   ├── 02_health_score.sql
│   ├── 03_cohort_retention.sql
│   ├── 04_feature_value.sql
│   └── 05_dashboard_queries.sql
├── analysis/
│   ├── feature_analysis.xlsx
│   ├── health_score_validation.ipynb
│   └── statistical_tests.R
├── dashboard/
│   └── product_health.pbix
├── stakeholder_report.pdf
└── appendix/
    └── methodology.md
```

---

#  Setup Instructions

### 1. Database Setup

```sql
CREATE DATABASE saas_project;
USE saas_project;
```

---

### 2. Import Data

Load the following CSV files:

| File                    | Table                   |
| ----------------------- | ----------------------- |
| customers.csv           | raw_customers           |
| feature_usage.csv       | raw_feature_usage       |
| subscription_events.csv | raw_subscription_events |
| support_tickets.csv     | raw_support_tickets     |

---

### 3. Run SQL Scripts

Execute in order:

```
01_feature_adoption.sql  
02_health_score.sql  
03_cohort_retention.sql  
04_feature_value.sql  
05_dashboard_queries.sql  
```

---

#  Key Analyses

---

##  Feature Adoption

* Measured feature usage across all customers
* Identified high vs low adoption features

---

##  Customer Health Scoring

* Built a **0–100 explainable score** using:

  * Feature usage
  * Login activity
  * Support interaction
  * Payment behavior
  * New feature adoption

---

##  Cohort Retention

* Monthly cohorts based on signup date
* Measured retention at M1, M3, M6, M12
* Calculated Net Revenue Retention (NRR)

---

##  Feature Value Analysis

* Identified features driving upgrades
* Analyzed churn behavior and feature abandonment
* Segmented customers by usage and MRR

---

##  Dashboard Metrics

* Product Adoption Rate
* Feature Penetration by Tier
* Customer Health Distribution
* Top 100 Churn Risk Customers
* Revenue Impact of Feature Usage

---

#  North Star KPIs

| KPI                          | Purpose                        |
| ---------------------------- | ------------------------------ |
| Multi-Feature Adoption       | Measures product stickiness    |
| WAU/MAU Ratio                | Engagement consistency         |
| Feature → Upgrade Conversion | Monetization efficiency        |
| Avg Health Score             | Churn prediction signal        |
| Net Revenue Retention        | Growth from existing customers |

---

# Key Insights

---

##  Product Engagement

* High adoption but moderate engagement depth
* Opportunity to increase daily/weekly usage

---

##  Revenue Drivers

* High feature usage → significantly higher MRR
* Strong evidence of product-led growth

---

##  Churn Risk

* Majority of users fall in mid-risk categories
* Very few "Champions" users

---

##  Feature Performance

Top monetization drivers:

* Dashboard
* Mobile App
* Team Collaboration

---

#  Business Recommendations

---

## 1. Double Down on High-Value Features

Focus development and marketing on:

* Dashboard
* Reporting
* Mobile App

---

## 2. Improve Feature Adoption

* Guided onboarding
* In-app feature discovery prompts

---

## 3. Upsell Strategy

Target:

* High usage, low-tier customers

Approach:

* Feature-based upgrade nudges

---

## 4. Reduce Churn Risk

* Monitor "Needs Attention" users
* Trigger early engagement campaigns

---

## 5. Pricing Optimization

* Introduce feature gating for premium features
* Improve tier differentiation

---

#  Tools & Technologies

* SQL (MySQL)
* Excel (Pivot Analysis)
* Streamlit (Dashboard)
* Python (Validation)

---

#  Conclusion

The product shows strong adoption and monetization potential. By improving engagement depth, optimizing feature packaging, and targeting high-value users, the business can significantly improve retention and revenue growth.

---

#  Skills Demonstrated

* Advanced SQL Analytics
* Product & Growth Analytics
* Cohort Analysis
* Customer Segmentation
* KPI Design
* Business Strategy

---
