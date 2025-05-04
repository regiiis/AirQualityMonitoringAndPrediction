"""
Secure Storage Module for ESP32 MicroPython.

This module provides secure storage functionality for WiFi credentials and API keys
using ESP32's Non-Volatile Storage (NVS). It implements best practices
for handling sensitive data including secure memory cleanup and input validation.
"""

import esp32 as nvs  # type: ignore


class SecureStorage:
    """
    Secure storage handler for WiFi credentials and API keys using ESP32 NVS.

    This class provides methods to safely store and retrieve sensitive credentials
    while implementing security best practices for handling sensitive data.

    Attributes:
        SSID_MAX_LENGTH (int): Maximum allowed length for SSID
        PASSWORD_MIN_LENGTH (int): Minimum required password length
        PASSWORD_MAX_LENGTH (int): Maximum allowed password length
        API_KEY_LENGTH (int): Minimum required API key length
        API_ENDPOINT_LENGTH (int): Maximum allowed API key length
        namespace (str): NVS namespace for storing credentials
    """

    SSID_MAX_LENGTH = 32
    PASSWORD_MIN_LENGTH = 8
    PASSWORD_MAX_LENGTH = 64
    API_KEY_LENGTH = 40
    API_ENDPOINT_LENGTH = 84

    def __init__(self, namespace: str = "wifi"):
        """
        Initialize secure storage with specified namespace.

        Args:
            namespace (str): NVS namespace for credential storage
        """
        self.namespace = namespace
        self._nvs = nvs.NVS(namespace)

    def _validate_wifi_credentials(self, ssid: str, password: str):
        """
        Validate WiFi credentials before storage.

        Args:
            ssid (str): WiFi network name
            password (str): WiFi password

        Raises:
            ValueError: If credentials fail validation
        """
        if not isinstance(ssid, str) or not isinstance(password, str):
            raise ValueError("Credentials must be strings")

        if not ssid or len(ssid.strip()) == 0:
            raise ValueError("SSID cannot be empty")

        if len(ssid) > self.SSID_MAX_LENGTH:
            raise ValueError(f"SSID must be {self.SSID_MAX_LENGTH} characters or less")

        if len(password) < self.PASSWORD_MIN_LENGTH:
            raise ValueError(
                f"Password must be at least {self.PASSWORD_MIN_LENGTH} characters"
            )

        if len(password) > self.PASSWORD_MAX_LENGTH:
            raise ValueError(
                f"Password must be {self.PASSWORD_MAX_LENGTH} characters or less"
            )

    def _validate_api_credentials(self, api_key: str, api_endpoint: str):
        """
        Validate API key before storage.

        Args:
            api_key (str): API key to validate
            api_endpoint (str): API endpoint to validate

        Raises:
            ValueError: If credentials fails validation
        """
        # Validate API key
        if not isinstance(api_key, str):
            raise ValueError("API key must be a string")
        if not api_key or len(api_key.strip()) == 0:
            raise ValueError("API key cannot be empty")
        if len(api_key) != self.API_KEY_LENGTH:
            raise ValueError(
                f"API key must be exactly {self.API_KEY_LENGTH} characters"
            )

        # Validate API endpoint
        if not isinstance(api_endpoint, str):
            raise ValueError("API endpoint must be a string")
        if not api_endpoint or len(api_endpoint.strip()) == 0:
            raise ValueError("API endpoint cannot be empty")
        if len(api_endpoint) > self.API_ENDPOINT_LENGTH:
            raise ValueError(
                f"API endpoint must be {self.API_ENDPOINT_LENGTH} characters or less"
            )

    def _secure_clear(self, buffer: bytearray) -> None:
        """
        Securely clear sensitive data from memory.

        Args:
            buffer (bytearray): Buffer containing sensitive data

        This method overwrites the buffer with zeros to ensure
        sensitive data is not left in memory.
        """
        for i in range(len(buffer)):
            buffer[i] = 0

    def store_wifi_credentials(self, ssid: str, password: str):
        """
        Securely store WiFi credentials in NVS.

        Args:
            ssid (str): WiFi network name
            password (str): WiFi password

        Returns:
            bool: True if storage successful, False otherwise

        Raises:
            ValueError: If credentials are invalid
        """
        pwd_encoded = None
        try:
            self._validate_wifi_credentials(ssid, password)

            # Encode credentials
            ssid_encoded = ssid.encode()
            pwd_encoded = bytearray(password.encode())

            # Store in NVS
            self._nvs.set_blob("ssid", ssid_encoded)
            self._nvs.set_blob("pwd", pwd_encoded)
            self._nvs.commit()

            return True

        except ValueError as ve:
            print(f"Validation error: {ve}")
            return False
        except Exception as e:
            print(f"Storage error: {e}")
            return False
        finally:
            # Securely clear sensitive data
            if pwd_encoded:
                self._secure_clear(pwd_encoded)

    def store_api_credentials(self, api_key: str, api_endpoint: str):
        """
        Securely store API credentials in NVS.

        Args:
            api_key (str): API key for authentication
            api_endpoint (str): API endpoint for the service

        Returns:
            bool: True if storage successful, False otherwise

        Raises:
            ValueError: If API credentials are invalid
        """
        api_key_encoded = None
        try:
            self._validate_api_credentials(api_key, api_endpoint)

            # API key
            # Encode API key
            api_key_encoded = bytearray(api_key.encode())
            # Store in NVS
            self._nvs.set_blob("api_key", api_key_encoded)
            self._nvs.commit()

            # API endpoint
            # Encode API endpoint
            api_endpoint_encoded = bytearray(api_endpoint.encode())
            # Store in NVS
            self._nvs.set_blob("api_endpoint", api_endpoint_encoded)
            self._nvs.commit()

            return True

        except ValueError as ve:
            print(f"Validation error: {ve}")
            return False
        except Exception as e:
            print(f"Storage error: {e}")
            return False
        finally:
            # Securely clear sensitive data
            if api_key_encoded:
                self._secure_clear(api_key_encoded)

    def get_wifi_credentials(self):
        """
        Retrieve stored WiFi credentials from NVS.

        Returns:
            tuple: (ssid, password) if successful, (None, None) if not found or error

        Note:
            Sensitive data is securely cleared from memory after retrieval
        """
        ssid_buffer = None
        pwd_buffer = None
        try:
            ssid_buffer = bytearray(self.SSID_MAX_LENGTH)
            pwd_buffer = bytearray(self.PASSWORD_MAX_LENGTH)

            try:
                self._nvs.get_blob("ssid", ssid_buffer)
            except Exception as e:
                print(f"Error retrieving SSID: {e}")
                return None, None
            try:
                self._nvs.get_blob("pwd", pwd_buffer)
            except Exception as e:
                print(f"Error retrieving wifi password: {e}")
                return None, None

            # Extract credentials before clearing buffers
            ssid = ssid_buffer.decode().strip("\x00")
            password = pwd_buffer.decode().strip("\x00")

            # Securely clear sensitive data
            if pwd_buffer:
                self._secure_clear(pwd_buffer)

            if not ssid:
                return None, None

            return ssid, password

        except Exception as e:
            print(f"Error retrieving credentials: {e}")
            return None, None
        finally:
            # Ensure buffers are cleared even if an error occurs
            if pwd_buffer:
                self._secure_clear(pwd_buffer)

    def get_api_credentials(self):
        """
        Retrieve stored API credentials from NVS.

        Returns:
            tuple: (api_key, api_endpoint) if successful, (None, None) if not found or error
        """
        api_key_buffer = None
        api_endpoint_buffer = None
        try:
            api_key_buffer = bytearray(self.API_KEY_LENGTH)
            api_endpoint_buffer = bytearray(self.API_ENDPOINT_LENGTH)

            try:
                self._nvs.get_blob("api_key", api_key_buffer)
            except Exception as e:
                print(f"Error retrieving API key: {e}")
                return None, None
            try:
                self._nvs.get_blob("api_endpoint", api_endpoint_buffer)
            except Exception as e:
                print(f"Error retrieving API endpoint: {e}")
                return None, None

            # Extract credentials
            api_key = api_key_buffer.decode().strip("\x00")
            api_endpoint = api_endpoint_buffer.decode().strip("\x00")

            # Securely clear sensitive data
            self._secure_clear(api_key_buffer)

            if not api_key or not api_endpoint:
                return None, None

            return api_key, api_endpoint

        except Exception as e:
            print(f"Error retrieving API credentials: {e}")
            return None, None
        finally:
            # Clear buffers
            if api_key_buffer:
                self._secure_clear(api_key_buffer)
            if api_endpoint_buffer:
                self._secure_clear(api_endpoint_buffer)

    def clear_wifi_credentials(self):
        """
        Securely clear stored credentials from NVS.

        Returns:
            bool: True if cleared successfully, False otherwise
        """
        try:
            self._nvs.erase_key("ssid")
            self._nvs.erase_key("pwd")
            self._nvs.commit()
            return True
        except Exception as e:
            print(f"Error clearing credentials: {e}")
            return False

    def clear_api_credentials(self):
        """
        Securely clear stored API key from NVS.

        Returns:
            bool: True if cleared successfully, False otherwise
        """
        try:
            self._nvs.erase_key("api_key")
            self._nvs.commit()
            self._nvs.erase_key("api_endpoint")
            self._nvs.commit()
            return True
        except Exception as e:
            print(f"Error clearing API key: {e}")
            return False

    def prompt_and_store_wifi_credentials(self):
        """
        Prompt user for WiFi credentials and store them securely.

        Returns:
            bool: True if credentials were successfully stored, False otherwise

        Note:
            Provides feedback about password requirements to user
        """
        try:
            print(f"SSID must be {self.SSID_MAX_LENGTH} characters or less")
            print(
                f"Password must be between {self.PASSWORD_MIN_LENGTH} and {self.PASSWORD_MAX_LENGTH} characters"
            )

            ssid = input("Enter WiFi SSID: ").strip()
            password = input("Enter WiFi Password: ").strip()

            if self.store_wifi_credentials(ssid, password):
                print("WiFi credentials stored successfully")
                return True
            return False

        except Exception as e:
            print(f"Error in credential input: {e}")
            return False

    def prompt_and_store_api_credentials(self):
        """
        Prompt user for API credentials and store it securely.

        Returns:
            bool: True if API credentials were successfully stored, False otherwise

        Note:
            Provides feedback about API credentials requirements to user
        """
        try:
            print(f"API endpoint must be {self.API_ENDPOINT_LENGTH} characters.")
            api_endpoint = input("Enter API endpoint: ").strip()
            print(f"API key must be exactly {self.API_KEY_LENGTH} characters.")
            api_key = input("Enter API Key: ").strip()

            if self.store_api_credentials(api_key=api_key, api_endpoint=api_endpoint):
                print("API credentials stored successfully")
                return True
            return False

        except Exception as e:
            print(f"Error entering API credentials: {e}")
            return False
