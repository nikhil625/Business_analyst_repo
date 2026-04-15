-- ============================================
-- 04_feature_value.sql (FINAL SUBMISSION)
-- ============================================


-- =========================================================
-- 1. FEATURE USAGE BY TIER (FIXED DENOMINATOR)
-- =========================================================

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
    2) AS usage_pct
FROM raw_customers c
LEFT JOIN raw_feature_usage f
    ON c.customer_id = f.customer_id
JOIN plan_size ps
    ON c.plan = ps.plan
GROUP BY c.plan, f.feature, ps.total_customers
ORDER BY c.plan, usage_pct DESC;



-- =========================================================
-- 2. STARTER USING PREMIUM FEATURES
-- =========================================================

SELECT 
    COUNT(DISTINCT f.customer_id) AS starter_using_premium,
    ROUND(
        100 * COUNT(DISTINCT f.customer_id) / 
        (SELECT COUNT(*) FROM raw_customers WHERE plan = 'starter'),
    2) AS pct_starter_premium
FROM raw_feature_usage f
JOIN raw_customers c
    ON f.customer_id = c.customer_id
WHERE c.plan = 'starter'
AND f.feature IN ('ai_insights','automation','reporting','team_collab');



-- =========================================================
-- 3. UPGRADE ATTRIBUTION (LAST 30 DAYS)
-- =========================================================

WITH upgrades AS (
    SELECT 
        customer_id,
        STR_TO_DATE(event_date,'%Y-%m-%d') AS upgrade_date
    FROM raw_subscription_events
    WHERE event_type = 'plan_upgrade'
),

pre_usage AS (
    SELECT DISTINCT
        u.customer_id,
        f.feature
    FROM upgrades u
    JOIN raw_feature_usage f
        ON u.customer_id = f.customer_id
    WHERE STR_TO_DATE(f.session_date,'%Y-%m-%d')
          BETWEEN DATE_SUB(u.upgrade_date, INTERVAL 30 DAY)
          AND u.upgrade_date
)

SELECT 
    feature,
    COUNT(DISTINCT customer_id) AS users_before_upgrade
FROM pre_usage
GROUP BY feature
ORDER BY users_before_upgrade DESC;



-- =========================================================
-- 4. UPGRADE LIKELIHOOD (FEATURE IMPACT)
-- =========================================================

WITH feature_users AS (
    SELECT DISTINCT customer_id, feature
    FROM raw_feature_usage
),

upgraded AS (
    SELECT DISTINCT customer_id
    FROM raw_subscription_events
    WHERE event_type = 'plan_upgrade'
)

SELECT 
    f.feature,
    COUNT(DISTINCT f.customer_id) AS users,
    COUNT(DISTINCT u.customer_id) AS upgraded_users,
    ROUND(
        100 * COUNT(DISTINCT u.customer_id) / 
        COUNT(DISTINCT f.customer_id),
    2) AS upgrade_likelihood_pct
FROM feature_users f
LEFT JOIN upgraded u
    ON f.customer_id = u.customer_id
GROUP BY f.feature
ORDER BY upgrade_likelihood_pct DESC;



-- =========================================================
-- 5. CHURN FEATURE USAGE (LAST 30 DAYS BEFORE CHURN)
-- =========================================================

WITH churned AS (
    SELECT 
        customer_id,
        STR_TO_DATE(event_date,'%Y-%m-%d') AS churn_date
    FROM raw_subscription_events
    WHERE event_type = 'subscription_cancel'
),

pre_churn_usage AS (
    SELECT DISTINCT
        c.customer_id,
        f.feature
    FROM churned c
    LEFT JOIN raw_feature_usage f
        ON c.customer_id = f.customer_id
    WHERE STR_TO_DATE(f.session_date,'%Y-%m-%d')
          BETWEEN DATE_SUB(c.churn_date, INTERVAL 30 DAY)
          AND c.churn_date
)

SELECT 
    feature,
    COUNT(DISTINCT customer_id) AS churn_users
FROM pre_churn_usage
GROUP BY feature
ORDER BY churn_users DESC;



-- =========================================================
-- 6. FEATURE ABANDONMENT BEFORE CHURN
-- =========================================================

WITH last_usage AS (
    SELECT 
        customer_id,
        feature,
        MAX(STR_TO_DATE(session_date,'%Y-%m-%d')) AS last_used
    FROM raw_feature_usage
    GROUP BY customer_id, feature
),

churned AS (
    SELECT 
        customer_id,
        STR_TO_DATE(event_date,'%Y-%m-%d') AS churn_date
    FROM raw_subscription_events
    WHERE event_type = 'subscription_cancel'
)

SELECT 
    l.feature,
    COUNT(*) AS abandoned_users
FROM last_usage l
JOIN churned c
    ON l.customer_id = c.customer_id
WHERE l.last_used < DATE_SUB(c.churn_date, INTERVAL 30 DAY)
GROUP BY l.feature
ORDER BY abandoned_users DESC;



-- =========================================================
-- 7. WILLINGNESS TO PAY (BETTER SEGMENTATION)
-- =========================================================

WITH usage_intensity AS (
    SELECT 
        customer_id,
        COUNT(*) AS total_usage
    FROM raw_feature_usage
    GROUP BY customer_id
)

SELECT 
    c.plan,
    CASE 
        WHEN u.total_usage > 100 THEN 'High Usage'
        WHEN u.total_usage > 50 THEN 'Medium Usage'
        ELSE 'Low Usage'
    END AS usage_segment,
    ROUND(AVG(c.mrr),2) AS avg_mrr,
    COUNT(*) AS customers
FROM raw_customers c
JOIN usage_intensity u
    ON c.customer_id = u.customer_id
GROUP BY c.plan, usage_segment
ORDER BY c.plan;



-- =========================================================
-- 8. BARGAIN HUNTERS (LOW PLAN, HIGH USAGE)
-- =========================================================

WITH usage_intensity AS (
    SELECT 
        customer_id,
        COUNT(*) AS total_usage
    FROM raw_feature_usage
    GROUP BY customer_id
)

SELECT 
    c.customer_id,
    c.plan,
    c.mrr,
    u.total_usage
FROM raw_customers c
JOIN usage_intensity u
    ON c.customer_id = u.customer_id
WHERE c.plan = 'starter'
AND u.total_usage > 50   -- lowered threshold for visibility
ORDER BY u.total_usage DESC;
