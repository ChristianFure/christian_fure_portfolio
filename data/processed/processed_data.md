## Data Files

| File | Description | S3 Link |
|------|-------------|---------|
| `cohort.csv` | All patient stays used to train and test the model. | [Link](https://readmission-prediction-synthea-data-811136281995-us-east-2-an.s3.us-east-2.amazonaws.com/synthea_data_for_readmission_prediction/processed/cohort/year%3D2026/month%3D07/cohort.csv) |
| `condition_features.csv` | Features related to patient's conditions during look-back window. | [Link](https://readmission-prediction-synthea-data-811136281995-us-east-2-an.s3.us-east-2.amazonaws.com/synthea_data_for_readmission_prediction/processed/features/year%3D2026/month%3D07/condition_features.csv) |
| `medication_features.csv` | Features related to patient's active medications at discharge. | [Link](https://readmission-prediction-synthea-data-811136281995-us-east-2-an.s3.us-east-2.amazonaws.com/synthea_data_for_readmission_prediction/processed/features/year%3D2026/month%3D07/medication_features.csv) |
| `utilization_features.csv` | Features related to patient's recent hospital usage. | [Link](https://readmission-prediction-synthea-data-811136281995-us-east-2-an.s3.us-east-2.amazonaws.com/synthea_data_for_readmission_prediction/processed/features/year%3D2026/month%3D07/utilization_features.csv) |
| `model_features.csv` | The final table where every stay_id combines with all the features from the above tables. | [Link](https://readmission-prediction-synthea-data-811136281995-us-east-2-an.s3.us-east-2.amazonaws.com/synthea_data_for_readmission_prediction/processed/model_ready/year%3D2026/month%3D07/model_features.csv) |


```mermaid
erDiagram
    COHORT {
        uuid stay_id PK
        uuid patient_id
        integer gender_male
        integer gender_female
        numeric age
        date stay_start
        date stay_end
        integer los
        integer days_til_next_admission
        numeric total_stay_cost
        integer readmit_30d
    }
    UTILIZATION_FEATURES {
        uuid stay_id FK
        bigint prior_admissions_90d
        bigint prior_admissions_180d
        bigint prior_admissions_365d
        bigint ed_visits_90d
        bigint ed_visits_120d
        bigint ed_visits_180d
        bigint ed_visits_365d
        integer days_since_last_admit
        integer had_prior_admission
        integer los
        integer has_post_discharge_careplan
        numeric cost_of_readmission
    }
    MEDICATION_FEATURES {
        uuid stay_id FK
        bigint active_medications
    }
    CONDITION_FEATURES {
        uuid stay_id FK
        bigint active_conditions
        integer has_heart_failure
        integer has_diabetes
        numeric latest_a1c
        integer has_recent_a1c
    }
    MODEL_FEATURES {
        uuid stay_id FK
        uuid patient_id
        numeric age
        bigint prior_admissions_180d
        bigint ed_visits_180d
        integer days_since_last_admit
        integer had_prior_admission
        integer los
        integer has_post_discharge_careplan
        bigint active_conditions
        integer has_diabetes
        integer has_heart_failure
        numeric latest_a1c
        integer has_recent_a1c
        bigint active_medications
        integer readmit_30d
    }
    COHORT ||--o| UTILIZATION_FEATURES : "has"
    COHORT ||--o| MEDICATION_FEATURES : "has"
    COHORT ||--o| CONDITION_FEATURES : "has"
    UTILIZATION_FEATURES ||--|| MODEL_FEATURES : "feeds"
    MEDICATION_FEATURES ||--|| MODEL_FEATURES : "feeds"
    CONDITION_FEATURES ||--|| MODEL_FEATURES : "feeds"
    COHORT ||--|| MODEL_FEATURES : "feeds"
```
'''
