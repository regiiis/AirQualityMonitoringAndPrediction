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
            input("READY TO START? Press Enter to continue...")
            print("Start main script")
            # Initialize device parameters
            self.device_id: str = "ESP32-001"
            self.location: str = "living_room"
            self.version: str = "1.0.0"
            # Initialize telecommunication parameters
            self.wlan = network.WLAN(network.STA_IF)
            self.ssid: str = None
            self.password: str = None
            self.api_endpoint: str = "https://api.example.com/v1/readings"
            self.api_key: str = "your_api_key_here"
            # Initialize system parameters
            self.sensors: dict = None
            self.colletcion_interval: int = 60  # seconds
            self.scl: int = 11
            self.sda: int = 12
            self.bat_i2c: int = 0x41
            self.pv_i2c: int = 0x45
            self.hum_and_temp_i2c: int = 0x28

        except Exception as e:
            print(f"Error initializing parameters: {e}")
            return

        ########################################################
        # Wifi setup
        ########################################################
        if not self.wlan.isconnected():
            print("Not connected to any network")
            try:
                # Create an instance of SecureStorage
                storage = SecureStorage()
                # Retrieve WiFi credentials from secure storage
                self.ssid, self.password = storage.get_credentials()
                if self.ssid and self.password:
                    # If credentials are found, try to connect to WiFi
                    print(f"Credentials found: {self.ssid}")
                    try:
                        print("Trying to connect to wifi")
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
                        storage.prompt_and_store_credentials()
                        self.ssid, self.password = storage.get_credentials()
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
                                print(f"Error trying to connect to wifi: {e}")
                        else:
                            raise Exception(
                                "Failed to get WiFi credentials from secure storage"
                            )
                    except Exception as e:
                        print(
                            f"Error trying to set credentials and connect to wifi: {e}"
                        )

            except Exception as e:
                print(f"Error in the wifi process: {e}")

        ########################################################
        # Sensor setup
        ########################################################
        try:
            # Create sensor instances
            # Battery monitoring sensor
            self.battery = (
                INA219Adapter(
                    sensor="ina219",
                    measurement="Battery",
                    i2c_address=self.bat_i2c,
                    scl=self.scl,
                    sda=self.sda,
                ),
            )
            # Solar panel monitoring sensor
            self.pv = (
                INA219Adapter(
                    sensor="ina219",
                    measurement="PV",
                    i2c_address=self.pv_i2c,
                    scl=self.scl,
                    sda=self.sda,
                ),
            )
            # Environmental sensor
            self.hum_and_temp = (
                HYT221Adapter(
                    sensor="hyt221",
                    measurement="Humidity & Temperature",
                    i2c_address=self.hum_and_temp_i2c,
                    scl=self.scl,
                    sda=self.sda,
                ),
            )

            print("All sensor instances created.")

        except Exception as e:
            print(f"Error creating sensors: {e}")

        ########################################################
        # API setup
        ########################################################
        try:
            # Create API service with contract validation
            self.api_client = ApiHttpService(
                name="AirQualityAPI", endpoint=self.api_endpoint, api_key=self.api_key
            )
            print("API client initialized successfully")
        except Exception as e:
            print(f"Error in API setup: {e}")

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
                    # Create the API payload with all collected data
                    payload = self.contract.create_sensor_payload(
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

                    # Check if we have valid measurements before sending
                    if payload and "measurements" in payload:
                        # Send API POST request
                        print("Sending API")
                        response = self.api_client.send_data(payload)

                        # Process the API response
                        if response.get("success", False):
                            print(f"API request successful: {response.get('data', {})}")
                        else:
                            print(
                                f"API request failed: {response.get('error', 'Unknown error')}"
                            )
                            if response.get("retry_suggested", False):
                                print("Will retry in next cycle")
                    else:
                        print("No valid measurements to send")
                        response = {"success": False, "error": "Invalid payload"}

                except Exception as e:
                    print(f"Error in data transmission: {e}")
                    response = {"success": False, "error": str(e)}

                # Wait before next reading
                print("Waiting for next reading cycle...")
                time.sleep(self.colletcion_interval)

            except Exception as e:
                print(f"Error in monitoring loop: {e}")
                time.sleep(5)


if __name__ == "__main__":
    main = Main()
    main.setup()
    main.main()
