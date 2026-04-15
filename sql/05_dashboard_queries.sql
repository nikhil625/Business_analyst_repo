-- ============================================
-- 05_dashboard_queries.sql 
-- ============================================


-- =========================================================
-- CREATE CUSTOMER HEALTH SCORES
-- =========================================================
DROP TABLE IF EXISTS customer_health_scores;

CREATE TABLE customer_health_scores AS
WITH feature_usage_score AS (
    SELECT customer_id, LEAST(30, COUNT(*) * 0.2) AS feature_score
    FROM raw_feature_usage
    GROUP BY customer_id
),
login_score AS (
    SELECT customer_id, LEAST(20, SUM(duration_seconds)/5000) AS login_score
    FROM raw_feature_usage
    GROUP BY customer_id
),
support_score AS (
    SELECT 
        customer_id,
        GREATEST(5,
            20 - COUNT(*) * 0.5 +
            AVG(CASE 
                WHEN sentiment = 'positive' THEN 2
                WHEN sentiment = 'neutral' THEN 0
                ELSE -2
            END)
        ) AS support_score
    FROM raw_support_tickets
    GROUP BY customer_id
),
payment_score AS (
    SELECT 
        customer_id,
        CASE 
            WHEN SUM(CASE WHEN event_type = 'subscription_cancel' THEN 1 ELSE 0 END) > 0 THEN 0
            ELSE 15
        END AS payment_score
    FROM raw_subscription_events
    GROUP BY customer_id
),
new_feature_score AS (
    SELECT 
        customer_id,
        LEAST(15, COUNT(DISTINCT feature) * 5) AS new_feature_score
    FROM raw_feature_usage
    WHERE feature IN ('ai_insights','automation','dashboard','reporting')
    GROUP BY customer_id
),
combined AS (
    SELECT 
        c.customer_id,
        COALESCE(f.feature_score,0) +
        COALESCE(l.login_score,0) +
        COALESCE(s.support_score,0) +
        COALESCE(p.payment_score,0) +
        COALESCE(n.new_feature_score,0) AS raw_score
    FROM raw_customers c
    LEFT JOIN feature_usage_score f ON c.customer_id = f.customer_id
    LEFT JOIN login_score l ON c.customer_id = l.customer_id
    LEFT JOIN support_score s ON c.customer_id = s.customer_id
    LEFT JOIN payment_score p ON c.customer_id = p.customer_id
    LEFT JOIN new_feature_score n ON c.customer_id = n.customer_id
)
SELECT 
    customer_id,
    ROUND((raw_score/80)*100,2) AS health_score,
    CASE 
        WHEN (raw_score/80)*100 <= 40 THEN 'At Risk'
        WHEN (raw_score/80)*100 <= 65 THEN 'Needs Attention'
        WHEN (raw_score/80)*100 <= 85 THEN 'Healthy'
        ELSE 'Champions'
    END AS health_tier
FROM combined;



-- =========================================================
-- DASHBOARD
-- =========================================================

-- 1. ADOPTION RATE
SELECT 
    COUNT(DISTINCT customer_id) AS active_customers,
    (SELECT COUNT(*) FROM raw_customers) AS total_customers,
    ROUND(
        100 * COUNT(DISTINCT customer_id) / 
        (SELECT COUNT(*) FROM raw_customers),
    2) AS adoption_rate_pct
FROM raw_feature_usage;



-- 2. FEATURE PENETRATION
WITH plan_size AS (
    SELECT plan, COUNT(*) AS total_customers
    FROM raw_customers
    GROUP BY plan
)
SELECT 
    c.plan,
    f.feature,
    COUNT(DISTINCT f.customer_id) AS users,
    ROUND(
        100 * COUNT(DISTINCT f.customer_id) / ps.total_customers,
    2) AS penetration_pct
FROM raw_customers c
LEFT JOIN raw_feature_usage f
    ON c.customer_id = f.customer_id
