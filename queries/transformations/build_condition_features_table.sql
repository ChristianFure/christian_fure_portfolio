CREATE TABLE features.condition_features AS (
WITH active_conditions AS (
    SELECT
        coh.stay_id,
        COUNT(con.id) AS active_conditions
    FROM features.cohort coh
    LEFT JOIN conditions con
        ON con.patient_id = coh.patient_id
        AND con.start_date < coh.stay_end
        AND COALESCE(con.stop_date, 'infinity') >= coh.stay_end
        AND con.description ILIKE '%disorder%'
    GROUP BY coh.stay_id
),

chronic_conditions AS (
    SELECT
        coh.stay_id,
        MAX(CASE WHEN con.code = '44054006' THEN 1 ELSE 0 END) AS has_diabetes,
        MAX(CASE WHEN con.code IN ('88805009', '84114007') THEN 1 ELSE 0 END) AS has_heart_failure
    FROM features.cohort coh
    LEFT JOIN conditions con
        ON coh.patient_id = con.patient_id
        AND con.code IN ('44054006', '88805009', '84114007')
        AND con.start_date < coh.stay_end
    GROUP BY coh.stay_id
),

a1c_results AS (
    SELECT DISTINCT ON (co.stay_id)
        co.stay_id,
        ob.value::DECIMAL AS latest_a1c,
        (value IS NOT NULL)::int AS has_recent_a1c,
        ob.date AS test_date
    FROM features.cohort co
    LEFT JOIN observations ob
        ON co.patient_id = ob.patient_id
        AND co.stay_end >= ob.date
        AND ob.code = '4548-4'
    ORDER BY
        co.stay_id,
        ob.date DESC
)

SELECT
    coh.stay_id,
    act.active_conditions,
    pc.has_heart_failure,
    pc.has_diabetes,
    a1c.latest_a1c,
    a1c.has_recent_a1c
FROM features.cohort coh
JOIN active_conditions act
    ON coh.stay_id = act.stay_id
JOIN chronic_conditions pc
    ON coh.stay_id = pc.stay_id
JOIN a1c_results a1c
    ON coh.stay_id = a1c.stay_id
)
