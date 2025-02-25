from machine import Pin, SoftI2C
from ina219 import INA219
import logging


class CustomINA219(INA219):
    def __log_register_operation(self, msg, register, value):
        # performance optimisation
        if self._log.isEnabledFor(logging.DEBUG):
            binary = "{0:#018b}".format(value)
            self._log.debug(
                "%s register 0x%02x: 0x%04x %s", msg, register, value, binary
            )


def read_ina219(I2C_ADDRESS: str, sensor_name: str):
    try:
        print(f"Start reading INA219 sensor at address {I2C_ADDRESS}")
        I2C_address = I2C_ADDRESS
        SHUNT_OHMS = 0.1
        MAX_EXPECTED_AMPS = 0.2

        print("Set I2C adress")
        i2c = SoftI2C(scl=Pin(11), sda=Pin(12))
        print("Get sensor data")
        ina = CustomINA219(
            SHUNT_OHMS,
            i2c,
            MAX_EXPECTED_AMPS,
            address=I2C_address,
            log_level=logging.INFO,
        )
        print("Configure sensor")
        ina.configure(ina.RANGE_16V)

        print(f"Print {sensor_name} data:")
        print("Bus Voltage: %.3f V" % ina.voltage())
        print("Current: %.3f mA" % ina.current())
        print("Power: %.3f mW" % ina.power())

    except Exception as e:
        print(f"Error reading INA219 sensor: {e}")
        return False
