/*
03_cohort_retention_mysql.sql
MySQL 8+

Jan-Dec 2024 signup cohorts, month 0-12 logo retention, NRR, and adoption
hypothesis input.
*/

CREATE OR REPLACE VIEW cohort_retention_long AS
WITH RECURSIVE month_numbers AS (
    SELECT 0 AS month_number
    UNION ALL SELECT month_number + 1 FROM month_numbers WHERE month_number < 12
),
cohorts AS (
    SELECT
        customer_id,
        signup_date,
        DATE_FORMAT(signup_date, '%Y-%m-01') AS cohort_month,
        mrr AS starting_mrr
    FROM customers
    WHERE signup_date >= '2024-01-01'
      AND signup_date < '2025-01-01'
),
customer_month_grid AS (
    SELECT
        c.customer_id,
        c.cohort_month,
        c.starting_mrr,
        mn.month_number,
        DATE_ADD(c.cohort_month, INTERVAL mn.month_number MONTH) AS cohort_age_month
    FROM cohorts c
    CROSS JOIN month_numbers mn
),
event_state AS (
    SELECT
        cmg.customer_id,
        cmg.cohort_month,
        cmg.starting_mrr,
        cmg.month_number,
        COALESCE(SUM(CASE WHEN se.event_date < DATE_ADD(cmg.cohort_age_month, INTERVAL 1 MONTH) THEN se.mrr_change ELSE 0 END), 0) AS cumulative_mrr_change,
        MAX(CASE WHEN se.event_type = 'churn' AND se.event_date < DATE_ADD(cmg.cohort_age_month, INTERVAL 1 MONTH) THEN se.event_date END) AS latest_churn_date,
        MAX(CASE WHEN se.event_type = 'reactivation' AND se.event_date < DATE_ADD(cmg.cohort_age_month, INTERVAL 1 MONTH) THEN se.event_date END) AS latest_reactivation_date
    FROM customer_month_grid cmg
    LEFT JOIN subscription_events se ON cmg.customer_id = se.customer_id
    GROUP BY cmg.customer_id, cmg.cohort_month, cmg.starting_mrr, cmg.month_number, cmg.cohort_age_month
),
customer_state AS (
    SELECT
        *,
        CASE WHEN latest_churn_date IS NOT NULL AND (latest_reactivation_date IS NULL OR latest_churn_date > latest_reactivation_date) THEN 0 ELSE 1 END AS active_logo_flag,
        GREATEST(0, starting_mrr + cumulative_mrr_change) AS ending_mrr
    FROM event_state
)
SELECT
    cohort_month,
    month_number,
    COUNT(DISTINCT customer_id) AS cohort_customers,
    SUM(active_logo_flag) AS retained_customers,
    ROUND(SUM(active_logo_flag) / NULLIF(COUNT(DISTINCT customer_id), 0), 4) AS logo_retention,
    SUM(starting_mrr) AS starting_mrr,
    SUM(ending_mrr) AS ending_mrr,
    ROUND(SUM(ending_mrr) / NULLIF(SUM(starting_mrr), 0), 4) AS nrr
FROM customer_state
GROUP BY cohort_month, month_number;

SELECT * FROM cohort_retention_long ORDER BY cohort_month, month_number;

SELECT
    cohort_month,
    MAX(CASE WHEN month_number = 0 THEN logo_retention END) AS month_0,
    MAX(CASE WHEN month_number = 1 THEN logo_retention END) AS month_1,
    MAX(CASE WHEN month_number = 2 THEN logo_retention END) AS month_2,
    MAX(CASE WHEN month_number = 3 THEN logo_retention END) AS month_3,
    MAX(CASE WHEN month_number = 4 THEN logo_retention END) AS month_4,
    MAX(CASE WHEN month_number = 5 THEN logo_retention END) AS month_5,
    MAX(CASE WHEN month_number = 6 THEN logo_retention END) AS month_6,
    MAX(CASE WHEN month_number = 7 THEN logo_retention END) AS month_7,
    MAX(CASE WHEN month_number = 8 THEN logo_retention END) AS month_8,
    MAX(CASE WHEN month_number = 9 THEN logo_retention END) AS month_9,
    MAX(CASE WHEN month_number = 10 THEN logo_retention END) AS month_10,
    MAX(CASE WHEN month_number = 11 THEN logo_retention END) AS month_11,
    MAX(CASE WHEN month_number = 12 THEN logo_retention END) AS month_12,
    MAX(CASE WHEN month_number = 12 THEN nrr END) AS month_12_nrr
FROM cohort_retention_long
GROUP BY cohort_month
ORDER BY cohort_month;

WITH cohorts AS (
    SELECT customer_id, signup_date
    FROM customers
    WHERE signup_date >= '2024-01-01' AND signup_date < '2025-01-01'
),
adoption AS (
    SELECT
        c.customer_id,
        COUNT(DISTINCT fu.feature_name) AS new_features_adopted_within_30_days
    FROM cohorts c
    LEFT JOIN feature_usage fu ON c.customer_id = fu.customer_id
        AND fu.feature_name IN ('API Connectors', 'Real-time Sync', 'Custom Transformations')
        AND fu.usage_count > 0
        AND fu.usage_date >= '2025-01-01'
        AND fu.usage_date < '2025-04-01'
    GROUP BY c.customer_id
),
retention_12 AS (
    SELECT
        c.customer_id,
        CASE
            WHEN MAX(CASE WHEN se.event_type = 'churn' AND se.event_date < DATE_ADD(c.signup_date, INTERVAL 12 MONTH) THEN se.event_date END) IS NOT NULL
             AND (
                MAX(CASE WHEN se.event_type = 'reactivation' AND se.event_date < DATE_ADD(c.signup_date, INTERVAL 12 MONTH) THEN se.event_date END) IS NULL
                OR MAX(CASE WHEN se.event_type = 'churn' AND se.event_date < DATE_ADD(c.signup_date, INTERVAL 12 MONTH) THEN se.event_date END)
                   > MAX(CASE WHEN se.event_type = 'reactivation' AND se.event_date < DATE_ADD(c.signup_date, INTERVAL 12 MONTH) THEN se.event_date END)
             )
                THEN 0 ELSE 1
        END AS retained_12m_flag
    FROM cohorts c
    LEFT JOIN subscription_events se ON c.customer_id = se.customer_id
    GROUP BY c.customer_id, c.signup_date
)
SELECT
    CASE WHEN COALESCE(a.new_features_adopted_within_30_days, 0) >= 2 THEN 'Adopted 2+ new features within 30 days'
         ELSE 'Did not adopt 2+ new features within 30 days'
    END AS adoption_group,
    COUNT(*) AS customers,
    SUM(r.retained_12m_flag) AS retained_customers,
    ROUND(AVG(r.retained_12m_flag), 4) AS retention_12m
FROM cohorts c
LEFT JOIN adoption a ON c.customer_id = a.customer_id
LEFT JOIN retention_12 r ON c.customer_id = r.customer_id
GROUP BY adoption_group
ORDER BY retention_12m DESC;
