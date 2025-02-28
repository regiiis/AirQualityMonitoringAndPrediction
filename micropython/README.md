# Air Quality Monitoring and Prediction System - Sensor Module

## Development Environment

- VS Code
- Powershell (with extension)
- Arduino Nano ESP32-S3
- MicroPython firmware for ESP32-S3
- Python 3.x
- lab-micropython-installer: https://github.com/arduino/lab-micropython-installer
- Micropython doc: https://docs.micropython.org/en/latest/index.html
- Micropython libs: https://github.com/micropython/micropython-lib/tree/master
- Micropython stubs: https://github.com/Josverl/micropython-stubs

Sensor Libs:
- INA219: https://raw.githubusercontent.com/chrisb2/pyb_ina219/master/ina219.py

   The module has four I2C, these addresses are:<br>
   INA219_I2C_ADDRESS1:  0x40   A0 = 0  A1 = 0<br>
   INA219_I2C_ADDRESS2:  0x41   A0 = 1  A1 = 0<br>
   INA219_I2C_ADDRESS3:  0x44   A0 = 0  A1 = 1<br>
   INA219_I2C_ADDRESS4:  0x45   A0 = 1  A1 = 1<br>

- HYT221:
   I2C adress: 0X28

- SoftI2C: any pin

### Installation

1. Navigate to the `micropython` folder
2. Run the installation script:
```powershell
.\install.ps1
```
This script will:
- Check for required prerequisites (Git, Node.js, npm)
- Install MicroPython on your ESP32 if not already installed
- Verify the installation

### Uploading Code

To upload the code to your ESP32:
```powershell
.\upload.ps1
```
This script will:
- Install required Python packages (adafruit-ampy)
- Automatically detect your ESP32 port
- Upload all necessary files (secure_storage.py, wifi.py, main.py)
- Connect to esp via miniterm
- Insert Credentials (Credentials are persistent on separate, NVS storage)

### Serial Connection

To connect to the ESP32's serial monitor:
```powershell
.\serial_connection.ps1
```
This script provides:
- Automatic ESP32 port detection
- Connect to esp via miniterm
