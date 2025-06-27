# ML-Pipeline
This directory contains the ML model training pipeline for the Air Quality Monitoring and Prediction project.

## Overview
The ML model-training pipepline is containerized using Docker. All computationally inexpensive models run on AWS Fargate once every 48 hours.

Larger models will be trained on GPUs - conception is still open.

## Structure
1 . Data Ingestion -> 2. Data Quality -> 3. Data Preprocessing -> 4. Model Training-> 5. Model Validation -> 6. Model Storage

1. **Data Ingestion**: Download from S3 bucket.
2. **Data Quality**: Check for data quality issues such as missing values, duplicates, and outliers. Store analysis report as JSON on S3.
3. **Preprocess Data**: Clean and prepare the data for training. Handles missing values, outliers, and feature engineering. Store data as CSV files on S3.
4. **Model Training**: Train the model using the preprocessed data.
5. **Model Validation**: Evaluate the model's performance using metrics. Store evaluation results as JSON on S3.
6. **Model Storage**: Save the trained model to S3.
