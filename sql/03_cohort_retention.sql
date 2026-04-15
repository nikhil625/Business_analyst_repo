-- ============================================
-- 03_cohort_retention.sql 
-- ============================================


-- =========================================================
-- 1. COHORT RETENTION (Month 0–3) as data is from 2024
-- =========================================================

WITH cohorts AS (
    SELECT 
        customer_id,
        STR_TO_DATE(signup_date, '%Y-%m-%d') AS signup_date,
        DATE_FORMAT(STR_TO_DATE(signup_date, '%Y-%m-%d'), '%Y-%m-01') AS cohort_month
    FROM raw_customers
    WHERE STR_TO_DATE(signup_date, '%Y-%m-%d') 
          BETWEEN '2024-01-01' AND '2024-06-30'
),

activity AS (
    SELECT 
        customer_id,
        STR_TO_DATE(session_date, '%Y-%m-%d') AS session_date
    FROM raw_feature_usage
),

cohort_activity AS (
    SELECT 
        c.cohort_month,
        c.customer_id,
        TIMESTAMPDIFF(MONTH, c.signup_date, a.session_date) AS month_number
    FROM cohorts c
    JOIN activity a
        ON c.customer_id = a.customer_id
),

cohort_size AS (
    SELECT 
        cohort_month,
        COUNT(*) AS total_users
    FROM cohorts
    GROUP BY cohort_month
)

SELECT 
    ca.cohort_month,
    ROUND(100 * COUNT(DISTINCT CASE WHEN month_number = 0 THEN customer_id END)/cs.total_users,2) AS M0,
    ROUND(100 * COUNT(DISTINCT CASE WHEN month_number = 1 THEN customer_id END)/cs.total_users,2) AS M1,
    ROUND(100 * COUNT(DISTINCT CASE WHEN month_number = 2 THEN customer_id END)/cs.total_users,2) AS M2,
    ROUND(100 * COUNT(DISTINCT CASE WHEN month_number = 3 THEN customer_id END)/cs.total_users,2) AS M3
FROM cohort_activity ca
JOIN cohort_size cs
ON ca.cohort_month = cs.cohort_month
GROUP BY ca.cohort_month, cs.total_users
ORDER BY ca.cohort_month;



-- =========================================================
-- 2. NET REVENUE RETENTION (NRR at Month 3)
-- =========================================================
WITH cohorts AS (
    SELECT 
        customer_id,
        STR_TO_DATE(signup_date, '%Y-%m-%d') AS signup_date,
        DATE_FORMAT(STR_TO_DATE(signup_date, '%Y-%m-%d'), '%Y-%m-01') AS cohort_month
    FROM raw_customers
    WHERE STR_TO_DATE(signup_date, '%Y-%m-%d') 
          BETWEEN '2024-01-01' AND '2024-06-30'
),

revenue_events AS (
    SELECT 
        c.customer_id,
        c.cohort_month,
        TIMESTAMPDIFF(
            MONTH,
            c.signup_date,
            STR_TO_DATE(r.event_date,'%Y-%m-%d')
        ) AS month_number,
        r.mrr_at_event,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_id, 
                         TIMESTAMPDIFF(MONTH, c.signup_date, STR_TO_DATE(r.event_date,'%Y-%m-%d'))
            ORDER BY STR_TO_DATE(r.event_date,'%Y-%m-%d') DESC
        ) AS rn
    FROM cohorts c
    JOIN raw_subscription_events r
        ON c.customer_id = r.customer_id
),

clean_revenue AS (
    SELECT 
        customer_id,
        cohort_month,
        month_number,
        mrr_at_event
    FROM revenue_events
    WHERE rn = 1
),

pivot AS (
    SELECT 
        customer_id,
        cohort_month,
        MAX(CASE WHEN month_number = 0 THEN mrr_at_event END) AS m0,
        MAX(CASE WHEN month_number = 3 THEN mrr_at_event END) AS m3
    FROM clean_revenue
    GROUP BY customer_id, cohort_month
),

valid_customers AS (
    SELECT *
    FROM pivot
    WHERE m0 IS NOT NULL AND m3 IS NOT NULL
)

SELECT 
    cohort_month,
    ROUND(100 * SUM(m3) / SUM(m0), 2) AS NRR_pct
FROM valid_customers
GROUP BY cohort_month
ORDER BY cohort_month;
-- =========================================================
-- 3. EARLY vs LATE COHORT (FEATURE IMPACT)
-- =========================================================

SELECT 
    CASE 
        WHEN STR_TO_DATE(signup_date,'%Y-%m-%d') < '2024-03-01' THEN 'Early Cohort'
        ELSE 'Late Cohort'
    END AS cohort_type,
    COUNT(*) AS users
FROM raw_customers
GROUP BY cohort_type;



-- =========================================================
-- 4. HYPOTHESIS TEST
-- "2+ features in 30 days → higher retention"
-- Using Month 3 retention proxy
-- =========================================================

WITH signup AS (
    SELECT 
        customer_id,
        STR_TO_DATE(signup_date, '%Y-%m-%d') AS signup_date
    FROM raw_customers
),

early_usage AS (
    SELECT 
        f.customer_id,
        COUNT(DISTINCT f.feature) AS features_used
    FROM raw_feature_usage f
    JOIN signup s
        ON f.customer_id = s.customer_id
    WHERE STR_TO_DATE(f.session_date, '%Y-%m-%d') 
          BETWEEN s.signup_date 
          AND DATE_ADD(s.signup_date, INTERVAL 30 DAY)
    GROUP BY f.customer_id
),

month3_activity AS (
    SELECT 
        s.customer_id,
        MAX(CASE 
            WHEN STR_TO_DATE(f.session_date, '%Y-%m-%d') 
                 BETWEEN DATE_ADD(s.signup_date, INTERVAL 60 DAY)
                 AND DATE_ADD(s.signup_date, INTERVAL 90 DAY)
            THEN 1 ELSE 0 END) AS retained_m3
    FROM signup s
    LEFT JOIN raw_feature_usage f
        ON s.customer_id = f.customer_id
    GROUP BY s.customer_id
)

SELECT 
    CASE 
        WHEN e.features_used >= 2 THEN 'High Adoption'
        ELSE 'Low Adoption'
    END AS segment,
    COUNT(*) AS users,
    SUM(m.retained_m3) AS retained_users,
    ROUND(100 * SUM(m.retained_m3)/COUNT(*),2) AS retention_pct
FROM early_usage e
JOIN month3_activity m
ON e.customer_id = m.customer_id
GROUP BY segment;
