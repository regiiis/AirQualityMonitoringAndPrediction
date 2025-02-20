# Air Quality Monitoring and Prediction - Sensor Documentation

## Development Environment

- VS Code with WSL (Ubuntu)
- Arduino Nano ESP32
- MicroPython firmware for ESP32
- Python 3.x

## Prerequisites

1. **WSL Setup**:
   - Install WSL2 with Ubuntu
   - Install `usbipd-win` for USB device access in WSL:
   ```powershell
   winget install --interactive --exact dorssel.usbipd-win
   ```

## Automated Setup

The project uses a Makefile to automate all setup steps. Here's how to get started:

1. **Connect Arduino**:
   - Connect your Arduino Nano ESP32 to your computer via USB
   - In PowerShell (as Administrator), attach the device to WSL:
   ```powershell
   usbipd list
   usbipd bind --busid <busid>
   usbipd attach --busid <busid>
   ```

2. **Check Device Connection**:
   ```bash
   make detect_port
   ```
   This will show available ports and automatically detect your ESP32.

3. **Full Installation**:
   ```bash
   make install
   ```
   This single command will:
   - Install all Python dependencies
   - Download the latest MicroPython firmware
   - Flash the firmware to ESP32
   - Upload the main.py script

### Individual Steps

If you prefer step-by-step setup:

```bash
# 1. Install Python dependencies
make setup

# 2. Download MicroPython firmware
make download

# 3. Flash firmware (port auto-detected)
make flash
# Or specify port manually:
make flash PORT=COM3  # Windows
make flash PORT=/dev/ttyUSB0  # WSL/Linux

# 4. Upload your code
make upload
```

### Troubleshooting

1. **Port Detection Issues**:
   - Run `make detect_port` to list available ports
   - Check USB connection
   - To check connected devices, you need to use PowerShell. WSL has no direct access to computer ports.


## Script Configuration

The main script requires WiFi credentials. You will be asked during runtime to pass them as env variable

```python
ssid = 'your_SSID'
password = 'your_PASSWORD'
```

## Development Workflow

1. Connect ESP32 and ensure it's attached to WSL
2. Make code changes in VS Code
3. Upload changes: `make upload`
4. Monitor output: Use VS Code's Serial Monitor or:
   ```bash
   screen /dev/ttyUSB0 115200
   ```
   (Exit screen with Ctrl+A, K)
