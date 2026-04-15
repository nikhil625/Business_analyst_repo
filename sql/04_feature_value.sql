/*
04_feature_value_mysql.sql
MySQL 8+

Feature value, pricing, upgrade attribution, churn abandonment, and upsell
targeting for Jan-Apr 2025.
*/

CREATE OR REPLACE VIEW feature_usage_rollup_mysql AS
SELECT
    c.customer_id,
    c.company_name,
    c.industry,
    c.company_size,
    c.current_tier,
    c.mrr,
    c.csm_assigned,
    fl.feature_name,
    COUNT(DISTINCT CASE WHEN fu.usage_count > 0 THEN fu.usage_date END) AS active_days,
    COALESCE(SUM(CASE WHEN fu.usage_count > 0 THEN fu.usage_count ELSE 0 END), 0) AS total_usage_count,
    COALESCE(SUM(fu.session_duration_seconds), 0) AS total_session_seconds,
    MIN(CASE WHEN fu.usage_count > 0 THEN fu.usage_date END) AS first_use_date,
    MAX(CASE WHEN fu.usage_count > 0 THEN fu.usage_date END) AS last_use_date
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
GROUP BY c.customer_id, c.company_name, c.industry, c.company_size, c.current_tier, c.mrr, c.csm_assigned, fl.feature_name;

-- Feature usage by tier and paywall signal.
SELECT
    current_tier,
    feature_name,
    COUNT(DISTINCT customer_id) AS tier_customers,
    COUNT(DISTINCT CASE WHEN total_usage_count > 0 THEN customer_id END) AS feature_users,
    ROUND(COUNT(DISTINCT CASE WHEN total_usage_count > 0 THEN customer_id END) / NULLIF(COUNT(DISTINCT customer_id), 0), 4) AS feature_penetration,
    ROUND(AVG(CASE WHEN total_usage_count > 0 THEN total_usage_count END), 2) AS avg_usage_among_users,
    CASE
        WHEN current_tier = 'starter'
         AND feature_name IN ('Real-time Sync', 'Custom Transformations')
         AND COUNT(DISTINCT CASE WHEN total_usage_count > 0 THEN customer_id END) / NULLIF(COUNT(DISTINCT customer_id), 0) >= 0.20
            THEN 'Strong upsell/paywall candidate'
        WHEN current_tier = 'professional'
         AND COUNT(DISTINCT CASE WHEN total_usage_count > 0 THEN customer_id END) / NULLIF(COUNT(DISTINCT customer_id), 0) < 0.15
            THEN 'Underutilized; improve onboarding'
        ELSE 'Monitor'
    END AS pricing_signal
FROM feature_usage_rollup_mysql
GROUP BY current_tier, feature_name
ORDER BY feature_name, current_tier;

-- Upgrade attribution: features used in the 30 days before upgrade.
WITH upgrade_events AS (
    SELECT customer_id, event_date AS upgrade_date, from_tier, to_tier, mrr_change
    FROM subscription_events
    WHERE event_type = 'upgrade'
      AND event_date >= '2025-01-01'
      AND event_date < '2025-05-01'
),
upgrade_feature_window AS (
    SELECT
        ue.customer_id,
        ue.upgrade_date,
        ue.from_tier,
        ue.to_tier,
        ue.mrr_change,
        fu.feature_name,
        SUM(CASE WHEN fu.usage_count > 0 THEN fu.usage_count ELSE 0 END) AS usage_30d_before_upgrade,
        COUNT(DISTINCT CASE WHEN fu.usage_count > 0 THEN fu.usage_date END) AS active_days_30d_before_upgrade
    FROM upgrade_events ue
    LEFT JOIN feature_usage fu ON ue.customer_id = fu.customer_id
        AND fu.usage_date >= DATE_SUB(ue.upgrade_date, INTERVAL 30 DAY)
        AND fu.usage_date < ue.upgrade_date
        AND fu.feature_name IN ('API Connectors', 'Real-time Sync', 'Custom Transformations')
    GROUP BY ue.customer_id, ue.upgrade_date, ue.from_tier, ue.to_tier, ue.mrr_change, fu.feature_name
)
SELECT
    feature_name,
    COUNT(DISTINCT customer_id) AS upgraded_customers_using_feature_pre_upgrade,
    ROUND(AVG(usage_30d_before_upgrade), 2) AS avg_usage_30d_before_upgrade,
    ROUND(AVG(active_days_30d_before_upgrade), 2) AS avg_active_days_30d_before_upgrade,
    SUM(mrr_change) AS attributed_mrr_change
FROM upgrade_feature_window
WHERE feature_name IS NOT NULL
  AND usage_30d_before_upgrade > 0
GROUP BY feature_name
ORDER BY attributed_mrr_change DESC;

