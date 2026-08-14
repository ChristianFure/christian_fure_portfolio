CREATE TABLE features.medication_features AS (
    SELECT
        co.stay_id,
        COUNT(m.code) AS active_medications
    FROM features.cohort co
    LEFT JOIN medications m
        ON co.patient_id = m.patient_id
        AND m.start_date <= co.stay_end
        AND COALESCE(m.stop_date, 'infinity') > co.stay_end
    GROUP BY co.stay_id
)