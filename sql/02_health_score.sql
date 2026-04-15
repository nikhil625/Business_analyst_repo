/*
02_health_score_mysql.sql
MySQL 8+

Explainable customer health score, 0-100.
*/

CREATE OR REPLACE VIEW customer_health_scores AS
WITH usage_rollup AS (
    SELECT
        c.customer_id,
        COALESCE(SUM(CASE
            WHEN fu.usage_count > 0 AND fu.feature_name = 'API Connectors' THEN fu.usage_count * 1.00
            WHEN fu.usage_count > 0 AND fu.feature_name = 'Real-time Sync' THEN fu.usage_count * 1.25
            WHEN fu.usage_count > 0 AND fu.feature_name = 'Custom Transformations' THEN fu.usage_count * 1.15
            ELSE 0
        END), 0) AS weighted_usage,
        COUNT(DISTINCT CASE WHEN fu.usage_count > 0 THEN fu.usage_date END) AS active_usage_days,
        COALESCE(SUM(fu.session_duration_seconds), 0) AS total_session_seconds,
        COUNT(DISTINCT CASE WHEN fu.usage_count > 0 THEN fu.feature_name END) AS new_features_adopted
    FROM customers c
    LEFT JOIN feature_usage fu ON c.customer_id = fu.customer_id
        AND fu.feature_name IN ('API Connectors', 'Real-time Sync', 'Custom Transformations')
        AND fu.usage_date >= '2025-01-01'
        AND fu.usage_date < '2025-05-01'
    GROUP BY c.customer_id
),
support_rollup AS (
    SELECT
        c.customer_id,
        COUNT(st.ticket_id) AS ticket_count,
        COALESCE(AVG(st.sentiment_score), 0) AS avg_sentiment_score,
        COALESCE(AVG(st.resolution_time_hours), 0) AS avg_resolution_hours,
        SUM(CASE WHEN st.category IN ('technical', 'performance') THEN 1 ELSE 0 END) AS bug_ticket_count
    FROM customers c
    LEFT JOIN support_tickets st ON c.customer_id = st.customer_id
        AND st.created_date >= '2025-01-01'
        AND st.created_date < '2025-05-01'
    GROUP BY c.customer_id
),
subscription_rollup AS (
    SELECT
        c.customer_id,
        SUM(CASE WHEN se.event_type = 'renewal' THEN 1 ELSE 0 END) AS renewal_count,
        SUM(CASE WHEN se.event_type = 'upgrade' THEN 1 ELSE 0 END) AS upgrade_count,
        SUM(CASE WHEN se.event_type = 'downgrade' THEN 1 ELSE 0 END) AS downgrade_count,
        SUM(CASE WHEN se.event_type = 'churn' THEN 1 ELSE 0 END) AS churn_count,
        SUM(CASE WHEN se.event_type = 'reactivation' THEN 1 ELSE 0 END) AS reactivation_count,
        COALESCE(SUM(se.mrr_change), 0) AS total_mrr_change,
        MAX(CASE WHEN se.event_type = 'churn' THEN se.event_date END) AS last_churn_date,
        MAX(CASE WHEN se.event_type = 'reactivation' THEN se.event_date END) AS last_reactivation_date
    FROM customers c
    LEFT JOIN subscription_events se ON c.customer_id = se.customer_id
        AND se.event_date >= '2025-01-01'
        AND se.event_date < '2025-05-01'
    GROUP BY c.customer_id
),
components AS (
    SELECT
        c.customer_id,
        c.company_name,
        c.industry,
        c.company_size,
        c.current_tier,
        c.mrr,
        c.csm_assigned,
        ur.weighted_usage,
        ur.active_usage_days,
        ur.total_session_seconds,
        ur.new_features_adopted,
        sr.ticket_count,
        sr.avg_sentiment_score,
        sr.avg_resolution_hours,
        sr.bug_ticket_count,
        sub.renewal_count,
        sub.upgrade_count,
        sub.downgrade_count,
        sub.churn_count,
        sub.reactivation_count,
        sub.total_mrr_change,
        CASE
            WHEN sub.last_churn_date IS NOT NULL
             AND (sub.last_reactivation_date IS NULL OR sub.last_churn_date > sub.last_reactivation_date)
                THEN 1 ELSE 0
        END AS churned_currently_flag,
        LEAST(100, ur.weighted_usage * 2.0) AS feature_usage_intensity_score,
        LEAST(100, ur.active_usage_days * 4.0) AS login_frequency_score,
        LEAST(100, ur.new_features_adopted * 33.3333) AS new_feature_engagement_score,
        GREATEST(0, LEAST(100, 70 + (sr.avg_sentiment_score * 20) - (sr.ticket_count * 3) - (sr.bug_ticket_count * 4) - CASE WHEN sr.avg_resolution_hours > 48 THEN 10 ELSE 0 END)) AS support_experience_score,
        GREATEST(0, LEAST(100, 75 + (sub.renewal_count * 10) + (sub.upgrade_count * 8) + (sub.reactivation_count * 5) - (sub.downgrade_count * 15) - (sub.churn_count * 35))) AS payment_history_score
    FROM customers c
    LEFT JOIN usage_rollup ur ON c.customer_id = ur.customer_id
    LEFT JOIN support_rollup sr ON c.customer_id = sr.customer_id
    LEFT JOIN subscription_rollup sub ON c.customer_id = sub.customer_id
)
SELECT
    *,
    ROUND(
        0.35 * feature_usage_intensity_score
        + 0.20 * support_experience_score
        + 0.15 * login_frequency_score
        + 0.15 * payment_history_score
        + 0.15 * new_feature_engagement_score,
        2
    ) AS health_score,
    CASE
        WHEN ROUND(0.35 * feature_usage_intensity_score + 0.20 * support_experience_score + 0.15 * login_frequency_score + 0.15 * payment_history_score + 0.15 * new_feature_engagement_score, 2) <= 40 THEN 'At Risk'
        WHEN ROUND(0.35 * feature_usage_intensity_score + 0.20 * support_experience_score + 0.15 * login_frequency_score + 0.15 * payment_history_score + 0.15 * new_feature_engagement_score, 2) <= 65 THEN 'Needs Attention'
        WHEN ROUND(0.35 * feature_usage_intensity_score + 0.20 * support_experience_score + 0.15 * login_frequency_score + 0.15 * payment_history_score + 0.15 * new_feature_engagement_score, 2) <= 85 THEN 'Healthy'
        ELSE 'Champions'
    END AS health_segment,
    CASE
        WHEN ROUND(0.35 * feature_usage_intensity_score + 0.20 * support_experience_score + 0.15 * login_frequency_score + 0.15 * payment_history_score + 0.15 * new_feature_engagement_score, 2) <= 40 THEN 1
        ELSE 0
    END AS predicted_churn_flag
