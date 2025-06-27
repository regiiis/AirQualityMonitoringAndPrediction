from files_to_csv_adapter import FilesToCSVAdapter


class FilesToCSV:
    def __init__(self, db_name, file_name):
        self.adapter = FilesToCSVAdapter(db_name, file_name)

    try:

        def get_file(self, file_name):
            return self.adapter.get_file(file_name)

        def get_metadata(self, file_name):
            return self.adapter.get_metadata(file_name)

        def update_metadata(self, file_name, metadata):
            return self.adapter.update_metadata(file_name, metadata)

        def get_new_files(self, prefix, metadata):
            return self.adapter.get_new_files(prefix, metadata)

        def consolidate_files(self, file_names):
            return self.adapter.consolidate_files(file_names)

        def store_consolidated_file(self, file_name, bucket_name):
            return self.adapter.store_consolidated_file(file_name, bucket_name)

    except Exception as e:
        print(f"An error occurred in FilesToCSV: {str(e)}")
        raise e
