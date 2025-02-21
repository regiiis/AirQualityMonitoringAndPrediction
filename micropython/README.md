# Air Quality Monitoring and Prediction - Sensor Documentation

## Development Environment

- VS Code
- Arduino Nano ESP32-S3
- MicroPython firmware for ESP32-S3
- Python 3.x
- lab-micropython-installer - https://github.com/arduino/lab-micropython-installer
## Prerequisites

1. **Install Python**:
   - Ensure Python 3.x is installed and added to your PATH
   - Install `pip` if not already installed

2. **Connect Arduino Nano ESP32-S3 via USB**:
   - Connect your Arduino Nano ESP32-S3 to your computer via USB

## Automated Setup

The project uses a PowerShell script to automate all setup steps. Here's how to get started:

1. **Run the Installation Script**:
   Open PowerShell and navigate to the project directory, then run:
   ```powershell
   .\install.ps1
   ```
   This single command will:
   - Detect the ESP32-S3 port
   - Install all Python dependencies
   - Download the latest MicroPython firmware for ESP32-S3
   - Erase the flash memory
   - Flash the firmware to ESP32-S3
   - Upload the `main.py` script located in the `micropython` directory

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

1. Connect ESP32-S3 and ensure it's attached
2. Make code changes in VS Code
3. Upload changes using the `install.ps1` script
4. Monitor output: Use VS Code's Serial Monitor or:
   ```powershell
   screen /dev/ttyUSB0 115200
   ```
   (Exit screen with Ctrl+A, K)

## Communication with ESP32-S3

### Connection Settings

Connect your ESP32-S3 to your PC via USB cable and use these serial communication parameters:

- Baud rate: 115200
- Data bits: 8
- Stop bits: 1
- Parity: None (N)
- (Often written as 115200-8-1-N)

### Software Options

You can use any serial terminal program:

- **Windows**: PuTTY, TeraTerm
- **Linux/macOS**: Screen, Minicom
- **Cross-platform**: Arduino Serial Monitor

### Communication Modes

The ESP32-S3 supports two USB communication methods:

1. **CDC/JTAG Mode**
   - Uses the built-in USB Serial/JTAG Controller
   - No external USB-to-UART bridge needed
   - Connects through GPIO19 (D-) and GPIO20 (D+)

2. **USB-to-UART Bridge**
   - Uses an external bridge chip on most development boards
   - Driver installation may be required depending on the bridge chip used

### Important Notes

- Close the serial terminal before uploading new firmware to avoid port access conflicts.
- Make sure to use a proper USB data cable, not just a charging cable.
- The ESP32-S3's built-in USB capability eliminates the need for external USB-to-UART adapters in most cases.
