from machine import Pin, SoftI2C  # type: ignore
from ina219 import INA219  # type: ignore
import logging


class CustomINA219(INA219):
    """
    A class fix to make the library compatible with micropython.
    """

    def __log_register_operation(self, msg, register, value):
        # performance optimisation
        if self._log.isEnabledFor(logging.DEBUG):  # Fixed line
            binary = "{0:#018b}".format(value)
            self._log.debug(
                "%s register 0x%02x: 0x%04x %s", msg, register, value, binary
            )


class ina219:
    """
    A class to represent the INA219 voltage and current sensor.

    Attributes:
    -----------
    scl : int
        The pin number for the I2C clock line.
    sda : int
        The pin number for the I2C data line.
    I2C_ADDRESS : int
        The I2C address of the INA219 sensor.
    sensor_name : str
        The name of the sensor.
    SHUNT_OHMS : float
        The value of the shunt resistor in ohms.
    MAX_EXPECTED_AMPS : float
        The maximum expected current in amps.

    Methods:
    --------
    read():
        Reads data from the INA219 sensor and returns the voltage, current, and power.
    print():
        Prints the voltage, current, and power data to the console.
    """

    def __init__(self, scl: int, sda: int, I2C_ADDRESS: int, sensor_name: str):
        """
        Constructs all the necessary attributes for the INA219 object.

        Parameters:
        -----------
        scl : int
            The pin number for the I2C clock line.
        sda : int
            The pin number for the I2C data line.
        I2C_ADDRESS : int
            The I2C address of the INA219 sensor.
        sensor_name : str
            The name of the sensor.
        """
        self.scl = scl
        self.sda = sda
        self.I2C_ADDRESS = I2C_ADDRESS
        self.sensor_name = sensor_name
        self.SHUNT_OHMS = 0.1
        self.MAX_EXPECTED_AMPS = 0.2

    def read(self):
        """
        Reads data from the INA219 sensor and returns the voltage, current, and power.

        Returns:
        --------
        tuple
            A tuple containing the voltage (in V), current (in mA), and power (in mW).
        """
        try:
            i2c = SoftI2C(scl=Pin(self.scl), sda=Pin(self.sda))
            ina = CustomINA219(
                self.SHUNT_OHMS,
                i2c,
                self.MAX_EXPECTED_AMPS,
                address=self.I2C_ADDRESS,
                log_level=logging.INFO,
            )

            ina.configure(
                voltage_range=ina.RANGE_16V,
                gain=ina.GAIN_1_40MV,
                bus_adc=ina.ADC_128SAMP,
                shunt_adc=ina.ADC_128SAMP,
            )

            return ina.voltage(), ina.current(), ina.power()

        except Exception as e:
            print(f"Error reading INA219 sensor: {e}")
            return False

    def print(self):
        """
        Prints the voltage, current, and power data to the console.
        """
        try:
            voltage, current, power = self.read()
            print(f"Print {self.sensor_name} data:")
            print("Bus Voltage: {:.2f} V".format(voltage))
            print("Current: {:.2f} mA".format(current))
            print("Power: {:.2f} mW".format(power))
        except Exception as e:
            print(f"Error reading {self.sensor_name} sensor: {e}")
            return False
