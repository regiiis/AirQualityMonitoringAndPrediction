"""
Secure Storage Module for ESP32 MicroPython.

This module provides secure storage functionality for WiFi credentials
using ESP32's Non-Volatile Storage (NVS). It implements best practices
for handling sensitive data including secure memory cleanup and input validation.
"""

import esp32 as nvs  # type: ignore


class SecureStorage:
    """
    Secure storage handler for WiFi credentials using ESP32 NVS.

    This class provides methods to safely store and retrieve WiFi credentials
    while implementing security best practices for handling sensitive data.

    Attributes:
        SSID_MAX_LENGTH (int): Maximum allowed length for SSID
        PASSWORD_MIN_LENGTH (int): Minimum required password length
        PASSWORD_MAX_LENGTH (int): Maximum allowed password length
        namespace (str): NVS namespace for storing credentials
    """

    SSID_MAX_LENGTH = 32
    PASSWORD_MIN_LENGTH = 8
    PASSWORD_MAX_LENGTH = 64

    def __init__(self, namespace: str = "wifi"):
        """
        Initialize secure storage with specified namespace.

        Args:
            namespace (str): NVS namespace for credential storage
        """
        self.namespace = namespace
        self._nvs = nvs.NVS(namespace)

    def _validate_credentials(self, ssid: str, password: str):
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

    def store_credentials(self, ssid: str, password: str):
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
            self._validate_credentials(ssid, password)

            # Encode credentials
            ssid_encoded = ssid.encode()
            pwd_encoded = password.encode()

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

    def get_credentials(self):
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
                self._nvs.get_blob("pwd", pwd_buffer)
            except Exception:
                print("No stored credentials found")
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

    def clear_credentials(self):
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

    def prompt_and_store_credentials(self):
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

            if self.store_credentials(ssid, password):
                print("WiFi credentials stored successfully")
                return True
            return False

        except Exception as e:
            print(f"Error in credential input: {e}")
            return False
