WITH base_usage AS (
    SELECT *
    FROM feature_usage
    WHERE session_date BETWEEN '2024-01-01' AND '2024-04-30'
      AND duration_seconds > 0
),

-- Total customers
total_customers AS (
    SELECT COUNT(DISTINCT customer_id) AS total FROM customer
),

-- 1. Adoption Rate
adoption AS (
    SELECT 
        feature,
        COUNT(DISTINCT customer_id) AS users,
        COUNT(DISTINCT customer_id) * 1.0 / t.total AS adoption_rate
    FROM base_usage, total_customers t
    GROUP BY feature, t.total
),

-- 2. DAU
dau AS (
    SELECT 
        feature,
        DATE(session_date) AS day,
        COUNT(DISTINCT customer_id) AS dau
    FROM base_usage
    GROUP BY feature, DATE(session_date)
),

-- Avg DAU per month
avg_dau AS (
    SELECT 
        feature,
        DATE_TRUNC('month', day) AS month,
        AVG(dau) AS avg_dau
    FROM dau
    GROUP BY feature, DATE_TRUNC('month', day)
),

-- MAU
mau AS (
    SELECT 
        feature,
        DATE_TRUNC('month', session_date) AS month,
        COUNT(DISTINCT customer_id) AS mau
    FROM base_usage
    GROUP BY feature, DATE_TRUNC('month', session_date)
),

-- Stickiness
stickiness AS (
    SELECT 
        a.feature,
        a.month,
        a.avg_dau,
        m.mau,
        a.avg_dau * 1.0 / m.mau AS dau_mau_ratio
    FROM avg_dau a
    JOIN mau m 
      ON a.feature = m.feature AND a.month = m.month
),

-- 3. Feature Release (proxy)
feature_release AS (
    SELECT 
        feature,
        MIN(DATE(session_date)) AS release_date
    FROM base_usage
    GROUP BY feature
),

-- First use
first_use AS (
    SELECT 
        feature,
        customer_id,
        MIN(DATE(session_date)) AS first_use_date
    FROM base_usage
    GROUP BY feature, customer_id
),

-- Time to first use
time_to_first_use AS (
    SELECT 
        f.feature,
        AVG(DATE_PART('day', f.first_use_date - r.release_date)) AS avg_days_to_first_use
    FROM first_use f
    JOIN feature_release r ON f.feature = r.feature
    GROUP BY f.feature
),

-- 4. Power Users
usage_days AS (
    SELECT 
        feature,
        customer_id,
        DATE_TRUNC('month', session_date) AS month,
        COUNT(DISTINCT DATE(session_date)) AS active_days
    FROM base_usage
    GROUP BY feature, customer_id, DATE_TRUNC('month', session_date)
),

power_users AS (
    SELECT 
        feature,
        COUNT(*) AS power_users
    FROM usage_days
    WHERE active_days >= 10
    GROUP BY feature
),

-- 5. Activation Rate
activation AS (
    SELECT 
        f.feature,
        COUNT(*) FILTER (
            WHERE DATE_PART('day', f.first_use_date - r.release_date) <= 7
        ) * 1.0 / COUNT(*) AS activation_rate
    FROM first_use f
    JOIN feature_release r ON f.feature = r.feature
    GROUP BY f.feature
)

-- FINAL OUTPUT
SELECT 
    a.feature,
    a.adoption_rate,
    s.avg_dau / NULLIF(s.mau, 0) AS dau_mau_ratio,
    t.avg_days_to_first_use,
    p.power_users,
    act.activation_rate
FROM adoption a
LEFT JOIN (
    SELECT feature, AVG(avg_dau) AS avg_dau, AVG(mau) AS mau
    FROM stickiness
    GROUP BY feature
) s ON a.feature = s.feature
LEFT JOIN time_to_first_use t ON a.feature = t.feature
LEFT JOIN power_users p ON a.feature = p.feature
LEFT JOIN activation act ON a.feature = act.feature
ORDER BY dau_mau_ratio DESC;