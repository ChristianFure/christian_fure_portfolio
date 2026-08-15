CREATE TABLE features.cohort AS
WITH inpatient_stays AS (
    SELECT patient_id,
           start_date as admission_date,
           stop_date as discharge_date,
           total_claim_cost
    FROM encounters
    WHERE encounter_class = 'inpatient'
),
sorted_stays AS (
    SELECT
        patient_id,
        admission_date,
        discharge_date,
        total_claim_cost,
        -- Flag a new "group" whenever this row's admission is after the previous row's discharge
        CASE
            WHEN admission_date <= MAX(discharge_date) OVER (
                PARTITION BY patient_id
                ORDER BY admission_date
                ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
            )
            THEN 0
            ELSE 1
        END AS is_new_group
    FROM inpatient_stays
),
grouped AS (
    SELECT
        patient_id,
        admission_date,
        discharge_date,
        total_claim_cost,
        SUM(is_new_group) OVER (
            PARTITION BY patient_id
            ORDER BY admission_date
        ) AS stay_group
    FROM sorted_stays
),
patient_stays AS (
    SELECT
        patient_id,
        MIN(admission_date) AS stay_start,
        MAX(discharge_date) AS stay_end,
        (LEAD(MIN(admission_date)) OVER (
            PARTITION BY patient_id
            ORDER BY MIN(admission_date)
        ) - MAX(discharge_date)) AS days_til_next_admission,
        SUM(total_claim_cost) as total_stay_cost
    FROM grouped
    GROUP BY patient_id, stay_group
)

SELECT
    gen_random_uuid() AS stay_id,
    CASE WHEN p.gender = 'M' THEN 1 ELSE 0 END AS gender_male,
    CASE WHEN p.gender = 'F' THEN 1 ELSE 0 END AS gender_female,
    EXTRACT(YEAR FROM AGE(ps.stay_end, p.birthdate)) AS age,
    ps.*,
    stay_end - stay_start AS los,
    CASE
        WHEN days_til_next_admission IS NOT NULL
            AND days_til_next_admission < 31
        THEN 1
        ELSE 0
    END AS readmit_30d
FROM patient_stays ps
JOIN patients p
    ON ps.patient_id = p.id
ORDER BY patient_id, stay_start;

ALTER TABLE features.cohort
ADD PRIMARY KEY (stay_id)
