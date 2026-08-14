CREATE TABLE features.utilization_features AS (
WITH prior_admissions AS (
    SELECT
        patient_id,
        stay_id,
        stay_start,
        COUNT(*) OVER (
            PARTITION BY patient_id
            ORDER BY stay_start
            RANGE BETWEEN INTERVAL '180 days' PRECEDING
            AND INTERVAL '1 day' PRECEDING
        ) AS prior_admissions_180d
    FROM features.cohort
    GROUP BY patient_id, stay_id, stay_start
),
ed_visits AS (
    SELECT
        c.patient_id,
        c.stay_id,
        c.stay_start,
        COUNT(e.start_date) FILTER (
            WHERE e.start_date >= c.stay_start - INTERVAL '180 days'
        ) AS ed_visits_180d
    FROM features.cohort c
    LEFT JOIN encounters e
        ON c.patient_id = e.patient_id
        AND encounter_class = 'emergency'
        AND c.stay_start > e.start_date
    GROUP BY c.patient_id, c.stay_id, c.stay_start
    ORDER BY c.patient_id, c.stay_start
),

last_admits AS (
    SELECT
        stay_id,
        LEAD(days_til_next_admission) OVER (
            PARTITION BY patient_id
            ORDER BY stay_start DESC
        ) AS days_since_last_admit
    FROM features.cohort
    ORDER BY patient_id, stay_start
),

post_discharge_careplans AS (
    SELECT
        co.stay_id,
        CASE
            WHEN COALESCE((MAX(ca.start_date) <= co.stay_end) AND ((MAX(ca.start_date) >= co.stay_start)), false) = TRUE THEN 1
                ELSE 0
        END AS has_careplan
    FROM features.cohort co
    LEFT JOIN careplans ca
        ON co.patient_id = ca.patient_id
        AND ca.start_date <= co.stay_end
        AND ca.start_date >= co.stay_start
        AND COALESCE(ca.stop_date, 'infinity') > co.stay_end
        AND ca.description ILIKE '%plan%'
    GROUP BY co.stay_id
)

SELECT
    pa.stay_id,
    pa.prior_admissions_180d,
    ev.ed_visits_180d,
    la.days_since_last_admit,
    CASE WHEN la.days_since_last_admit IS NULL THEN 0 ELSE 1 END AS had_prior_admission,
    pdc.has_careplan AS has_post_discharge_careplan,
    CASE WHEN c.readmit_30d = 1 THEN LEAD(total_stay_cost, 1) OVER (ORDER BY c.stay_start) ELSE 0.0 END AS cost_of_readmission
FROM features.cohort c
JOIN prior_admissions pa
    ON c.stay_id = pa.stay_id
LEFT JOIN ed_visits ev
    ON c.stay_id = ev.stay_id
JOIN last_admits la
    ON c.stay_id = la.stay_id
JOIN post_discharge_careplans pdc
    ON c.stay_id = pdc.stay_id
)
