"""
Main script for ESP32 Air Quality Monitoring System.

This module handles the main execution flow including:
- WiFi connection management
- Secure storage for credentials
- Network status monitoring
"""

import time
import network  # type: ignore
from secure_storage import SecureStorage  # type: ignore
from wifi import connect_wifi  # type: ignore
from ina219_sensor import read_ina219  # type: ignore
from hyt221_sensor import HYT221  # type: ignore


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
    # Initialize wlan
    wlan = network.WLAN(network.STA_IF)
    ssid = None
    password = None
    scl = 11
    sda = 12

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

    # Main monitoring loop
    while True:
        try:
            print("Starting WiFi monitoring...")
            while True:
                if wlan.isconnected():
                    print(f"Connected to: {ssid}")
                else:
                    print("Not connected to any network")
                read_ina219(scl=scl, sda=sda, I2C_ADDRESS=0x41, sensor_name="Battery")
                read_ina219(scl=scl, sda=sda, I2C_ADDRESS=0x45, sensor_name="PV Panel")
                HYT221(scl=scl, sda=sda, freq=100000, address=0x28).print()
                time.sleep(5)

        except Exception as e:
            print(f"Error: {e}")
            time.sleep(5)


if __name__ == "__main__":
    main()
