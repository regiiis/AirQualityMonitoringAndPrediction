import pytest
import os
from unittest.mock import Mock, patch
from datetime import datetime

# Use absolute imports (works with conftest.py setup)
from main import FilesToCSV


class TestConsolidation:
    """Test consolidation service with mocked S3 operations"""

    def setup_method(self):
        """Setup test data and mocks before each test"""
        # Load test data files
        self.test_data_dir = os.path.join(os.path.dirname(__file__), "test_data")

        # Load existing CSV content
        with open(
            os.path.join(self.test_data_dir, "airq_consolidated_sensor_data.csv"), "r"
        ) as f:
            self.existing_csv = f.read()

        # Load JSON test files
        with open(
            os.path.join(self.test_data_dir, "airq_20250626_221612.json"), "r"
        ) as f:
            self.json1 = f.read()
        with open(
            os.path.join(self.test_data_dir, "airq_20250630_090556.json"), "r"
        ) as f:
            self.json2 = f.read()
        with open(
            os.path.join(self.test_data_dir, "airq_20250630_095811.json"), "r"
        ) as f:
            self.json3 = f.read()

    @patch.dict(
        os.environ,
        {
            "SOURCE_BUCKET_NAME": "test-bucket",
            "SENSOR_DATA_PATH": "raw-data/",
            "CONSOLIDATED_PATH": "consolidated/",
            "CONSOLIDATED_FILENAME": "airq_consolidated_sensor_data.csv",
        },
    )
    @patch("boto3.client")
    def test_incremental_consolidation_adds_new_data(self, mock_boto_client):
        """Test that new JSON files are correctly added to existing CSV"""

        # Mock S3 client
        mock_s3 = Mock()
        mock_boto_client.return_value = mock_s3

        # Mock S3 responses
        def mock_get_object(Bucket, Key):
            """Mock S3 get_object responses"""
            if Key == "consolidated/airq_consolidated_sensor_data.csv":
                # Return existing CSV
                return {
                    "Body": Mock(
                        read=Mock(return_value=self.existing_csv.encode("utf-8"))
                    )
                }
            elif Key == "raw-data/airq_20250626_221612.json":
                return {
                    "Body": Mock(read=Mock(return_value=self.json1.encode("utf-8")))
                }
            elif Key == "raw-data/airq_20250630_090556.json":
                return {
                    "Body": Mock(read=Mock(return_value=self.json2.encode("utf-8")))
                }
            elif Key == "raw-data/airq_20250630_095811.json":
                return {
                    "Body": Mock(read=Mock(return_value=self.json3.encode("utf-8")))
                }
            else:
                raise Exception(f"File not found: {Key}")

        def mock_list_objects_v2(Bucket, Prefix):
            """Mock S3 list_objects_v2 response"""
            return {
                "Contents": [
                    {
                        "Key": "raw-data/airq_20250626_221612.json",
                        "LastModified": datetime(2025, 6, 26, 22, 16, 12),
                    },
                    {
                        "Key": "raw-data/airq_20250630_090556.json",
                        "LastModified": datetime(2025, 6, 30, 9, 5, 56),
                    },
                    {
                        "Key": "raw-data/airq_20250630_095811.json",
                        "LastModified": datetime(2025, 6, 30, 9, 58, 11),
                    },
                ]
            }

        # Setup mocks
        mock_s3.get_object.side_effect = mock_get_object
        mock_s3.list_objects_v2.side_effect = mock_list_objects_v2
        mock_s3.put_object.return_value = {}

        # Initialize service
        service = FilesToCSV()

        # Run consolidation
        result = service.run_consolidation()

        # Verify success
        assert result["status"] == "success"
        assert (
            result["files_processed"] == 2
        )  # Should process 2 new files (json2 and json3)
        assert result["total_records"] == 4  # 2 existing + 2 new = 4 total

        # Verify put_object was called to store updated CSV
        assert mock_s3.put_object.called

        # Get the stored CSV content
        put_call = mock_s3.put_object.call_args
        stored_content = put_call[1]["Body"].decode("utf-8")

        # Verify the CSV contains the new data
        lines = stored_content.split("\n")

        # Should have metadata line + header + 4 data rows
        assert len([line for line in lines if line.strip()]) >= 5

        # Check that new temperature values are present
        assert "28.53" in stored_content  # From json2
        assert "28.69" in stored_content  # From json3

        # Check that new timestamps are present
        assert "804589552" in stored_content  # From json2
        assert "804592690" in stored_content  # From json3

        print("✅ Test passed: New JSON data correctly added to CSV")

    @patch.dict(
        os.environ,
        {
            "SOURCE_BUCKET_NAME": "test-bucket",
            "SENSOR_DATA_PATH": "raw-data/",
            "CONSOLIDATED_PATH": "consolidated/",
            "CONSOLIDATED_FILENAME": "airq_consolidated_sensor_data.csv",
        },
    )
    @patch("boto3.client")
    def test_initial_consolidation_creates_new_csv(self, mock_boto_client):
        """Test initial consolidation when no CSV exists"""

        # Mock S3 client
        mock_s3 = Mock()
        mock_boto_client.return_value = mock_s3

        # Mock S3 responses - no existing CSV
        def mock_get_object(Bucket, Key):
            if Key == "consolidated/airq_consolidated_sensor_data.csv":
                # Simulate file not found
                raise Exception("NoSuchKey")
            elif Key == "raw-data/airq_20250626_221612.json":
                return {
                    "Body": Mock(read=Mock(return_value=self.json1.encode("utf-8")))
                }
            elif Key == "raw-data/airq_20250630_090556.json":
                return {
                    "Body": Mock(read=Mock(return_value=self.json2.encode("utf-8")))
                }
            elif Key == "raw-data/airq_20250630_095811.json":
                return {
                    "Body": Mock(read=Mock(return_value=self.json3.encode("utf-8")))
                }

        def mock_list_objects_v2(Bucket, Prefix):
            return {
                "Contents": [
                    {"Key": "raw-data/airq_20250626_221612.json"},
                    {"Key": "raw-data/airq_20250630_090556.json"},
                    {"Key": "raw-data/airq_20250630_095811.json"},
                ]
            }

        # Setup mocks
        mock_s3.get_object.side_effect = mock_get_object
        mock_s3.list_objects_v2.side_effect = mock_list_objects_v2
        mock_s3.put_object.return_value = {}

        # Initialize service
        service = FilesToCSV()

        # Run consolidation
        result = service.run_consolidation()

        # Verify success
        assert result["status"] == "success"
        assert result["files_processed"] == 3  # All 3 files processed
        assert result["total_records"] == 3  # 3 total records

        # Get the stored CSV content
        put_call = mock_s3.put_object.call_args
        stored_content = put_call[1]["Body"].decode("utf-8")

        # Verify all data is present
        assert "27.32" in stored_content  # From json1
        assert "28.53" in stored_content  # From json2
        assert "28.69" in stored_content  # From json3

        print("✅ Test passed: Initial consolidation creates correct CSV")


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
