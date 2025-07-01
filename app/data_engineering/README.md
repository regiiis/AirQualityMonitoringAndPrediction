# AIRQ Data Engineering
This directory contains the data engineering components of the AIRQ project. In regard to this project, the data enigineering service is in charge to process data already stored in the datalake S3.

## Tasks

## Data Consolidation - Sensor Readings to CSV File
This task merges JSON sensor data from the datalake S3 into a consolidation CSV file.

**High-Level Features**
Adapter
    1.  a. Downloads CSV file from S3 bucket.

Domain
    2.  a. Get last entry date from metadata.
        b. List all JSON file newer than the last entrty date.
        c. Download all JSON files.
        d. Flatten JSON data.
        e. Generate CSV header for flatten data.
        f. Check if headers match, otherwise update CSV header.
        g. Append flatten JSON data to CSV file.
        h. Update metadata with last entry date.

Adapter
    3. a. Upload consolidated CSV file to S3 bucket.

### **Environment Variables**
```bash
SOURCE_BUCKET_NAME=your-s3-bucket-name
CONSOLIDATED_FILE_NAME=consolidated_sensor_data.csv
```

### **File Structure**
```
data_consolidation
├── adapters
│   ├── json_processor_adapter.py
│   └── s3_storage_adapter.py
├── Dockerfile
├── domain
│   ├── consolidation_service.py
│   └── models
│       └── file_metadata.py
├── __init__.py
├── main.py
├── modules
│   ├── files_to_csv_adapter.py
│   ├── files_to_csv_port.py
│   └── __init__.py
├── ports
│   ├── file_storage_port.py
│   └── json_processor_port.py
├── requirements.txt
└── tests
    └── __init__.py
```
