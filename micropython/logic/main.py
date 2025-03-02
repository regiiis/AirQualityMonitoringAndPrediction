"""
Main script for ESP32 Air Quality Monitoring System.

This module handles the main execution flow including:
- WiFi connection management
- Secure storage for credentials
- Network status monitoring
"""

import time
import network  # type: ignore
from modules.secure_storage import SecureStorage  # type: ignore
from modules.wifi import connect_wifi  # type: ignore
from data_collection.adapter.hyt221 import HYT221Adapter  # type: ignore
from data_collection.adapter.ina219 import INA219Adapter  # type: ignore


def main():
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
    input("READY TO START? Press Enter to continue...")
    print("Start main script")

    # Initialize system parameters
    wlan = network.WLAN(network.STA_IF)
    ssid = None
    password = None
    scl = 11
    sda = 12
    sensors = []

    # Wifi setup
    if not wlan.isconnected():
        print("Not connected to any network")
        try:
            # Create an instance of SecureStorage
            storage = SecureStorage()
            # Retrieve WiFi credentials from secure storage
            ssid, password = storage.get_credentials()
            if ssid and password:
                # If credentials are found, try to connect to WiFi
                print(f"Credentials found: {ssid}")
                try:
                    print("Trying to connect to wifi")
                    wlan, ssid = connect_wifi(ssid, password)
                    time.sleep(3)
                    if not wlan.isconnected():
                        raise Exception("Failed to get WiFi connection details")
                except Exception as e:
                    print(f"Error: {e}")
            else:
                # If credentials are not found, prompt user to enter them trying to connect to wifi
                print("WiFi credentials not found in secure storage")
                try:
                    # Prompt user to enter WiFi credentials
                    storage.prompt_and_store_credentials()
                    ssid, password = storage.get_credentials()
                    if ssid and password:
                        try:
                            # If credentials are found, try to connect to WiFi
                            wlan, ssid = connect_wifi(ssid, password)
                            time.sleep(3)
                            if not wlan.isconnected():
                                raise Exception("Failed to get WiFi connection details")
                        except Exception as e:
                            print(f"Error trying to connect to wifi: {e}")
                    else:
                        raise Exception(
                            "Failed to get WiFi credentials from secure storage"
                        )
                except Exception as e:
                    print(f"Error trying to set credentials and connect to wifi: {e}")

        except Exception as e:
            print(f"Error in the wifi process: {e}")

    # Intantiate sensors
    try:
        # Create sensor instances
        sensors = [
            # Battery monitoring sensor
            INA219Adapter("ina219", name="Battery", i2c_address=0x41, scl=scl, sda=sda),
            # Solar panel monitoring sensor
            INA219Adapter(
                "ina219", name="PV Panel", i2c_address=0x45, scl=scl, sda=sda
            ),
            # Environmental sensor
            HYT221Adapter(
                "hyt221",
                name="Humidity & Temperature",
                i2c_address=0x28,
                scl=scl,
                sda=sda,
            ),
        ]

        print(f"Created {len(sensors)} sensor instances")

    except Exception as e:
        print(f"Error creating sensors: {e}")
        sensors = []

    # Main monitoring loop
    while True:
        try:
            print("\n--- Starting monitoring cycle ---")

            # Display WiFi status
            if wlan.isconnected():
                print(f"Connected to: {ssid}")
            else:
                print("Not connected to any network")

            # Read and display sensor data
            for sensor in sensors:
                if sensor.is_ready():
                    # Method 1: Use the built-in print method
                    sensor.print()

                    # Method 2: Read and process data manually
                    readings = sensor.read()

                    # Example of accessing specific values
                    if "voltage" in readings and sensor.name == "Battery":
                        voltage = readings["voltage"]
                        if voltage < 3.3:
                            print(f"WARNING: Battery voltage low ({voltage}V)")

                    if "humidity" in readings:
                        humidity = readings["humidity"]
                        if humidity > 80:
                            print(f"WARNING: High humidity ({humidity}%)")
                else:
                    print(f"Warning: Sensor '{sensor.name}' is not ready")

            # Wait before next reading
            print("Waiting for next reading cycle...")
            time.sleep(5)

        except Exception as e:
            print(f"Error in monitoring loop: {e}")
            time.sleep(5)


if __name__ == "__main__":
    main()
