# Sensor Module
An embeded MicroPython project for Arduino Nano ESP32-S3.

The sensor module is designed to be used with the Arduino Nano ESP32-S3 board. It collects data from various sensors and sends it to a cloud-based backend for further processing and analysis.

MicroPython is a lean implementation of Python 3 that is optimized to run on microcontrollers and in constrained environments. It allows you to write Python code that interacts with hardware, making it ideal for IoT projects.

## Development Environment

### ```Components```
- **IDE**: VS Code
- **Scripts**: PowerShell
- **Hardware**: Arduino Nano ESP32-S3
- **Sensors**: INA219, HYT221
- **Firmware**: MicroPython for ESP32-S3
- **Language**: Python 3.11.*
- **Tools**: lab-micropython-installer: https://github.com/arduino/lab-micropython-installer

Resources & Knowledge:
- Micropython doc: https://docs.micropython.org/en/latest/index.html
- Micropython libs: https://github.com/micropython/micropython-lib/tree/master
- Micropython stubs: https://github.com/Josverl/micropython-stubs
- CPython libs: https://github.com/python/cpython

Sensor Libs:
- INA219: https://raw.githubusercontent.com/chrisb2/pyb_ina219/master/ina219.py

   The module has four I2C addresses:<br>
   INA219_I2C_ADDRESS1:  0x40   A0 = 0  A1 = 0<br>
   INA219_I2C_ADDRESS2:  0x41   A0 = 1  A1 = 0<br>
   INA219_I2C_ADDRESS3:  0x44   A0 = 0  A1 = 1<br>
   INA219_I2C_ADDRESS4:  0x45   A0 = 1  A1 = 1<br>

- HYT221:
   I2C adress: 0X28

You can also use "SoftI2C" feature, which makes it possible to use any GPIO pins as I2C pins. This is useful when you want to use different pins for I2C communication.

## Automation Scripts
In the `micropython` folder, you will find several PowerShell scripts that automate the installation and setup process for MicroPython on your ESP32 board. There is a script to install MicroPython, upload code, connect to the serial monitor, and clean the ESP32 flash memory.

The


- Run in PS in order to be able torun scripts:

1. Open PowerShell as Administrator
2. Set the execution policy to allow script execution:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```
3. Navigate to the `micropython` folder

Run one of the following scripts:

### ```Firmware Installer```
Install MicroPython on your ESP32 board.

```powershell
.\install.ps1
```
This script will:
- Check for required prerequisites (Git, Node.js, npm)
- Get the port of the ESP32
- Install MicroPython on your ESP32
- Verify the installation

### ```Code Uploader```
Upload the code to your ESP32.

```powershell
.\upload.ps1
```

The script has the following variables, which needs to be updated manually if changed:
- .\upload.ps1
   - $libraries - List of libs to upload on ESP32
   - $directories - Directory structure under .\micropython\

This script will:
- Install required Python packages (adafruit-ampy)
- Automatically detect your ESP32 port
- Create the necessary directory structure on the ESP32
- Upload the required libraries and files to the ESP32
- Upload all necessary files (secure_storage.py, wifi.py, main.py)
- Reboot the ESP32
- Connect to esp via miniterm
- Setup the credentials for WiFi connection and API key

### ```Serial Connector```
Connect to the ESP32's serial monitor.

```powershell
.\serial_connection.ps1
```
This script provides:
- Automatic ESP32 port detection
- Connect to esp via miniterm

### ```ESP32 Cleaner```
Clean the ESP32 flash memory and format the filesystem:

```powershell
.\clean_esp32.ps1
```
This script provides:
- Automatic ESP32 port detection
- Connect to esp via miniterm
- Erase the ESP32 flash memory
- Format the ESP32 filesystem
- Reboot the ESP32
