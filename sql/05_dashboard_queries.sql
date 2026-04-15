/*
05_dashboard_queries_mysql.sql
MySQL 8+

Executive dashboard datasets.
Run 02_health_score_mysql.sql first if you want the reusable
customer_health_scores view available.
*/

-- Executive KPI cards.
SELECT
    COUNT(*) AS total_customers,
    SUM(CASE WHEN churned_currently_flag = 0 THEN 1 ELSE 0 END) AS active_customers,
    ROUND(AVG(CASE WHEN new_features_adopted >= 1 THEN 1 ELSE 0 END), 4) AS overall_new_feature_adoption_rate,
    ROUND(AVG(CASE WHEN new_features_adopted >= 2 THEN 1 ELSE 0 END), 4) AS customers_using_2_plus_new_features_rate,
    SUM(mrr) AS current_mrr,
    SUM(mrr) * 12 AS estimated_arr,
    SUM(total_mrr_change) AS jan_apr_net_mrr_change,
    ROUND(AVG(health_score), 2) AS avg_health_score,
    ROUND(AVG(churned_currently_flag), 4) AS churn_rate
FROM customer_health_scores;

-- Feature penetration by tier.
SELECT
    c.current_tier,
    fl.feature_name,
    COUNT(DISTINCT c.customer_id) AS customers_in_tier,
    COUNT(DISTINCT CASE WHEN fu.usage_count > 0 THEN c.customer_id END) AS feature_users,
    ROUND(COUNT(DISTINCT CASE WHEN fu.usage_count > 0 THEN c.customer_id END) / NULLIF(COUNT(DISTINCT c.customer_id), 0), 4) AS feature_penetration
FROM customers c
CROSS JOIN (
    SELECT 'API Connectors' AS feature_name
    UNION ALL SELECT 'Real-time Sync'
    UNION ALL SELECT 'Custom Transformations'
) fl
LEFT JOIN feature_usage fu ON c.customer_id = fu.customer_id
    AND fl.feature_name = fu.feature_name
    AND fu.usage_date >= '2025-01-01'
    AND fu.usage_date < '2025-05-01'
GROUP BY c.current_tier, fl.feature_name
ORDER BY fl.feature_name, c.current_tier;

-- Customer health distribution.
SELECT
    health_segment,
    COUNT(*) AS customers,
    ROUND(COUNT(*) / (SELECT COUNT(*) FROM customer_health_scores), 4) AS customer_share,
    ROUND(AVG(mrr), 2) AS avg_mrr,
    SUM(mrr) AS segment_mrr,
    ROUND(AVG(churned_currently_flag), 4) AS churn_rate
FROM customer_health_scores
GROUP BY health_segment
ORDER BY MIN(health_score);

-- Top 100 churn-risk customers.
SELECT
    customer_id,
    company_name,
    industry,
    company_size,
    current_tier,
    mrr,
    csm_assigned,
    new_features_adopted,
    weighted_usage,
    active_usage_days,
    ticket_count,
    avg_sentiment_score,
    health_score,
    health_segment,
    CASE
        WHEN csm_assigned = TRUE THEN 'CSM outreach within 7 days'
        WHEN current_tier = 'starter' THEN 'Automated rescue/onboarding campaign'
        ELSE 'Support-led product education'
    END AS recommended_action
FROM customer_health_scores
WHERE churned_currently_flag = 0
ORDER BY health_score ASC, mrr DESC
LIMIT 100;

-- Revenue impact of new feature adoption, correlational.
SELECT
    new_features_adopted,
    COUNT(*) AS customers,
    ROUND(AVG(mrr), 2) AS avg_mrr,
    SUM(mrr) AS total_mrr,
    ROUND(AVG(total_mrr_change), 2) AS avg_net_mrr_change_jan_apr,
    ROUND(AVG(CASE WHEN upgrade_count > 0 THEN 1 ELSE 0 END), 4) AS upgrade_rate,
    ROUND(AVG(churned_currently_flag), 4) AS churn_rate
FROM customer_health_scores
GROUP BY new_features_adopted
ORDER BY new_features_adopted;

-- Estimated ARR impact of improving API Connectors adoption by 10 percentage points.
WITH api_adoption AS (
    SELECT
        c.customer_id,
        c.mrr,
        CASE WHEN SUM(CASE WHEN fu.usage_count > 0 THEN fu.usage_count ELSE 0 END) > 0 THEN 1 ELSE 0 END AS adopted_api
    FROM customers c
    LEFT JOIN feature_usage fu ON c.customer_id = fu.customer_id
        AND fu.feature_name = 'API Connectors'
        AND fu.usage_date >= '2025-01-01'
        AND fu.usage_date < '2025-05-01'
    GROUP BY c.customer_id, c.mrr
),
adoption_summary AS (
    SELECT
        COUNT(*) AS total_customers,
        SUM(adopted_api) AS current_api_adopters,
        ROUND(AVG(CASE WHEN adopted_api = 1 THEN mrr END), 2) AS avg_mrr_api_adopters,
        ROUND(AVG(CASE WHEN adopted_api = 0 THEN mrr END), 2) AS avg_mrr_non_adopters
    FROM api_adoption
)
SELECT
    total_customers,
    current_api_adopters,
    CEIL(total_customers * 0.10) AS incremental_adopters_from_10pp_lift,
    avg_mrr_api_adopters,
    avg_mrr_non_adopters,
    ROUND((avg_mrr_api_adopters - avg_mrr_non_adopters) * CEIL(total_customers * 0.10) * 12, 2) AS estimated_incremental_arr_correlation
FROM adoption_summary;