JOIN plan_size ps
    ON c.plan = ps.plan
GROUP BY c.plan, f.feature, ps.total_customers
ORDER BY c.plan, penetration_pct DESC;



-- 3. CUSTOMER HEALTH DISTRIBUTION
SELECT 
    health_tier,
    COUNT(*) AS customers
FROM customer_health_scores
GROUP BY health_tier;



-- 4. TOP 100 CHURN RISK CUSTOMERS
SELECT 
    customer_id,
    health_score,
    health_tier
FROM customer_health_scores
WHERE health_tier = 'At Risk'
ORDER BY health_score ASC
LIMIT 100;



-- 5. REVENUE IMPACT OF FEATURE USAGE
SELECT 
    feature_bucket,
    COUNT(*) AS customers,
    ROUND(AVG(mrr),2) AS avg_mrr
FROM (
    SELECT 
        c.customer_id,
        c.mrr,
        CASE 
            WHEN COUNT(DISTINCT f.feature) >= 5 THEN 'High Feature Usage'
            WHEN COUNT(DISTINCT f.feature) >= 3 THEN 'Medium Feature Usage'
            ELSE 'Low Feature Usage'
        END AS feature_bucket
    FROM raw_customers c
    LEFT JOIN raw_feature_usage f
        ON c.customer_id = f.customer_id
    GROUP BY c.customer_id, c.mrr
) t
GROUP BY feature_bucket;



-- =========================================================
-- KPI SECTION
-- =========================================================

-- KPI 1: MULTI-FEATURE ADOPTION
SELECT 
    ROUND(
        100 * COUNT(DISTINCT customer_id) / 
        (SELECT COUNT(*) FROM raw_customers),
    2) AS pct_multi_feature_users
FROM (
    SELECT customer_id
    FROM raw_feature_usage
    GROUP BY customer_id
    HAVING COUNT(DISTINCT feature) >= 2
) t;



-- KPI 2: WAU / MAU 
WITH weekly_active AS (
    SELECT 
        YEARWEEK(STR_TO_DATE(session_date,'%Y-%m-%d')) AS week,
        COUNT(DISTINCT customer_id) AS wau
    FROM raw_feature_usage
    WHERE STR_TO_DATE(session_date,'%Y-%m-%d') 
          BETWEEN '2024-04-01' AND '2024-04-30'
    GROUP BY YEARWEEK(STR_TO_DATE(session_date,'%Y-%m-%d'))
),
monthly_active AS (
    SELECT COUNT(DISTINCT customer_id) AS mau
    FROM raw_feature_usage
    WHERE STR_TO_DATE(session_date,'%Y-%m-%d') 
          BETWEEN '2024-04-01' AND '2024-04-30'
)
SELECT 
    ROUND(AVG(wau) / (SELECT mau FROM monthly_active), 4) AS dau_mau_ratio
FROM weekly_active;



-- KPI 3: FEATURE → UPGRADE CONVERSION
SELECT 
    f.feature,
    ROUND(
        100 * COUNT(DISTINCT CASE WHEN s.event_type='plan_upgrade' THEN f.customer_id END)
        / COUNT(DISTINCT f.customer_id),
    2) AS upgrade_conversion_pct
FROM raw_feature_usage f
LEFT JOIN raw_subscription_events s
    ON f.customer_id = s.customer_id
GROUP BY f.feature;



-- KPI 4: AVG CUSTOMER HEALTH SCORE
SELECT 
    ROUND(AVG(health_score),2) AS avg_health_score
FROM customer_health_scores;



-- KPI 5: FEATURE USAGE vs MRR
SELECT 
    COUNT(DISTINCT f.feature) AS features_used,
    ROUND(AVG(c.mrr),2) AS avg_mrr
FROM raw_customers c
JOIN raw_feature_usage f
    ON c.customer_id = f.customer_id
GROUP BY c.customer_id;
