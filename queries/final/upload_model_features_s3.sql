SELECT * FROM aws_s3.query_export_to_s3(
    'SELECT * FROM model_features',
    aws_commons.create_s3_uri(
            'readmission-prediction-synthea-data-811136281995-us-east-2-an',
            'synthea_data_for_readmission_prediction/processed/model_ready/year=2026/month=07/model_features.csv',
            'us-east-2'
    ),
    options := 'format csv, HEADER true'
);