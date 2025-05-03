"""
Main script for ESP32 Air Quality Monitoring System.

This module handles the main execution flow including:
- One-time sensor module setup
-- WIFI setup
-- Sensor setup
-- API setup
- Main Loop
-- Data collection
-- Data transmission
"""

import time
import network  # type: ignore
from modules.secure_storage import SecureStorage  # type: ignore
from modules.wifi import connect_wifi  # type: ignore
from data_collection.adapter.hyt221 import HYT221Adapter  # type: ignore
from data_collection.adapter.ina219 import INA219Adapter  # type: ignore
from data_transmission.service.api_http_service import ApiHttpService  # type: ignore


class Main:
    def setup(self):
        """
        Main execution function for the ESP32 Air Quality Monitoring System.

        This function performs the following tasks:
        1. Initializes the WiFi interface
        2. Attempts to retrieve stored WiFi credentials
        3. Connects to WiFi using stored or user-provided credentials
        4. Monitors the WiFi connection status

        Raises:
            Exception: For various WiFi-related errors including connection failures
                    and credential management issues
        """
        try:
            # Initialize system parameters
            print("GET TO START SETUP")
            time.sleep(3)
            print("Start setup script")
            # Initialize device parameters
            self.device_id: str = "ESP32-001"
            self.location: str = "living_room"
            self.version: str = "1.0.0"
            # Initialize telecommunication parameters
            self.wlan = network.WLAN(network.STA_IF)
            self.storage = SecureStorage()
            self.ssid: str = None
            self.password: str = None
            self.api_endpoint: str = "https://wojr2kkcnf.execute-api.eu-central-1.amazonaws.com/v1/data-ingestion/readings"
            self.api_key: str = None
            # Initialize system parameters
            self.sensors: dict = None
            self.collection_interval: int = 60  # seconds
            self.scl: int = 11
            self.sda: int = 12
            self.bat_i2c: int = 0x41
            self.pv_i2c: int = 0x45
            self.hum_and_temp_i2c: int = 0x28

        except Exception as e:
            print(f"Error initializing parameters: {e}")
            return

        ########################################################
        # WiFi setup
        ########################################################
        if not self.wlan.isconnected():
            print("Not connected to any network")
            try:
                try:
                    # Retrieve WiFi credentials from secure storage
                    self.ssid, self.password = self.storage.get_credentials()
                except Exception as e:
                    print(f"Failed to retrieve WiFi credentials: {e}")
                if self.ssid and self.password:
                    # If credentials are found, try to connect to WiFi
                    print(f"Credentials found: {self.ssid}")
                    try:
                        print("Trying to connect to Wifi")
                        self.wlan, self.ssid = connect_wifi(self.ssid, self.password)
                        time.sleep(3)
                        if not self.wlan.isconnected():
                            raise Exception("Failed to get WiFi connection details")
                    except Exception as e:
                        print(f"Error: {e}")
                else:
                    # If credentials are not found, prompt user to enter them trying to connect to wifi
                    print("WiFi credentials not found in secure storage")
                    try:
                        # Prompt user to enter WiFi credentials
                        try:
                            self.storage.prompt_and_store_credentials()
                        except Exception as e:
                            print(f"Failed to store WiFi Credentials: {e}")
                        try:
                            self.ssid, self.password = self.storage.get_credentials()
                        except Exception as e:
                            print(f"Failed to retrieve WiFi credetnials: {e}")
                        if self.ssid and self.password:
                            try:
                                # If credentials are found, try to connect to WiFi
                                self.wlan, self.ssid = connect_wifi(
                                    self.ssid, self.password
                                )
                                time.sleep(3)
                                if not self.wlan.isconnected():
                                    raise Exception(
                                        "Failed to get WiFi connection details"
                                    )
                            except Exception as e:
                                print(f"Error trying to connect to WiFi: {e}")
                        else:
                            raise Exception(
                                "Failed to get WiFi credentials from secure storage"
                            )
                    except Exception as e:
                        print(
                            f"Error trying to set credentials and connect to WiFi: {e}"
                        )

            except Exception as e:
                print(f"Error in the WiFi process: {e}")

        ########################################################
        # API setup
        ########################################################

        if not self.api_key:
            try:
                # Try to get API key
                self.api_key = self.storage.get_api_key()
                if self.api_key:
                    print(f"API key found: {self.api_key}")
                else:
                    try:
                        # Try to store API key
                        print("API key not stored")
                        self.storage.prompt_and_store_api_key()
                    except Exception:
                        print("Failed to store API Key")
                    try:
                        self.api_key = self.storage.get_api_key()
                    except Exception as e:
                        print(f"Failed to store API key: {e}")
                    if not self.api_key:
                        raise Exception("Failed to retrieve API key")
            except Exception as e:
                print(f"Failed to handle API key: {e}")

        try:
            # Create API service with contract validation
            self.api_client = ApiHttpService(
                name="AirQualityAPI", endpoint=self.api_endpoint, api_key=self.api_key
            )
            print("API client initialized successfully")

            # Test API connection
            print("Testing API connection...")
            connection_test_result = self.api_client.test_connection()
            if connection_test_result:
                print("✅ API connection test successful!")
            else:
                print("❌ API connection test failed. Check endpoint and API key.")

        except Exception as e:
            print(f"Error in API setup: {e}")

        ########################################################
        # Sensor setup
        ########################################################
        try:
            # Create sensor instances
            # Battery monitoring sensor
            self.battery = INA219Adapter(
                sensor="ina219",
                measurement="Battery",
                i2c_address=self.bat_i2c,
                scl=self.scl,
                sda=self.sda,
            )
            # Solar panel monitoring sensor
            self.pv = INA219Adapter(
                sensor="ina219",
                measurement="PV",
                i2c_address=self.pv_i2c,
                scl=self.scl,
                sda=self.sda,
            )
            # Environmental sensor
            self.hum_and_temp = HYT221Adapter(
                sensor="hyt221",
                measurement="Humidity & Temperature",
                i2c_address=self.hum_and_temp_i2c,
                scl=self.scl,
                sda=self.sda,
            )

            print("All sensor instances created.")

        except Exception as e:
            print(f"Error creating sensors: {e}")

    def main(self):
        ########################################################
        # Main loop
        ########################################################
        while True:
            try:
                print("\n--- Starting monitoring cycle ---")

                # Display WiFi status
                if self.wlan.isconnected():
                    print(f"Connected to: {self.ssid}")
                else:
                    print("Not connected to any network")
                    if self.ssid and self.password:
                        # If credentials are found, try to connect to WiFi
                        print(f"Credentials found: {self.ssid}")
                        try:
                            print("Trying to connect to Wifi")
                            self.wlan, self.ssid = connect_wifi(
                                self.ssid, self.password
                            )
                            time.sleep(3)
                            if self.wlan.isconnected():
                                print(f"Connected to: {self.ssid}")
                            else:
                                print("Not connected to any network")
                                break
                        except Exception as e:
                            print(f"Error: {e}")
                    else:
                        print("Missing WiFi credentials!")

                ########################################################
                # Data collection
                ########################################################
                sleep = 0.25
                try:
                    for i in range(3):
                        if self.battery.is_ready():
                            battery_data = self.battery.read()
                            break
                        time.sleep(sleep)
                    else:
                        battery_data = {"measurements": {"error"}}
                except Exception:
                    raise

                try:
                    for i in range(3):
                        if self.pv.is_ready():
                            pv_data = self.pv.read()
                            break
                        time.sleep(sleep)
                    else:
                        pv_data = {"measurements": {"error"}}
                except Exception:
                    raise

                try:
                    for i in range(3):
                        if self.hum_and_temp.is_ready():
                            hnt_data = self.hum_and_temp.read()
                            break
                        time.sleep(sleep)
                    else:
                        hnt_data = {"measurements": {"error"}}
                except Exception:
                    raise

                ################################################
                # Data transmission
                ################################################
                try:
                    # Send API POST request
                    print("Build and send API Request")
                    response = self.api_client.send_data(
                        hyt221=hnt_data,
                        ina219_1=battery_data,
                        ina219_2=pv_data,
                        metadata={
                            "device_id": self.device_id,
                            "timestamp": int(time.time()),
                            "location": self.location,
                            "version": self.version,
                        },
                    )

                    # Process the API response
                    if response.get("success", False):
                        print(f"API request successful: {response.get('data', {})}")
                    else:
                        error_msg = response.get("error", "Unknown error")
                        status = response.get("status_code", "n/a")
                        print(f"API request failed ({status}): {error_msg}")

                except Exception as e:
                    print(f"Error in data transmission: {e}")
                    # Short delay after errors to prevent rapid retries
                    time.sleep(5)

                # Always wait between cycles, regardless of success/failure
                print(
                    f"Waiting {self.collection_interval} seconds before next reading cycle..."
                )
                time.sleep(self.collection_interval)

            except Exception as e:
                print(f"Error during main loop: {e}")
                time.sleep(5)


if __name__ == "__main__":
    while True:
        try:
            main = Main()
            main.setup()
            main.main()
        except Exception as e:
            print(f"Fatal error: {e}")
            time.sleep(60)
            print("Restarting application...")
