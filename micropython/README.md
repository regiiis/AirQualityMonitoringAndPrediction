# Air Quality Monitoring and Prediction - Sensor Documentation

## Development Environment

- VS Code
- Arduino Nano ESP32
- MicroPython firmware for ESP32
- Python 3.x

## Prerequisites

1. **Install Python**:
   - Ensure Python 3.x is installed and added to your PATH
   - Install `pip` if not already installed

2. **Connect Arduino Nano ESP32 via USB**:
   - Connect your Arduino Nano ESP32 to your computer via USB

## Automated Setup

The project uses a PowerShell script to automate all setup steps. Here's how to get started:

1. **Run the Installation Script**:
   Open PowerShell and navigate to the project directory, then run:
   ```powershell
   .\install.ps1
   ```
   This single command will:
   - Detect the ESP32 port
   - Install all Python dependencies
   - Download the latest MicroPython firmware
   - Flash the firmware to ESP32
   - Upload the `main.py` script

### Troubleshooting

1. **Port Detection Issues**:
   - Ensure the device is properly connected
   - Check the device manager to see if the device is recognized

2. **Python Environment Issues**:
   - Ensure Python is installed and added to your PATH
   - Use the `--user` option for pip installations to avoid permission issues

## Script Configuration

The main script requires WiFi credentials. You will be prompted to enter them during the installation process.

## Development Workflow

1. Connect ESP32 and ensure it's attached
2. Make code changes in VS Code
3. Upload changes using the `install.ps1` script
4. Monitor output: Use VS Code's Serial Monitor or:
   ```powershell
   screen /dev/ttyUSB0 115200
   ```
   (Exit screen with Ctrl+A, K)
