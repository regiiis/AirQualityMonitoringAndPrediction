# Air Quality Monitoring and Prediction System - Sensor Module

## Development Environment

- VS Code
- Arduino Nano ESP32-S3
- MicroPython firmware for ESP32-S3
- Python 3.x
- lab-micropython-installer: https://github.com/arduino/lab-micropython-installer
- micropythn doc: https://docs.micropython.org/en/latest/index.html

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
