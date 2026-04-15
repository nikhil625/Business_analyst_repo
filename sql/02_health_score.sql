-- ============================================
-- 02_health_score.sql 
-- ============================================


WITH feature_usage_score AS (
    SELECT 
        customer_id,
        LEAST(30, COUNT(*) * 0.2) AS feature_score
    FROM raw_feature_usage
    WHERE STR_TO_DATE(session_date, '%Y-%m-%d') 
          BETWEEN '2024-01-01' AND '2024-04-30'
    GROUP BY customer_id
),

login_score AS (
    SELECT 
        customer_id,
        LEAST(20, SUM(duration_seconds)/5000) AS login_score
    FROM raw_feature_usage
    WHERE STR_TO_DATE(session_date, '%Y-%m-%d') 
          BETWEEN '2024-01-01' AND '2024-04-30'
    GROUP BY customer_id
),

support_score AS (
    SELECT 
        customer_id,
        GREATEST(5, 
            20 
            - COUNT(*) * 0.5
            + AVG(CASE 
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
            WHEN SUM(CASE WHEN event_type = 'churn' THEN 1 ELSE 0 END) > 0 THEN 0
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
    WHERE feature IN ('ai_insights', 'automation', 'dashboard', 'reporting')
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
