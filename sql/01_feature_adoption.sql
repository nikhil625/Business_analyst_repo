/*
01_feature_adoption_mysql.sql
MySQL 8+

Feature adoption metrics for Jan-Apr 2025.
Adoption requires usage_count > 0.
*/

WITH feature_releases AS (
    SELECT 'API Connectors' AS feature_name, DATE('2025-01-01') AS release_date
    UNION ALL SELECT 'Real-time Sync', DATE('2025-02-01')
    UNION ALL SELECT 'Custom Transformations', DATE('2025-03-01')
),
feature_activity AS (
    SELECT
        fu.customer_id,
        fu.feature_name,
        fu.usage_date,
        DATE_SUB(fu.usage_date, INTERVAL WEEKDAY(fu.usage_date) DAY) AS usage_week,
        DATE_FORMAT(fu.usage_date, '%Y-%m-01') AS usage_month,
        COALESCE(fu.usage_count, 0) AS usage_count,
        COALESCE(fu.session_duration_seconds, 0) AS session_duration_seconds,
        CASE WHEN COALESCE(fu.usage_count, 0) > 0 THEN 1 ELSE 0 END AS engaged_flag
    FROM feature_usage fu
    INNER JOIN feature_releases fr ON fu.feature_name = fr.feature_name
    WHERE fu.usage_date >= '2025-01-01'
      AND fu.usage_date < '2025-05-01'
),
feature_customer_rollup AS (
    SELECT
        customer_id,
        feature_name,
        MIN(CASE WHEN engaged_flag = 1 THEN usage_date END) AS first_use_date,
        COUNT(DISTINCT CASE WHEN engaged_flag = 1 THEN usage_date END) AS active_days,
        SUM(CASE WHEN engaged_flag = 1 THEN usage_count ELSE 0 END) AS total_usage_count,
        SUM(session_duration_seconds) AS total_session_seconds
    FROM feature_activity
    GROUP BY customer_id, feature_name
),
monthly_stickiness AS (
    SELECT
        ma.feature_name,
        ma.usage_month,
        ma.mau,
        ROUND(AVG(da.dau), 2) AS avg_dau,
        ROUND(AVG(da.dau) / NULLIF(ma.mau, 0), 4) AS dau_mau_ratio
    FROM (
        SELECT feature_name, usage_month, COUNT(DISTINCT customer_id) AS mau
        FROM feature_activity
        WHERE engaged_flag = 1
        GROUP BY feature_name, usage_month
    ) ma
    LEFT JOIN (
        SELECT feature_name, usage_month, usage_date, COUNT(DISTINCT customer_id) AS dau
        FROM feature_activity
        WHERE engaged_flag = 1
        GROUP BY feature_name, usage_month, usage_date
    ) da ON ma.feature_name = da.feature_name AND ma.usage_month = da.usage_month
    GROUP BY ma.feature_name, ma.usage_month, ma.mau
),
monthly_power_users AS (
    SELECT
        customer_id,
        feature_name,
        usage_month,
        COUNT(DISTINCT CASE WHEN engaged_flag = 1 THEN usage_date END) AS active_days_in_month
    FROM feature_activity
    GROUP BY customer_id, feature_name, usage_month
),
feature_summary AS (
    SELECT
        fr.feature_name,
        fr.release_date,
        COUNT(DISTINCT c.customer_id) AS eligible_customers,
        COUNT(DISTINCT CASE WHEN fcr.first_use_date IS NOT NULL THEN fcr.customer_id END) AS adopted_customers,
        ROUND(COUNT(DISTINCT CASE WHEN fcr.first_use_date IS NOT NULL THEN fcr.customer_id END) / NULLIF(COUNT(DISTINCT c.customer_id), 0), 4) AS adoption_rate,
        MIN(fcr.first_use_date) AS first_customer_usage_date,
        DATEDIFF(MIN(fcr.first_use_date), fr.release_date) AS time_to_first_use_days,
        COUNT(DISTINCT CASE WHEN fcr.first_use_date >= fr.release_date AND fcr.first_use_date < DATE_ADD(fr.release_date, INTERVAL 7 DAY) THEN fcr.customer_id END) AS activated_within_7_days_customers,
        ROUND(COUNT(DISTINCT CASE WHEN fcr.first_use_date >= fr.release_date AND fcr.first_use_date < DATE_ADD(fr.release_date, INTERVAL 7 DAY) THEN fcr.customer_id END) / NULLIF(COUNT(DISTINCT c.customer_id), 0), 4) AS activation_rate_7_days,
        COUNT(DISTINCT CASE WHEN mpu.active_days_in_month >= 10 THEN mpu.customer_id END) AS power_users_any_month,
        ROUND(AVG(CASE WHEN fcr.first_use_date IS NOT NULL THEN fcr.total_usage_count END), 2) AS avg_usage_per_adopter,
        ROUND(AVG(CASE WHEN fcr.first_use_date IS NOT NULL THEN fcr.total_session_seconds END), 2) AS avg_session_seconds_per_adopter
    FROM feature_releases fr
    CROSS JOIN customers c
    LEFT JOIN feature_customer_rollup fcr ON c.customer_id = fcr.customer_id AND fr.feature_name = fcr.feature_name
    LEFT JOIN monthly_power_users mpu ON fcr.customer_id = mpu.customer_id AND fcr.feature_name = mpu.feature_name
    WHERE c.signup_date <= '2025-04-30'
    GROUP BY fr.feature_name, fr.release_date
)
SELECT
    fs.*,
    ms.usage_month,
    ms.avg_dau,
    ms.mau,
    ms.dau_mau_ratio
