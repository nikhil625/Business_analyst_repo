#  Product Analytics Case Study: Feature Adoption & Customer Health

---

##  Objective

Analyze product usage data (Jan–Apr 2024) to evaluate feature adoption, user engagement, and customer health. The goal is to identify drivers of retention and areas of product improvement.

---

##  How to Reproduce the Analysis

1. **Set up environment**

   ```bash
   pip install pandas matplotlib streamlit
   ```

2. **Run SQL queries**

   * Navigate to `sql/`
   * Execute queries in order:

     * `01_feature_adoption.sql`
     * `02_health_score.sql`
     * `03_cohort_retention.sql`
     * `04_feature_value.sql`
     * `05_dashboard_queries.sql`

3. **Run Python analysis**

   * Open `analysis/health_score_validation.ipynb`
   * Run all cells to validate health score

4. **Launch dashboard (optional)**

   ```bash
   streamlit run dashboard/app.py
   ```

---

##  Key Findings

* Feature adoption increased consistently across all features
* Engagement is shallow:

  * Low DAU/MAU ratios
  * No power users identified
* Activation rates are extremely low (<2% for most features)
* `custom_roles` has highest stickiness (high engagement, low adoption)
* Users explore features but fail to develop habitual usage

---

##  Top 3 Recommendations (with Expected Impact)

### 1. Improve Onboarding Experience

* Add guided product tours and feature prompts
   Expected Impact: Increase activation rate by 2–3x

---

### 2. Build Habit-Forming Features

* Introduce alerts, automation, and recurring workflows
   Expected Impact: Improve DAU/MAU and user retention

---

### 3. Upsell High-Engagement Features (`custom_roles`)

* Target users already engaging deeply
   Expected Impact: Increase revenue and expansion opportunities

---

##  Assumptions & Limitations

* Feature release dates not available → approximated using first observed usage
* Login frequency derived from session activity (proxy)
* Activation measured relative to available data, not true release timing
* Health score is rule-based (not optimized via ML)

---

##  Data Quality Notes

* Missing values in usage duration handled via filtering (`duration_seconds > 0`)
* Support ticket missing values interpreted as unresolved tickets
* Some customers have no feature usage → treated as inactive users
* Potential bias due to limited observation window (Jan–Apr 2024)

---

## Methodology Overview

* Metrics computed at feature and customer level
* Health score designed as weighted sum of:

  * Usage intensity
  * Login frequency
  * Support signals
  * Payment behavior
  * Feature adoption
* Score validated using churn correlation and classification metrics

---

##  Deliverables

* SQL queries for all KPIs
* Feature adoption analysis
* Customer health scoring model
* Validation notebook
* Dashboard (Power BI / Streamlit)
* Stakeholder report
* Methodology documentation

---

##  Key Takeaway

Despite strong growth in feature adoption, user engagement remains shallow. Improving onboarding and building habit-forming product experiences are critical to driving retention and long-term customer value.
