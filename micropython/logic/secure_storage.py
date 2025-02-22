import esp
import esp32 as nvs


class SecureStorage:
    def __init__(self, namespace="wifi"):
        # Create or open a namespace in NVS flash memory
        # Think of namespace as a "folder" in the ESP32's permanent storage
        self.namespace = namespace
        self._nvs = nvs.NVS(namespace)

    def store_credentials(self, ssid, password):
        try:
            # Convert strings to bytes and store in NVS flash
            # This data persists even when ESP32 is powered off
            # set_blob stores binary data in the specified namespace
            self._nvs.set_blob("ssid", ssid.encode())  # Store under 'ssid' key
            self._nvs.set_blob("pwd", password.encode())  # Store under 'pwd' key
            self._nvs.commit()  # Write to flash memory
            return True
        except Exception as e:
            print(f"Error storing credentials: {e}")
            return False

    def get_credentials(self):
        try:
            # Retrieve bytes from NVS flash and convert back to strings
            ssid = self._nvs.get_blob("ssid").decode()
            password = self._nvs.get_blob("pwd").decode()
            return ssid, password
        except Exception as e:
            print(f"Error retreiving credentials: {e}")
            return None, None

    @staticmethod
    def print_storage_info():
        """Print information about NVS storage"""
        try:
            # Get NVS partition info
            partition = esp.nvs_get_info()
            print("NVS Storage Info:")
            print(f"Total size: {partition['total_size']} bytes")
            print(f"Used size: {partition['used_size']} bytes")
            print(
                f"Free size: {partition['total_size'] - partition['used_size']} bytes"
            )
            return True
        except Exception as e:
            print("Error getting NVS storage info:", e)
            return False
