CREATE TABLE model_features AS (
    SELECT
        uf.stay_id,
        co.patient_id,
        co.age,
        uf.prior_admissions_180d,
        uf.ed_visits_180d,
        uf.days_since_last_admit,
        uf.had_prior_admission,
        co.los,
        uf.has_post_discharge_careplan,
        cd.active_conditions,
        cd.has_diabetes,
        cd.has_heart_failure,
        cd.latest_a1c,
        cd.has_recent_a1c,
        mf.active_medications,
        co.readmit_30d
    FROM utilization_features uf
    JOIN condition_features cd
        ON uf.stay_id = cd.stay_id
    JOIN medication_features mf
        ON uf.stay_id = mf.stay_id
    JOIN cohort co
        ON uf.stay_id = co.stay_id
)