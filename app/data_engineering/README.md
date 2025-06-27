# AIRQ Data Engineering
This directory contains the data engineering components of the AIRQ project. In regard to this project, the data enigineering service is in charge to process data already stored in the datalake S3.

## Tasks

Data Consolidation - Sensor Readings
- This task is responsible for merging the data from the datalake S3 into one CSV file.

    1. Downloads the CSV files from S3
    2. Laod new JSON files from S3 since cdv file update
    3. Add the JSON data to the CSV file
    4. Uploads the consolidated CSV file back to S3
