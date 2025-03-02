"""
Adapter implementation for HYT221 humidity/temperature sensor
"""

from machine import Pin, SoftI2C
import time
from data_collection.port.sensorport import I2CSensorPort


class HYT221Adapter(I2CSensorPort):
    """
    Adapter for the HYT221 humidity and temperature sensor.

    Implements the SensorPort interface, adapting the HYT221 sensor functions
    to the common interface.
    """

    def __init__(self, name, i2c_address, scl, sda):
        """
        Initialize the HYT221 sensor adapter.

        Args:
            name: A descriptive name for this sensor instance
            i2c_address: The I2C address of the sensor (default is 0x28)
            scl: The pin number for the I2C clock line
            sda: The pin number for the I2C data line
        """
        self._name = name
        self._i2c_address = i2c_address
        self._scl = scl
        self._sda = sda

    @property
    def name(self) -> str:
        return self._name

    @property
    def i2c_address(self) -> int:
        return self._i2c_address

    @property
    def scl(self) -> int:
        return self._scl

    @property
    def sda(self) -> int:
        return self._sda

    def is_ready(self) -> bool:
        """Check if the sensor is available on the I2C bus"""
        try:
            i2c = SoftI2C(scl=Pin(self._scl), sda=Pin(self._sda))
            devices = i2c.scan()
            return self._i2c_address in devices
        except Exception:
            return False

    def read(self):
        """
        Read humidity and temperature from the HYT221 sensor

        Returns:
            Dict with humidity and temperature readings
        """
        try:
            self._i2c = SoftI2C(scl=Pin(self._scl), sda=Pin(self._sda))

            # Trigger a measurement
            self._i2c.writeto(self._i2c_address, b"\x00")
            time.sleep(0.1)  # Wait for the measurement to complete

            # Read 4 bytes of data
            data = self._i2c.readfrom(self._i2c_address, 4)

            # Parse the data
            humidity = ((data[0] & 0x3F) << 8) | data[1]
            temperature = (data[2] << 6) | (data[3] >> 2)

            # Convert to human-readable values
            humidity = humidity * 100 / 16383.0
            temperature = temperature * 165 / 16383.0 - 40

            return {
                "humidity": humidity,
                "temperature": temperature,
                "units": {"humidity": "%", "temperature": "°C"},
            }
        except Exception as e:
            print(f"Error reading HYT221 sensor: {e}")
            return {"error": str(e)}
