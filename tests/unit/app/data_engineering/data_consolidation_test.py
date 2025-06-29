"""
Unit tests for Data Consolidation Adapter functionality
"""

from app.data_engineering.data_consolidation.modules.files_to_csv_adapter import (
    FilesToCsvAdapter,
)


class TestFilesToCsvAdapter:
    """Test suite for FilesToCsvAdapter"""

    def test_load_json_file():
        """Test loading a JSON file"""
        adapter = FilesToCsvAdapter()
        data = adapter.load_json_file(
            "tests/unit/app/data_engineering/test_data/airq_20250627_080448.json"
        )
        assert isinstance(data, dict)
        assert "measurements" in data
