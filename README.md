# Project Structure

```text
9t5_analytics_bi/
├── terraform/                   # GCP infrastructure as code
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── ingestion/                   # Python ELT scripts
│   ├── extract.py
│   ├── load.py
│   ├── requirements.txt
│   └── Dockerfile               # For Cloud Run
├── dbt/                         # dbt project root
│   ├── dbt_project.yml
│   ├── profiles.yml
│   ├── models/
│   │   ├── staging/
│   │   └── marts/
│   └── tests/
├── superset/                    # Superset deployment config
│   ├── docker-compose.yml
│   └── superset_config.py
├── .github/
│   └── workflows/
│       ├── dbt_ci.yml           # Run dbt test on PR
│       └── ingestion_deploy.yml # Deploy Cloud Run on push
├── .gitignore
└── README.md
```
