# SaaS Product Feature Adoption & Monetization

## Executive Summary

This project analyzes product usage, feature adoption, customer health, retention, support experience, and monetization opportunities for a B2B SaaS dataset. SQL transformations are written for MySQL 8+, hypothesis testing is implemented in Python, and outputs are designed for Excel or dashboard tools.

## How To Reproduce

1. Create a MySQL database:

```sql
CREATE DATABASE IF NOT EXISTS dataflow_project;
USE dataflow_project;
```

2. Create/import the four CSV tables using MySQL Workbench:

```text
customers.csv              -> raw_customers
feature_usage.csv          -> raw_feature_usage
subscription_events.csv    -> raw_subscription_events
support_tickets.csv        -> raw_support_tickets
```

3. Normalize the raw tables into analysis views before running the SQL files. The required normalized views are:

```text
customers
feature_usage
subscription_events
support_tickets
```

4. Run the SQL files in order:

```text
sql/01_feature_adoption.sql
sql/02_health_score.sql
sql/03_cohort_retention.sql
sql/04_feature_value.sql
sql/05_dashboard_queries.sql
```

Run `02_health_score.sql` before `05_dashboard_queries.sql`, because the dashboard file uses the `customer_health_scores` view.

5. Run Python hypothesis testing:

```bash
cd analysis
pip install pandas scipy sqlalchemy pymysql
python statistical_tests.py
```

Set the MySQL password first:

```powershell
$env:MYSQL_PASSWORD='your_mysql_password'
```

## Data Reconciliation

The uploaded CSV schema differs from the written case prompt. The analysis uses these mappings:

```text
plan                  -> current_tier
api_integration       -> API Connectors
automation            -> Real-time Sync
ai_insights           -> Custom Transformations
actions_performed     -> usage_count
duration_seconds      -> session_duration_seconds
opened_at             -> created_date
sentiment text        -> numeric sentiment_score
```

The main analysis window is Jan-Apr 2025 because the uploaded dataset has stronger usable product activity in that period. Signup cohorts use Jan-Dec 2024.

## Key Findings

Populate after running SQL:

1. Highest adoption feature:
2. Stickiest feature by DAU/MAU:
3. Health segment with highest churn risk:
4. Feature with strongest upgrade association:
5. Highest-priority upsell segment:

## Top Recommendations

1. Double down on the feature with the strongest adoption, stickiness, and upgrade lift.
2. Target high-usage starter customers with Professional-tier messaging.
3. Use the health score to prioritize at-risk outreach.

## Assumptions and Limitations

- Findings are correlational, not causal.
- `actions_performed > 0` indicates true feature use.
- `duration_seconds` is used as a session engagement proxy.
- `growth` and `enterprise` are treated as higher-touch account segments.
- Support sentiment is converted from text labels into numeric values.
