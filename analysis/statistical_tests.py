"""
Hypothesis testing for the SaaS Product Feature Adoption project.

This script connects to MySQL, pulls analysis-ready data from the normalized
views, and runs statistical tests in Python.

Setup:
    pip install pandas scipy sqlalchemy pymysql

Environment variables:
    MYSQL_USER=root
    MYSQL_PASSWORD=your_password
    MYSQL_HOST=localhost
    MYSQL_PORT=3306
    MYSQL_DATABASE=dataflow_project

Output:
    analysis/hypothesis_test_results.md
"""

from __future__ import annotations

import math
import os
from pathlib import Path

import pandas as pd
from scipy import stats
from sqlalchemy import create_engine, text


OUTPUT_PATH = Path(__file__).with_name("hypothesis_test_results.md")


def mysql_engine():
    user = os.getenv("MYSQL_USER", "root")
    password = os.getenv("MYSQL_PASSWORD", "")
    host = os.getenv("MYSQL_HOST", "localhost")
    port = os.getenv("MYSQL_PORT", "3306")
    database = os.getenv("MYSQL_DATABASE", "dataflow_project")

    if not password:
        raise RuntimeError(
            "MYSQL_PASSWORD is not set. Set it before running, for example: "
            "PowerShell: $env:MYSQL_PASSWORD='your_password'"
        )

    url = f"mysql+pymysql://{user}:{password}@{host}:{port}/{database}"
    return create_engine(url)


def two_proportion_z_test(success_a: int, total_a: int, success_b: int, total_b: int):
    rate_a = success_a / total_a if total_a else math.nan
    rate_b = success_b / total_b if total_b else math.nan
    pooled = (success_a + success_b) / (total_a + total_b)
    se = math.sqrt(pooled * (1 - pooled) * ((1 / total_a) + (1 / total_b)))
    z_score = (rate_a - rate_b) / se if se else math.nan
    p_value = 2 * (1 - stats.norm.cdf(abs(z_score))) if not math.isnan(z_score) else math.nan
    return rate_a, rate_b, z_score, p_value


def fetch_hypothesis_dataset(engine) -> pd.DataFrame:
    query = """
    WITH cohorts AS (
        SELECT customer_id, signup_date
        FROM customers
        WHERE signup_date >= '2024-01-01'
          AND signup_date < '2025-01-01'
    ),
    adoption AS (
        SELECT
            c.customer_id,
            COUNT(DISTINCT fu.feature_name) AS new_features_adopted_within_30_days
        FROM cohorts c
        LEFT JOIN feature_usage fu
            ON c.customer_id = fu.customer_id
           AND fu.feature_name IN ('API Connectors', 'Real-time Sync', 'Custom Transformations')
           AND fu.usage_count > 0
           AND fu.usage_date >= '2025-01-01'
           AND fu.usage_date < '2025-04-01'
        GROUP BY c.customer_id
    ),
    retention_12 AS (
        SELECT
            c.customer_id,
            CASE
                WHEN MAX(CASE WHEN se.event_type = 'churn'
                               AND se.event_date < DATE_ADD(c.signup_date, INTERVAL 12 MONTH)
                          THEN se.event_date END) IS NOT NULL
                 AND (
                    MAX(CASE WHEN se.event_type = 'reactivation'
                              AND se.event_date < DATE_ADD(c.signup_date, INTERVAL 12 MONTH)
                         THEN se.event_date END) IS NULL
                    OR MAX(CASE WHEN se.event_type = 'churn'
                                 AND se.event_date < DATE_ADD(c.signup_date, INTERVAL 12 MONTH)
                            THEN se.event_date END)
                       > MAX(CASE WHEN se.event_type = 'reactivation'
                                   AND se.event_date < DATE_ADD(c.signup_date, INTERVAL 12 MONTH)
                              THEN se.event_date END)
                 )
                    THEN 0 ELSE 1
            END AS retained_12m_flag
        FROM cohorts c
        LEFT JOIN subscription_events se
            ON c.customer_id = se.customer_id
        GROUP BY c.customer_id, c.signup_date
    )
    SELECT
        c.customer_id,
        CASE
            WHEN COALESCE(a.new_features_adopted_within_30_days, 0) >= 2 THEN 1
            ELSE 0
        END AS adopted_2_plus_features,
        COALESCE(a.new_features_adopted_within_30_days, 0) AS new_features_adopted_within_30_days,
        r.retained_12m_flag
    FROM cohorts c
    LEFT JOIN adoption a ON c.customer_id = a.customer_id
    LEFT JOIN retention_12 r ON c.customer_id = r.customer_id;
    """
    return pd.read_sql(query, engine)


def fetch_health_scores(engine) -> pd.DataFrame:
    # Run 02_health_score.sql first so this view exists.
    return pd.read_sql(
        """
        SELECT
            customer_id,
            current_tier,
            mrr,
            health_score,
            health_segment,
            churned_currently_flag,
            predicted_churn_flag
        FROM customer_health_scores;
        """,
        engine,
    )


