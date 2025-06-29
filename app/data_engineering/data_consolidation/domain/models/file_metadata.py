from dataclasses import dataclass
from datetime import datetime
from typing import Dict, Any, Optional


@dataclass
class FileMetadata:
    """Domain model for file metadata"""

    created_at: datetime
    last_entry: datetime
    description: str
    total_records: int
    columns: int
    files_processed: int
    custom_data: Optional[Dict[str, Any]] = None

    def to_dict(self) -> Dict[str, Any]:
        return {
            "date_created": int(self.created_at.timestamp()),
            "last_entry": int(self.last_entry.timestamp()),
            "data_description": self.description,
            "total_records": self.total_records,
            "columns": self.columns,
            "files_processed": self.files_processed,
            **(self.custom_data or {}),
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "FileMetadata":
        return cls(
            created_at=datetime.fromtimestamp(data.get("date_created", 0)),
            last_entry=datetime.fromtimestamp(data.get("last_entry", 0)),
            description=data.get("data_description", ""),
            total_records=data.get("total_records", 0),
            columns=data.get("columns", 0),
            files_processed=data.get("files_processed", 0),
            custom_data={
                k: v
                for k, v in data.items()
                if k
                not in [
                    "date_created",
                    "last_entry",
                    "data_description",
                    "total_records",
                    "columns",
                    "files_processed",
                ]
            },
        )


@dataclass
class ConsolidationResult:
    """Result of consolidation operation"""

    success: bool
    csv_content: str
    metadata: FileMetadata
    files_processed: int
    error_message: Optional[str] = None
