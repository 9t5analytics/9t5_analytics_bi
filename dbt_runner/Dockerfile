FROM python:3.11-slim

RUN pip install dbt-core==1.8.0 dbt-bigquery==1.8.0

WORKDIR /app

COPY dbt/analytics/ ./analytics/
COPY dbt_runner/profiles.yml ./profiles.yml

ENV PYTHONUNBUFFERED=1
ENV DBT_PROFILES_DIR=/app

CMD ["dbt", "run", "--select", "marts", "--project-dir", "/app/analytics", "--profile", "analytics"]