-- Upgrade likelihood per feature.
WITH upgrade_customers AS (
    SELECT DISTINCT customer_id
    FROM subscription_events
    WHERE event_type = 'upgrade'
      AND event_date >= '2025-01-01'
      AND event_date < '2025-05-01'
)
SELECT
    fur.feature_name,
    COUNT(DISTINCT CASE WHEN fur.total_usage_count > 0 THEN fur.customer_id END) AS feature_users,
    COUNT(DISTINCT CASE WHEN fur.total_usage_count = 0 THEN fur.customer_id END) AS non_users,
    COUNT(DISTINCT CASE WHEN fur.total_usage_count > 0 AND uc.customer_id IS NOT NULL THEN fur.customer_id END) AS upgraded_feature_users,
    COUNT(DISTINCT CASE WHEN fur.total_usage_count = 0 AND uc.customer_id IS NOT NULL THEN fur.customer_id END) AS upgraded_non_users,
    ROUND(COUNT(DISTINCT CASE WHEN fur.total_usage_count > 0 AND uc.customer_id IS NOT NULL THEN fur.customer_id END) / NULLIF(COUNT(DISTINCT CASE WHEN fur.total_usage_count > 0 THEN fur.customer_id END), 0), 4) AS upgrade_rate_users,
    ROUND(COUNT(DISTINCT CASE WHEN fur.total_usage_count = 0 AND uc.customer_id IS NOT NULL THEN fur.customer_id END) / NULLIF(COUNT(DISTINCT CASE WHEN fur.total_usage_count = 0 THEN fur.customer_id END), 0), 4) AS upgrade_rate_non_users
FROM feature_usage_rollup_mysql fur
LEFT JOIN upgrade_customers uc ON fur.customer_id = uc.customer_id
GROUP BY fur.feature_name
ORDER BY upgrade_rate_users DESC;

-- Churn risk: feature abandonment before churn.
WITH churn_events AS (
    SELECT customer_id, event_date AS churn_date
    FROM subscription_events
    WHERE event_type = 'churn'
      AND event_date >= '2025-01-01'
      AND event_date < '2025-05-01'
)
SELECT
    fur.feature_name,
    COUNT(DISTINCT ce.customer_id) AS churned_customers_with_feature_history,
    COUNT(DISTINCT CASE WHEN fur.last_use_date IS NOT NULL AND fur.last_use_date < DATE_SUB(ce.churn_date, INTERVAL 14 DAY) THEN ce.customer_id END) AS abandoned_before_churn_customers,
    ROUND(COUNT(DISTINCT CASE WHEN fur.last_use_date IS NOT NULL AND fur.last_use_date < DATE_SUB(ce.churn_date, INTERVAL 14 DAY) THEN ce.customer_id END) / NULLIF(COUNT(DISTINCT ce.customer_id), 0), 4) AS abandonment_rate_before_churn,
    ROUND(AVG(CASE WHEN fur.last_use_date IS NOT NULL THEN DATEDIFF(ce.churn_date, fur.last_use_date) END), 2) AS avg_days_between_last_use_and_churn
FROM churn_events ce
INNER JOIN feature_usage_rollup_mysql fur ON ce.customer_id = fur.customer_id
GROUP BY fur.feature_name
ORDER BY abandonment_rate_before_churn DESC;

-- Upsell campaign targets.
WITH customer_usage AS (
    SELECT
        customer_id,
        company_name,
        industry,
        company_size,
        current_tier,
        mrr,
        csm_assigned,
        SUM(total_usage_count) AS total_new_feature_usage,
        COUNT(DISTINCT CASE WHEN total_usage_count > 0 THEN feature_name END) AS new_features_used
    FROM feature_usage_rollup_mysql
    GROUP BY customer_id, company_name, industry, company_size, current_tier, mrr, csm_assigned
)
SELECT
    *,
    CASE WHEN current_tier = 'starter' AND total_new_feature_usage >= 50 AND new_features_used >= 2 THEN 1 ELSE 0 END AS bargain_hunter_flag,
    CASE
        WHEN current_tier = 'starter' AND total_new_feature_usage >= 50 AND new_features_used >= 2 AND csm_assigned = TRUE THEN 'CSM-led Professional upsell'
        WHEN current_tier = 'starter' AND total_new_feature_usage >= 50 AND new_features_used >= 2 THEN 'Automated Professional trial offer'
        WHEN current_tier = 'professional' AND new_features_used >= 2 THEN 'Enterprise expansion nurture'
        ELSE 'No immediate upsell action'
    END AS recommended_campaign
FROM customer_usage
WHERE (current_tier = 'starter' AND total_new_feature_usage >= 50 AND new_features_used >= 2)
   OR (current_tier = 'professional' AND new_features_used >= 2)
ORDER BY total_new_feature_usage DESC, mrr DESC;
