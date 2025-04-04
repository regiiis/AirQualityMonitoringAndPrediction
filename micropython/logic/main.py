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
from data_transmission.adapter.api_http_adapter import ApiHttpAdapter  # type: ignore
from data_transmission.adapter.api_contract_adapter import ApiContractAdapter  # type: ignore


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
    try:
        # Initialize system parameters
        input("READY TO START? Press Enter to continue...")
        print("Start main script")
        # Initialize device parameters
        device_id: str = "ESP32-001"
        location: str = "living_room"
        version: str = "1.0.0"
        # Initialize telecommunication parameters
        wlan = network.WLAN(network.STA_IF)
        ssid: str = None
        password: str = None
        api_endpoint: str = "https://api.example.com/v1/readings"
        api_key: str = "your_api_key_here"
        # Initialize system parameters
        sensors: dict = None
        colletcion_interval: int = 10  # seconds
        scl: int = 11
        sda: int = 12

    except Exception as e:
        print(f"Error initializing parameters: {e}")
        return

    ########################################################
    # Wifi setup
    ########################################################
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

    ########################################################
    # Sensor setup
    ########################################################
    try:
        # Create sensor instances
        sensors = [
            # Battery monitoring sensor
            INA219Adapter(
                sensor="ina219",
                measurement="Battery",
                i2c_address=0x41,
                scl=scl,
                sda=sda,
            ),
            # Solar panel monitoring sensor
            INA219Adapter(
                sensor="ina219",
                measurement="PV Panel",
                i2c_address=0x45,
                scl=scl,
                sda=sda,
            ),
            # Environmental sensor
            HYT221Adapter(
                sensor="hyt221",
                measurement="Humidity & Temperature",
                i2c_address=0x28,
                scl=scl,
                sda=sda,
            ),
        ]

        print(f"Created {len(sensors)} sensor instances")

    except Exception as e:
        print(f"Error creating sensors: {e}")
        sensors = []

    ########################################################
    # API setup
    ########################################################
    try:
        # Create contract adapter for payload creation
        contract = ApiContractAdapter()

        # Create HTTP adapter with contract validation
        api_client = ApiHttpAdapter(
            name="AirQualityAPI", endpoint=api_endpoint, api_key=api_key
        )
    except Exception as e:
        print(f"Error in API setup: {e}")

    ########################################################
    # Main loop
    ########################################################
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

                    # # Method 2: Read and process data manually
                    # readings = sensor.read()

                    # # Example of accessing specific values
                    # if "voltage" in readings and sensor.sensor == "Battery":
                    #     voltage = readings["voltage"]
                    #     if voltage < 3.3:
                    #         print(f"WARNING: Battery voltage low ({voltage}V)")

                    # if "humidity" in readings:
                    #     humidity = readings["humidity"]
                    #     if humidity > 80:
                    #         print(f"WARNING: High humidity ({humidity}%)")
                else:
                    print(f"Warning: Sensor '{sensor.sensor}' is not ready")

            ################################################
            # Data transmission
            ################################################
            try:
                # Collect data from all sensors
                temperature = None
                humidity = None
                voltage = {}
                current = {}

                # Extract readings from each sensor
                for sensor in sensors:
                    if not sensor.is_ready():
                        continue

                    readings = sensor.read()

                    # HYT221 sensor provides temperature and humidity
                    if sensor.measurement == "Humidity & Temperature":
                        temperature = readings.get("temperature")
                        humidity = readings.get("humidity")

                    # INA219 sensors provide voltage and current
                    elif sensor.measurement == "Battery":
                        voltage["battery"] = readings.get("voltage")
                        current["battery"] = readings.get("current")

                    elif sensor.measurement == "PV Panel":
                        voltage["solar"] = readings.get("voltage")
                        current["solar"] = readings.get("current")

                # Create the API payload with all collected data
                sensor_data = contract.create_sensor_payload(
                    device_id=device_id,
                    timestamp=int(time.time()),
                    temperature=temperature,
                    humidity=humidity,
                    voltage=voltage,  # Dictionary with multiple voltage sources
                    current=current,  # Dictionary with multiple current sources
                    metadata={
                        "location": location,
                        "version": version,
                        "battery_percent": readings.get("battery_percent", 0)
                        if "battery_percent" in readings
                        else None,
                    },
                )

                # Check if we have any measurements before sending
                if sensor_data["measurements"]:
                    print(f"Sending data: {sensor_data}")
                    response = api_client.send_data(sensor_data)
                    print(f"API response: {response}")
                else:
                    print("No measurements to send")

            except Exception as e:
                print(f"Error in data transmission: {e}")
                response = {"success": False, "error": str(e)}

            # Wait before next reading
            print("Waiting for next reading cycle...")
            time.sleep(colletcion_interval)

        except Exception as e:
            print(f"Error in monitoring loop: {e}")
            time.sleep(5)


if __name__ == "__main__":
    main()
