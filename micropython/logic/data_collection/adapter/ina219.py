"""
Adapter implementation for INA219 current/voltage sensor
"""

from machine import Pin, SoftI2C  # type: ignore
from ina219 import INA219  # type: ignore
import logging
from data_collection.port.sensorport import I2CSensorPort  # type: ignore


class CustomINA219(INA219):
    """
    A class fix to make the library compatible with micropython.
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
    Adapter for the INA219 voltage and current sensor.

    Implements the SensorPort interface, adapting the INA219 library functions
    to the common interface.
    """

    def __init__(self, name, i2c_address, scl, sda):
        """
        Initialize the INA219 sensor adapter.

        Args:
            scl: The pin number for the I2C clock line
            sda: The pin number for the I2C data line
            i2c_address: The I2C address of the sensor
            sensor_name: A descriptive name for this sensor instance
        """
        self._name = name
        self._i2c_address = i2c_address
        self._scl = scl
        self._sda = sda
        self._shunt_ohms = 0.1
        self._max_expected_amps = 0.2
        self._ina = None

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
        Read voltage, current, and power measurements from the INA219 sensor

        Returns:
            Dict with voltage, current, and power readings
        """
        try:
            i2c = SoftI2C(scl=Pin(self._scl), sda=Pin(self._sda))
            ina = CustomINA219(
                self._shunt_ohms,
                i2c,
                self._max_expected_amps,
                address=self._i2c_address,
                log_level=logging.INFO,
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
                "voltage": voltage,
                "current": current,
                "power": power,
                "units": {"voltage": "V", "current": "mA", "power": "mW"},
            }

        except Exception as e:
            print(f"Error reading INA219 sensor: {e}")
            return {"error": str(e)}