FROM feature_summary fs
LEFT JOIN monthly_stickiness ms ON fs.feature_name = ms.feature_name
ORDER BY fs.feature_name, ms.usage_month;

-- Weekly trend dashboard dataset.
SELECT
    feature_name,
    DATE_SUB(usage_date, INTERVAL WEEKDAY(usage_date) DAY) AS usage_week,
    COUNT(DISTINCT CASE WHEN usage_count > 0 THEN customer_id END) AS weekly_active_customers,
    SUM(CASE WHEN usage_count > 0 THEN usage_count ELSE 0 END) AS weekly_usage_count,
    SUM(session_duration_seconds) AS weekly_session_seconds
FROM feature_usage
WHERE feature_name IN ('API Connectors', 'Real-time Sync', 'Custom Transformations')
  AND usage_date >= '2025-01-01'
  AND usage_date < '2025-05-01'
GROUP BY feature_name, usage_week
ORDER BY feature_name, usage_week;

-- Adoption by tier.
SELECT
    fl.feature_name,
    c.current_tier,
    COUNT(DISTINCT c.customer_id) AS eligible_customers,
    COUNT(DISTINCT a.customer_id) AS adopted_customers,
    ROUND(COUNT(DISTINCT a.customer_id) / NULLIF(COUNT(DISTINCT c.customer_id), 0), 4) AS adoption_rate
FROM (
    SELECT 'API Connectors' AS feature_name
    UNION ALL SELECT 'Real-time Sync'
    UNION ALL SELECT 'Custom Transformations'
) fl
CROSS JOIN customers c
LEFT JOIN (
    SELECT DISTINCT customer_id, feature_name
    FROM feature_usage
    WHERE usage_count > 0
      AND usage_date >= '2025-01-01'
      AND usage_date < '2025-05-01'
) a ON c.customer_id = a.customer_id AND fl.feature_name = a.feature_name
GROUP BY fl.feature_name, c.current_tier
ORDER BY fl.feature_name, c.current_tier;

-- Adoption by company size.
SELECT
    fl.feature_name,
    c.company_size,
    COUNT(DISTINCT c.customer_id) AS eligible_customers,
    COUNT(DISTINCT a.customer_id) AS adopted_customers,
    ROUND(COUNT(DISTINCT a.customer_id) / NULLIF(COUNT(DISTINCT c.customer_id), 0), 4) AS adoption_rate
FROM (
    SELECT 'API Connectors' AS feature_name
    UNION ALL SELECT 'Real-time Sync'
    UNION ALL SELECT 'Custom Transformations'
) fl
CROSS JOIN customers c
LEFT JOIN (
    SELECT DISTINCT customer_id, feature_name
    FROM feature_usage
    WHERE usage_count > 0
      AND usage_date >= '2025-01-01'
      AND usage_date < '2025-05-01'
) a ON c.customer_id = a.customer_id AND fl.feature_name = a.feature_name
GROUP BY fl.feature_name, c.company_size
ORDER BY fl.feature_name, c.company_size;

-- Correlation matrix.
WITH matrix AS (
    SELECT
        c.customer_id,
        SUM(CASE WHEN fu.feature_name = 'API Connectors' AND fu.usage_count > 0 THEN fu.usage_count ELSE 0 END) AS api_connectors_usage,
        SUM(CASE WHEN fu.feature_name = 'Real-time Sync' AND fu.usage_count > 0 THEN fu.usage_count ELSE 0 END) AS real_time_sync_usage,
        SUM(CASE WHEN fu.feature_name = 'Custom Transformations' AND fu.usage_count > 0 THEN fu.usage_count ELSE 0 END) AS custom_transformations_usage
    FROM customers c
    LEFT JOIN feature_usage fu ON c.customer_id = fu.customer_id
        AND fu.usage_date >= '2025-01-01'
        AND fu.usage_date < '2025-05-01'
    GROUP BY c.customer_id
)
SELECT
    COUNT(*) AS customers_in_matrix,
    SUM(CASE WHEN api_connectors_usage > 0 THEN 1 ELSE 0 END) AS api_connectors_adopters,
    SUM(CASE WHEN real_time_sync_usage > 0 THEN 1 ELSE 0 END) AS real_time_sync_adopters,
    SUM(CASE WHEN custom_transformations_usage > 0 THEN 1 ELSE 0 END) AS custom_transformations_adopters,
    ROUND(STDDEV_POP(api_connectors_usage), 4) AS api_connectors_stddev,
    ROUND(STDDEV_POP(real_time_sync_usage), 4) AS real_time_sync_stddev,
    ROUND(STDDEV_POP(custom_transformations_usage), 4) AS custom_transformations_stddev,
    (AVG(api_connectors_usage * real_time_sync_usage) - AVG(api_connectors_usage) * AVG(real_time_sync_usage))
        / NULLIF(STDDEV_POP(api_connectors_usage) * STDDEV_POP(real_time_sync_usage), 0) AS corr_api_connectors_real_time_sync,
    (AVG(api_connectors_usage * custom_transformations_usage) - AVG(api_connectors_usage) * AVG(custom_transformations_usage))
        / NULLIF(STDDEV_POP(api_connectors_usage) * STDDEV_POP(custom_transformations_usage), 0) AS corr_api_connectors_custom_transformations,
    (AVG(real_time_sync_usage * custom_transformations_usage) - AVG(real_time_sync_usage) * AVG(custom_transformations_usage))
        / NULLIF(STDDEV_POP(real_time_sync_usage) * STDDEV_POP(custom_transformations_usage), 0) AS corr_real_time_sync_custom_transformations
FROM matrix;
