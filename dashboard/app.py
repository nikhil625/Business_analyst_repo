import streamlit as st
import pandas as pd
import plotly.express as px
import os

# -------------------------
# Page Config
# -------------------------
st.set_page_config(layout="wide")
st.title("📊 Feature Adoption Dashboard (Jan–Apr 2024)")

# -------------------------
# Load Data (CORRECTED)
# -------------------------
base_path = os.path.dirname(os.path.dirname(__file__))

customer = pd.read_csv(
    os.path.join(base_path, "data/customers.csv"),
    parse_dates=['signup_date']
)

feature_usage = pd.read_csv(
    os.path.join(base_path, "data/feature_usage.csv"),
    parse_dates=['session_date']
)

subscription = pd.read_csv(
    os.path.join(base_path, "data/subscription_events.csv"),
    parse_dates=['event_date']
)

support_tickets = pd.read_csv(
    os.path.join(base_path, "data/support_tickets.csv"),
    parse_dates=['opened_at']
)

# -------------------------
# Filter Data
# -------------------------
df = feature_usage[
    (feature_usage['session_date'] >= '2024-01-01') &
    (feature_usage['session_date'] <= '2024-04-30') &
    (feature_usage['duration_seconds'] > 0)
].copy()

df['week'] = df['session_date'].dt.to_period('W').astype(str)
df['date'] = df['session_date'].dt.date
df['month'] = df['session_date'].dt.to_period('M')

# -------------------------
# Sidebar Filter
# -------------------------
st.sidebar.header("Filters")

features = df['feature'].unique()
selected_features = st.sidebar.multiselect(
    "Select Features",
    features,
    default=features
)

df = df[df['feature'].isin(selected_features)]

# -------------------------
# KPI CARDS
# -------------------------
st.subheader(" Key Metrics")

col1, col2, col3 = st.columns(3)

total_users = df['customer_id'].nunique()
total_features = df['feature'].nunique()

# Stickiness calculation
dau = df.groupby(['feature', 'date'])['customer_id'].nunique().reset_index()
dau['month'] = pd.to_datetime(dau['date']).dt.to_period('M')

avg_dau = dau.groupby(['feature', 'month'])['customer_id'].mean().reset_index()

mau = df.groupby(['feature', 'month'])['customer_id'].nunique().reset_index()

stickiness = avg_dau.merge(mau, on=['feature', 'month'])
stickiness['ratio'] = stickiness['customer_id_x'] / stickiness['customer_id_y']

avg_stickiness = round(stickiness['ratio'].mean(), 3)

col1.metric("Total Active Users", total_users)
col2.metric("Features Used", total_features)
col3.metric("Avg Stickiness (DAU/MAU)", avg_stickiness)

# -------------------------
#  Weekly Trends
# -------------------------
st.subheader(" Weekly Feature Usage")

weekly = df.groupby(['feature', 'week'])['customer_id'].nunique().reset_index()

fig1 = px.line(
    weekly,
    x='week',
    y='customer_id',
    color='feature',
    markers=True
)

st.plotly_chart(fig1, use_container_width=True)

# -------------------------
#  Adoption by Customer Tier
# -------------------------
st.subheader(" Adoption by Customer Tier")

df_tier = df.merge(customer[['customer_id', 'plan']], on='customer_id', how='left')

tier = df_tier.groupby(['feature', 'plan'])['customer_id'].nunique().reset_index()

fig2 = px.bar(
    tier,
    x='feature',
    y='customer_id',
    color='plan',
    barmode='group'
)

st.plotly_chart(fig2, use_container_width=True)

# -------------------------
#  Adoption by Company Size
# -------------------------
st.subheader("Adoption by Company Size")

df_size = df.merge(customer[['customer_id', 'company_size']], on='customer_id', how='left')

size = df_size.groupby(['feature', 'company_size'])['customer_id'].nunique().reset_index()

fig3 = px.bar(
    size,
    x='feature',
    y='customer_id',
    color='company_size',
    barmode='group'
)

st.plotly_chart(fig3, use_container_width=True)

# -------------------------
#  Correlation Matrix
# -------------------------
st.subheader(" Feature Usage Correlation")

matrix = df.groupby(['customer_id', 'feature']).size().unstack(fill_value=0)
matrix = (matrix > 0).astype(int)

corr = matrix.corr()

fig4 = px.imshow(
    corr,
    text_auto=True,
    color_continuous_scale='Blues'
)

st.plotly_chart(fig4, use_container_width=True)

# -------------------------
#  Stickiness Chart
# -------------------------
st.subheader(" Feature Stickiness (DAU/MAU)")

final = stickiness.groupby('feature')['ratio'].mean().reset_index()

fig5 = px.bar(
    final.sort_values(by='ratio', ascending=False),
    x='feature',
    y='ratio',
    title="Stickiness by Feature"
)

st.plotly_chart(fig5, use_container_width=True)

# -------------------------
# KEY INSIGHT
# -------------------------
top_feature = final.sort_values(by='ratio', ascending=False).iloc[0]

st.subheader(" Key Insight")

st.success(
    f"Stickiest Feature: {top_feature['feature']} "
    f"(DAU/MAU: {round(top_feature['ratio'], 3)})"
)