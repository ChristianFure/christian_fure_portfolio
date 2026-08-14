-- Creating staging tables and inserting the data from the raw CSV files into them.

-- Patients Table
CREATE TABLE patients (
    id                   UUID PRIMARY KEY,
    birthdate            DATE,
    death_date           DATE,
    ssn                  TEXT,
    drivers              TEXT,
    passport             TEXT,
    prefix               TEXT,
    first_name           TEXT,
    middle_name          TEXT,
    last_name            TEXT,
    suffix               TEXT,
    maiden               TEXT,
    marital              CHAR(1),
    race                 TEXT,
    ethnicity            TEXT,
    gender               CHAR(1),
    birthplace           TEXT,
    address              TEXT,
    city                 TEXT,
    state                TEXT,
    county               TEXT,
    fips                 TEXT,
    zip                  TEXT,
    lat                  DECIMAL,
    lon                  DECIMAL,
    healthcare_expenses  DECIMAL,
    healthcare_coverage  DECIMAL,
    income               DECIMAL
);

SELECT aws_s3.table_import_from_s3(
    'patients',
    '',
    '(format csv, header true)',
    aws_commons.create_s3_uri(
        'READMISSION_S3_BUCKET',
        'synthea_data_for_readmission_prediction/raw/patients.csv',
        'us-east-2'
    )
);

-- Encounters Table
CREATE TEMP TABLE encounters_staging (
    id                  UUID,
    start_date          DATE,
    stop_date           DATE,
    patient_id          UUID,
    organization_id     TEXT,
    provider_id         TEXT,
    payer_id            TEXT,
    encounter_class     TEXT,
    code                TEXT,
    description         TEXT,
    base_encounter_cost DECIMAL,
    total_claim_cost    DECIMAL,
    payer_coverage      DECIMAL,
    reason_code         TEXT,
    reason_description  TEXT
);

SELECT aws_s3.table_import_from_s3(
    'encounters_staging',
    '',
    '(format csv, header true)',
    aws_commons.create_s3_uri(
        'READMISSION_S3_BUCKET',
        'synthea_data_for_readmission_prediction/raw/encounters.csv',
        'us-east-2'
    )
);

CREATE TABLE encounters (
    id                  UUID PRIMARY KEY,
    start_date          DATE,
    stop_date           DATE,
    patient_id          UUID REFERENCES  patients(id) ON DELETE CASCADE,
    encounter_class     TEXT,
    code                TEXT,
    description         TEXT,
    base_encounter_cost DECIMAL,
    total_claim_cost    DECIMAL,
    payer_coverage      DECIMAL,
    reason_code         TEXT,
    reason_description  TEXT
);

INSERT INTO encounters (
        id,
        start_date,
        stop_date,
        patient_id,
        encounter_class,
        code,
        description,
        base_encounter_cost,
        total_claim_cost,
        payer_coverage,
        reason_code,
        reason_description
)
SELECT
    id,
    start_date,
    stop_date,
    patient_id,
    encounter_class,
    code,
    description,
    base_encounter_cost,
    total_claim_cost,
    payer_coverage,
    reason_code,
    reason_description
FROM encounters_staging;

-- Conditions Table
CREATE TEMP TABLE conditions_staging (
    start_date          DATE,
    stop_date           DATE,
    patient_id          UUID,
    encounter_id        UUID,
    system              TEXT,
    code                TEXT,
    description         TEXT
);

SELECT aws_s3.table_import_from_s3(
    'conditions_staging',
    '',
    '(format csv, header true)',
    aws_commons.create_s3_uri(
        'READMISSION_S3_BUCKET',
        'synthea_data_for_readmission_prediction/raw/conditions.csv',
        'us-east-2'
    )
);

CREATE TABLE conditions (
    id                  SERIAL PRIMARY KEY ,
    start_date          DATE,
    stop_date           DATE,
    patient_id          UUID REFERENCES patients(id) ON DELETE CASCADE,
    encounter_id        UUID REFERENCES encounters(id) ON DELETE CASCADE,
    system              TEXT,
    code                TEXT,
    description         TEXT
);

INSERT INTO conditions (
        start_date,
        stop_date,
        patient_id,
        encounter_id,
        system,
        code,
        description
)
SELECT
    start_date,
    stop_date,
    patient_id,
    encounter_id,
    system,
    code,
    description
FROM conditions_staging;


-- Careplans Table
CREATE TABLE careplans (
    id                  UUID PRIMARY KEY,
    start_date          DATE,
    stop_date           DATE,
    patient_id          UUID REFERENCES patients(id) ON DELETE CASCADE,
    encounter_id        UUID REFERENCES encounters(id) ON DELETE CASCADE,
    code                TEXT,
    description         TEXT,
    reason_code         TEXT,
    reason_description  TEXT
);

SELECT aws_s3.table_import_from_s3(
    'careplans',
    '',
    '(format csv, header true)',
    aws_commons.create_s3_uri(
        'READMISSION_S3_BUCKET',
        'synthea_data_for_readmission_prediction/raw/careplans.csv',
        'us-east-2'
    )
);

-- Medications Table
CREATE TEMP TABLE medications_staging (
    start_date          DATE,
    stop_date           DATE,
    patient_id          UUID,
    payer_id            TEXT,
    encounter_id        UUID,
    code                TEXT,
    description         TEXT,
    base_cost           DECIMAL,
    payer_coverage      DECIMAL,
    dispenses           INT,
    total_cost          DECIMAL,
    reason_code         TEXT,
    reason_description  TEXT
);

SELECT aws_s3.table_import_from_s3(
    'medications_staging',
    '',
    '(format csv, header true)',
    aws_commons.create_s3_uri(
        'READMISSION_S3_BUCKET',
        'synthea_data_for_readmission_prediction/raw/medications.csv',
        'us-east-2'
    )
);

CREATE TABLE medications (
    id                  SERIAL PRIMARY KEY ,
    start_date          DATE,
    stop_date           DATE,
    patient_id          UUID REFERENCES patients(id) ON DELETE CASCADE,
    encounter_id        UUID REFERENCES encounters(id) ON DELETE CASCADE,
    code                TEXT,
    description         TEXT,
    base_cost           DECIMAL,
    payer_coverage      DECIMAL,
    dispenses           INT,
    total_cost          DECIMAL,
    reason_code         TEXT,
    reason_description  TEXT
);

INSERT INTO medications (
    start_date,
    stop_date,
    patient_id,
    encounter_id,
    code,
    description,
    base_cost,
    payer_coverage,
    dispenses,
    total_cost,
    reason_code,
    reason_description
)
SELECT
    start_date,
    stop_date,
    patient_id,
    encounter_id,
    code,
    description,
    base_cost,
    payer_coverage,
    dispenses,
    total_cost,
    reason_code,
    reason_description
FROM medications_staging;

-- Observations Table
CREATE TABLE observations (
    date                DATE,
    patient_id          UUID REFERENCES patients(id) ON DELETE CASCADE,
    encounter_id        UUID REFERENCES encounters(id) ON DELETE CASCADE,
    category            TEXT,
    code                TEXT,
    description         TEXT,
    value               TEXT,
    units               TEXT,
    type                TEXT
);

SELECT aws_s3.table_import_from_s3(
    'observations',
    '',
    '(format csv, header true)',
    aws_commons.create_s3_uri(
        'READMISSION_S3_BUCKET',
        'synthea_data_for_readmission_prediction/raw/observations.csv',
        'us-east-2'
    )
);
