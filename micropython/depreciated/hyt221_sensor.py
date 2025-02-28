from machine import Pin, I2C
import time


class HYT221:
    """
    A class to represent the HYT221 humidity and temperature sensor.

    Attributes:
    -----------
    i2c : I2C
        The I2C interface to communicate with the sensor.
    address : int
        The I2C address of the sensor.

    Methods:
    --------
    read():
        Triggers a measurement and reads the humidity and temperature data from the sensor.
    print():
        Prints the humidity and temperature data to the console.
    """

    def __init__(self, scl: int, sda: int, freq: int, address=0x28):
        """
        Constructs all the necessary attributes for the HYT221 object.

        Parameters:
        -----------
        scl : int
            The pin number for the I2C clock line.
        sda : int
            The pin number for the I2C data line.
        freq : int
            The frequency for the I2C communication.
        address : int, optional
            The I2C address of the sensor (default is 0x28).
        """
        self.i2c = I2C(1, scl=Pin(scl), sda=Pin(sda), freq=freq)
        self.address = address

    def read(self):
        """
        Triggers a measurement and reads the humidity and temperature data from the sensor.

        Returns:
        --------
        tuple
            A tuple containing the humidity (in %) and temperature (in °C).
        """
        # Trigger a measurement
        self.i2c.writeto(self.address, b"\x00")
        time.sleep(0.1)  # Wait for the measurement to complete

        # Read 4 bytes of data
        data = self.i2c.readfrom(self.address, 4)

        # Parse the data
        humidity = ((data[0] & 0x3F) << 8) | data[1]
        temperature = (data[2] << 6) | (data[3] >> 2)

        # Convert to human-readable values
        humidity = humidity * 100 / 16383.0
        temperature = temperature * 165 / 16383.0 - 40

        return humidity, temperature

    def print(self):
        """
        Prints the humidity and temperature data to the console.
        """
        try:
            humidity, temperature = self.read()
            print("Humidity: {:.2f}%".format(humidity))
            print("Temperature: {:.2f}C".format(temperature))
        except Exception as e:
            print(f"Error reading HYT221 sensor: {e}")
            return False
