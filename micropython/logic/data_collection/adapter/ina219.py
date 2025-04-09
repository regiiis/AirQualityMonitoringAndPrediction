"""
Adapter implementation for INA219 current/voltage sensor

This module provides an adapter for the INA219 current, voltage and power monitoring sensor
that implements the I2CSensorPort interface, allowing it to be used within
the application's port-adapter architecture.
"""

from machine import Pin, SoftI2C  # type: ignore
from ina219 import INA219  # type: ignore
import logging

try:
    from data_collection.port.sensorport import I2CSensorPort  # type: ignore
except ImportError:
    from micropython.logic.data_collection.port.sensorport import I2CSensorPort  # type: ignore


class CustomINA219(INA219):
    """
    A customized INA219 implementation to fix compatibility issues with MicroPython.

    This class overrides specific methods from the original INA219 library
    to ensure proper operation on MicroPython environments with limited resources.
    """

    def __log_register_operation(self, msg, register, value):
        # performance optimisation
        if self._log.isEnabledFor(logging.DEBUG):
            binary = "{0:#018b}".format(value)
            self._log.debug(
                "%s register 0x%02x: 0x%04x %s", msg, register, value, binary
            )


class INA219Adapter(I2CSensorPort):
    """
    Adapter for the INA219 voltage, current and power measurement sensor.

    This adapter provides a standardized interface to the INA219 sensor
    following the ports and adapters pattern. It handles I2C communication
    and measurement conversion for voltage (V), current (mA) and power (mW).

    Implements the I2CSensorPort interface, adapting the INA219 library functions
    to the common sensor interface used throughout the application.
    """

    def __init__(self, sensor, measurement, i2c_address, scl, sda):
        """
        Initialize the INA219 sensor adapter.

        Args:
            sensor: Identifier for the sensor type (e.g., "ina219")
            measurement: Description of what's being measured (e.g., "Battery", "PV Panel")
            i2c_address: The I2C address of the sensor (e.g., 0x40, 0x41)
            scl: The pin number for the I2C clock line
            sda: The pin number for the I2C data line
        """
        self._sensor = sensor
        self._measurement = measurement
        self._i2c_address = i2c_address
        self._scl = scl
        self._sda = sda
        self._shunt_ohms = 0.1  # Standard shunt resistor value
        self._max_expected_amps = 0.2  # Maximum expected current
        self._ina = None

    @property
    def sensor(self) -> str:
        """
        Get the sensor type identifier.

        Returns:
            str: The sensor type (e.g., "ina219")
        """
        return self._sensor

    @property
    def measurement(self) -> str:
        """
        Get the measurement description.

        Returns:
            str: Description of what's being measured (e.g., "Battery")
        """
        return self._measurement

    @property
    def i2c_address(self) -> int:
        """
        Get the I2C address of the sensor.

        Returns:
            int: I2C address in hexadecimal (e.g., 0x40)
        """
        return self._i2c_address

    @property
    def scl(self) -> int:
        """
        Get the SCL pin number.

        Returns:
            int: GPIO pin number for I2C clock line
        """
        return self._scl

    @property
    def sda(self) -> int:
        """
        Get the SDA pin number.

        Returns:
            int: GPIO pin number for I2C data line
        """
        return self._sda

    def is_ready(self) -> bool:
        """
        Check if the sensor is available on the I2C bus.

        Scans the I2C bus and checks if a device with the configured address responds.

        Returns:
            bool: True if sensor responds, False otherwise
        """
        try:
            i2c = SoftI2C(scl=Pin(self._scl), sda=Pin(self._sda))
            devices = i2c.scan()
            return self._i2c_address in devices
        except Exception:
            return False

    def read(self):
        """
        Read voltage, current, and power measurements from the INA219 sensor.

        Configures the INA219 for 16V range and highest precision measurements,
        then reads voltage, current and power values.

        Returns:
            dict: Dictionary containing:
                - voltage: Bus voltage in volts (V)
                - current: Current in milliamps (mA)
                - power: Power in milliwatts (mW)
                - units: Dictionary mapping values to their units
                - error: Error message if reading failed
        """
        try:
            i2c = SoftI2C(scl=Pin(self._scl), sda=Pin(self._sda))
            ina = CustomINA219(
                self._shunt_ohms,
                i2c,
                self._max_expected_amps,
                address=self._i2c_address,
                log_level=logging.WARNING,
            )

            ina.configure(
                voltage_range=ina.RANGE_16V,
                gain=ina.GAIN_1_40MV,
                bus_adc=ina.ADC_128SAMP,
                shunt_adc=ina.ADC_128SAMP,
            )

            voltage = ina.voltage()
            current = ina.current()
            power = ina.power()

            return {
                "measurements": {
                    "measurement:": self._measurement,
                    "voltage": voltage,
                    "current": current,
                    "power": power,
                },
                "units": {"voltage": "V", "current": "mA", "power": "mW"},
            }

        except Exception as e:
            print(f"Error reading INA219 sensor: {e}")
            return {"error": str(e)}