FROM components;

SELECT *
FROM customer_health_scores
ORDER BY health_score ASC, mrr DESC;

-- Validation: churn rate by health segment and current tier.
SELECT
    current_tier,
    health_segment,
    COUNT(*) AS customers,
    ROUND(AVG(health_score), 2) AS avg_health_score,
    ROUND(AVG(churned_currently_flag), 4) AS churn_rate,
    ROUND(AVG(mrr), 2) AS avg_mrr
FROM customer_health_scores
GROUP BY current_tier, health_segment
ORDER BY current_tier, avg_health_score;

-- Confusion matrix using At Risk as predicted churn.
SELECT
    SUM(CASE WHEN predicted_churn_flag = 1 AND churned_currently_flag = 1 THEN 1 ELSE 0 END) AS true_positives,
    SUM(CASE WHEN predicted_churn_flag = 1 AND churned_currently_flag = 0 THEN 1 ELSE 0 END) AS false_positives,
    SUM(CASE WHEN predicted_churn_flag = 0 AND churned_currently_flag = 1 THEN 1 ELSE 0 END) AS false_negatives,
    SUM(CASE WHEN predicted_churn_flag = 0 AND churned_currently_flag = 0 THEN 1 ELSE 0 END) AS true_negatives,
    ROUND(SUM(CASE WHEN predicted_churn_flag = 1 AND churned_currently_flag = 0 THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN predicted_churn_flag = 1 THEN 1 ELSE 0 END), 0), 4) AS false_positive_rate_among_predicted,
    ROUND(SUM(CASE WHEN predicted_churn_flag = 0 AND churned_currently_flag = 1 THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN churned_currently_flag = 1 THEN 1 ELSE 0 END), 0), 4) AS false_negative_rate_among_actual_churn
FROM customer_health_scores;
