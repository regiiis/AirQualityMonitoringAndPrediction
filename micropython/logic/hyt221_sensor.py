from machine import Pin, I2C
import time


class HYT221:
    def __init__(self, scl: int, sda: int, freq: int, address=0x28):
        self.i2c = I2C(1, scl=Pin(scl), sda=Pin(sda), freq=freq)
        self.address = address

    def read(self):
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
        humidity, temperature = self.read()
        print("Humidity: {:.2f}%".format(humidity))
        print("Temperature: {:.2f}C".format(temperature))
