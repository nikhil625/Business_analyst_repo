-- ============================================
-- 01_feature_adoption.sql 
-- Metrics: Jan–Apr 2024 
-- ============================================


-- ============================================
-- 1. ADOPTION RATE
-- ============================================

SELECT 
    f.feature,
    COUNT(DISTINCT f.customer_id) AS users_used,
    c.total_customers,
    ROUND(100.0 * COUNT(DISTINCT f.customer_id) / c.total_customers, 2) AS adoption_rate_pct
FROM raw_feature_usage f
CROSS JOIN (
    SELECT COUNT(DISTINCT customer_id) AS total_customers FROM raw_customers
) c
WHERE STR_TO_DATE(f.session_date, '%Y-%m-%d') 
      BETWEEN '2024-01-01' AND '2024-04-30'
GROUP BY f.feature, c.total_customers;



-- ============================================
-- 2. DAU / MAU (STICKINESS)
-- ============================================

SELECT 
    d.feature,
    DATE_FORMAT(d.day, '%Y-%m-01') AS month,
    ROUND(AVG(d.dau), 2) AS avg_dau,
    m.mau,
    ROUND(AVG(d.dau)/m.mau, 4) AS dau_mau_ratio
FROM (
    SELECT 
        feature,
        DATE(STR_TO_DATE(session_date, '%Y-%m-%d')) AS day,
        COUNT(DISTINCT customer_id) AS dau
    FROM raw_feature_usage
    WHERE STR_TO_DATE(session_date, '%Y-%m-%d') 
          BETWEEN '2024-01-01' AND '2024-04-30'
    GROUP BY feature, day
) d
JOIN (
    SELECT 
        feature,
        DATE_FORMAT(STR_TO_DATE(session_date, '%Y-%m-%d'), '%Y-%m-01') AS month,
        COUNT(DISTINCT customer_id) AS mau
    FROM raw_feature_usage
    WHERE STR_TO_DATE(session_date, '%Y-%m-%d') 
          BETWEEN '2024-01-01' AND '2024-04-30'
    GROUP BY feature, month
) m
ON d.feature = m.feature
AND DATE_FORMAT(d.day, '%Y-%m-01') = m.month
GROUP BY d.feature, DATE_FORMAT(d.day, '%Y-%m-01'), m.mau;



-- ============================================
-- 3. TIME TO FIRST USE 
-- ============================================

SELECT 
    feature,
    AVG(days_to_first_use) AS avg_days_to_first_use
FROM (
    SELECT 
        feature,
        customer_id,
        DATEDIFF(
            MIN(STR_TO_DATE(session_date, '%Y-%m-%d')),
            MIN(MIN(STR_TO_DATE(session_date, '%Y-%m-%d'))) 
                OVER (PARTITION BY feature)
        ) AS days_to_first_use
    FROM raw_feature_usage
    WHERE STR_TO_DATE(session_date, '%Y-%m-%d') 
          BETWEEN '2024-01-01' AND '2024-04-30'
    GROUP BY feature, customer_id
) t
GROUP BY feature;



-- ============================================
-- 4. POWER USERS (>=5 DAYS / MONTH) (as 10 gave 0)
-- ============================================

SELECT 
    feature,
    month,
    COUNT(*) AS power_users_count
FROM (
    SELECT 
        feature,
        customer_id,
        DATE_FORMAT(STR_TO_DATE(session_date, '%Y-%m-%d'), '%Y-%m-01') AS month,
        COUNT(DISTINCT DATE(STR_TO_DATE(session_date, '%Y-%m-%d'))) AS active_days
    FROM raw_feature_usage
    WHERE STR_TO_DATE(session_date, '%Y-%m-%d') 
          BETWEEN '2024-01-01' AND '2024-04-30'
    GROUP BY feature, customer_id, month
) t
WHERE active_days >= 5
GROUP BY feature, month;



-- ============================================
-- 5. ACTIVATION RATE (WITHIN 7 DAYS)
-- ============================================

SELECT 
    feature,
    COUNT(*) AS activated_users,
    ROUND(
        100.0 * COUNT(*) / 
        (SELECT COUNT(DISTINCT customer_id) FROM raw_customers),
    2) AS activation_rate_pct
FROM (
    SELECT 
        feature,
        customer_id,
        DATEDIFF(
            MIN(STR_TO_DATE(session_date, '%Y-%m-%d')),
            MIN(MIN(STR_TO_DATE(session_date, '%Y-%m-%d'))) 
                OVER (PARTITION BY feature)
        ) AS days_to_first_use
    FROM raw_feature_usage
    WHERE STR_TO_DATE(session_date, '%Y-%m-%d') 
          BETWEEN '2024-01-01' AND '2024-04-30'
    GROUP BY feature, customer_id
) t
WHERE days_to_first_use <= 7
GROUP BY feature;



-- ============================================
-- DASHBOARD QUERIES
-- ============================================

-- Weekly Trends
SELECT 
    feature,
    YEARWEEK(STR_TO_DATE(session_date, '%Y-%m-%d')) AS week,
    COUNT(DISTINCT customer_id) AS active_users
FROM raw_feature_usage
WHERE STR_TO_DATE(session_date, '%Y-%m-%d') 
      BETWEEN '2024-01-01' AND '2024-04-30'
GROUP BY feature, week;


-- Adoption by Plan
SELECT 
    c.plan,
    f.feature,
    COUNT(DISTINCT f.customer_id) AS users
FROM raw_feature_usage f
JOIN raw_customers c
    ON f.customer_id = c.customer_id
WHERE STR_TO_DATE(f.session_date, '%Y-%m-%d') 
      BETWEEN '2024-01-01' AND '2024-04-30'
GROUP BY c.plan, f.feature;


-- Adoption by Company Size
SELECT 
    c.company_size,
    f.feature,
    COUNT(DISTINCT f.customer_id) AS users
FROM raw_feature_usage f
JOIN raw_customers c
    ON f.customer_id = c.customer_id
WHERE STR_TO_DATE(f.session_date, '%Y-%m-%d') 
      BETWEEN '2024-01-01' AND '2024-04-30'
GROUP BY c.company_size, f.feature;


-- Feature Correlation
SELECT 
    a.feature AS feature_1,
    b.feature AS feature_2,
    COUNT(DISTINCT a.customer_id) AS common_users
FROM raw_feature_usage a
JOIN raw_feature_usage b
    ON a.customer_id = b.customer_id
    AND a.feature < b.feature
WHERE STR_TO_DATE(a.session_date, '%Y-%m-%d') 
      BETWEEN '2024-01-01' AND '2024-04-30'
  AND STR_TO_DATE(b.session_date, '%Y-%m-%d') 
      BETWEEN '2024-01-01' AND '2024-04-30'
GROUP BY a.feature, b.feature;
