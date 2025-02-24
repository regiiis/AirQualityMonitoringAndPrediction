import esp32 as nvs  # type: ignore


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
            self._nvs.set_blob("ssid", ssid.encode())
            self._nvs.set_blob("pwd", password.encode())
            self._nvs.commit()  # Write to flash memory
            return True
        except Exception as e:
            print(f"Error storing credentials: {e}")
            return False

    def get_credentials(self):
        try:
            # Retrieve bytes from NVS flash and convert back to strings
            ssid_buffer = bytearray(32)  # Assuming max length of SSID is 32 bytes
            pwd_buffer = bytearray(64)  # Assuming max length of password is 64 bytes
            self._nvs.get_blob("ssid", ssid_buffer)
            self._nvs.get_blob("pwd", pwd_buffer)
            ssid = ssid_buffer.decode().strip("\x00")
            password = pwd_buffer.decode().strip("\x00")
            print(f"Retrieved credentials: {ssid}")
            return ssid, password
        except Exception as e:
            print(f"Error retreiving credentials: {e}")
            return None, None

    def prompt_and_store_credentials(self):
        try:
            ssid = input("Enter WiFi SSID: ")
            password = input("Enter WiFi Password: ")
            self.store_credentials(ssid, password)
            print("WiFi credentials stored successfully.")
        except Exception as e:
            print(f"Error prompting and storing credentials: {e}")