def fetch_feature_upgrade_dataset(engine) -> pd.DataFrame:
    query = """
    WITH customer_feature AS (
        SELECT
            c.customer_id,
            MAX(CASE WHEN fu.feature_name = 'API Connectors' AND fu.usage_count > 0 THEN 1 ELSE 0 END) AS used_api_connectors,
            MAX(CASE WHEN fu.feature_name = 'Real-time Sync' AND fu.usage_count > 0 THEN 1 ELSE 0 END) AS used_real_time_sync,
            MAX(CASE WHEN fu.feature_name = 'Custom Transformations' AND fu.usage_count > 0 THEN 1 ELSE 0 END) AS used_custom_transformations
        FROM customers c
        LEFT JOIN feature_usage fu
            ON c.customer_id = fu.customer_id
           AND fu.usage_date >= '2025-01-01'
           AND fu.usage_date < '2025-05-01'
        GROUP BY c.customer_id
    ),
    upgrades AS (
        SELECT
            customer_id,
            MAX(CASE WHEN event_type = 'upgrade'
                      AND event_date >= '2025-01-01'
                      AND event_date < '2025-05-01'
                THEN 1 ELSE 0 END) AS upgraded_flag
        FROM subscription_events
        GROUP BY customer_id
    )
    SELECT
        cf.customer_id,
        cf.used_api_connectors,
        cf.used_real_time_sync,
        cf.used_custom_transformations,
        COALESCE(u.upgraded_flag, 0) AS upgraded_flag
    FROM customer_feature cf
    LEFT JOIN upgrades u ON cf.customer_id = u.customer_id;
    """
    return pd.read_sql(query, engine)


def summarize_feature_upgrade_tests(df: pd.DataFrame) -> list[str]:
    lines = ["## Feature Usage vs Upgrade Tests", ""]
    feature_columns = {
        "API Connectors": "used_api_connectors",
        "Real-time Sync": "used_real_time_sync",
        "Custom Transformations": "used_custom_transformations",
    }

    for feature_name, col in feature_columns.items():
        users = df[df[col] == 1]
        non_users = df[df[col] == 0]
        success_a = int(users["upgraded_flag"].sum())
        total_a = len(users)
        success_b = int(non_users["upgraded_flag"].sum())
        total_b = len(non_users)

        rate_a, rate_b, z_score, p_value = two_proportion_z_test(
            success_a, total_a, success_b, total_b
        )

        lines.extend(
            [
                f"### {feature_name}",
                "",
                f"- Feature users: {total_a}",
                f"- Non-users: {total_b}",
                f"- Upgrade rate for users: {rate_a:.4f}",
                f"- Upgrade rate for non-users: {rate_b:.4f}",
                f"- Lift: {rate_a - rate_b:.4f}",
                f"- Two-proportion z-score: {z_score:.4f}",
                f"- p-value: {p_value:.4f}",
                "",
            ]
        )
    return lines


def main():
    engine = mysql_engine()

    with engine.connect() as conn:
        conn.execute(text("SELECT 1"))

    retention = fetch_hypothesis_dataset(engine)
    health = fetch_health_scores(engine)
    feature_upgrade = fetch_feature_upgrade_dataset(engine)

    adopted = retention[retention["adopted_2_plus_features"] == 1]
    not_adopted = retention[retention["adopted_2_plus_features"] == 0]

    success_a = int(adopted["retained_12m_flag"].sum())
    total_a = len(adopted)
    success_b = int(not_adopted["retained_12m_flag"].sum())
    total_b = len(not_adopted)
    rate_a, rate_b, z_score, p_value = two_proportion_z_test(
        success_a, total_a, success_b, total_b
    )

    contingency = pd.crosstab(health["health_segment"], health["churned_currently_flag"])
    chi2, chi2_p, dof, expected = stats.chi2_contingency(contingency)

    at_risk = health[health["health_segment"] == "At Risk"]["churned_currently_flag"]
    others = health[health["health_segment"] != "At Risk"]["churned_currently_flag"]
    risk_rate, other_rate, risk_z, risk_p = two_proportion_z_test(
        int(at_risk.sum()), len(at_risk), int(others.sum()), len(others)
    )

    lines = [
        "# Hypothesis Test Results",
        "",
        "## Primary Hypothesis",
        "",
        "Hypothesis: Customers who adopt 2+ new features have higher 12-month retention.",
        "",
        f"- Adopted 2+ customers: {total_a}",
        f"- Did not adopt 2+ customers: {total_b}",
        f"- Retention rate for adopted 2+: {rate_a:.4f}",
        f"- Retention rate for not adopted 2+: {rate_b:.4f}",
        f"- Retention lift: {rate_a - rate_b:.4f}",
        f"- Target lift from prompt: 0.2000",
        f"- Two-proportion z-score: {z_score:.4f}",
        f"- p-value: {p_value:.4f}",
        "",
        "Interpretation: If p-value < 0.05, the retention difference is statistically significant. Compare the observed lift to 0.20 to evaluate the business hypothesis.",
        "",
        "## Health Segment vs Churn",
        "",
        f"- Chi-square statistic: {chi2:.4f}",
        f"- Degrees of freedom: {dof}",
        f"- p-value: {chi2_p:.4f}",
        "",
        "## At Risk Segment Churn Lift",
        "",
        f"- At Risk churn rate: {risk_rate:.4f}",
        f"- Other segments churn rate: {other_rate:.4f}",
        f"- Churn lift: {risk_rate - other_rate:.4f}",
        f"- Two-proportion z-score: {risk_z:.4f}",
        f"- p-value: {risk_p:.4f}",
        "",
    ]

    lines.extend(summarize_feature_upgrade_tests(feature_upgrade))

    OUTPUT_PATH.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
