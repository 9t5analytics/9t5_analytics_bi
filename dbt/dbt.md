```text
dbt/
├── dbt_project.yml          # project configuration
├── profiles.yml             # database connection settings
├── models/
│   ├── staging/             # one model per raw table
│   │   ├── _sources.yml     # declares your raw tables as sources
│   │   ├── _staging.yml     # documents and tests staging models
│   │   └── stg_*.sql        # staging model files
│   └── marts/               # business logic models
│       ├── _marts.yml       # documents and tests mart models
│       └── fct_*.sql        # fact models
│       └── dim_*.sql        # dimension models
├── tests/                   # custom data tests
└── macros/                  # reusable SQL snippets

```