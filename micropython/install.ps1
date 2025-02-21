# Configuration
$FIRMWARE_BASE_URL = "https://micropython.org/download/ARDUINO_NANO_ESP32/"
$FIRMWARE_FILE = "arduino_nano_esp32_latest.bin"
$DRIVER_URL = "https://www.silabs.com/documents/public/software/CP210x_Universal_Windows_Driver.zip"
$DRIVER_ZIP = "CP210x_Universal_Windows_Driver.zip"
$DRIVER_FOLDER = "CP210x_Universal_Windows_Driver"

function Check-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "This script must be run as an administrator. Restarting with elevated privileges..." -ForegroundColor Yellow
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
}

function Check-Driver {
    Write-Host "Checking for CP210x driver..." -ForegroundColor Blue
    $driver = Get-WmiObject Win32_PnPSignedDriver | Where-Object { $_.DeviceName -like '*CP210*' }
    if (-not $driver) {
        Write-Host "CP210x driver not found." -ForegroundColor Red
        $install = Read-Host "Would you like to download and install the driver now? (y/n)"
        if ($install -eq 'y') {
            Write-Host "Downloading CP210x driver..." -ForegroundColor Blue
            Invoke-WebRequest -Uri $DRIVER_URL -OutFile $DRIVER_ZIP
            Write-Host "Extracting CP210x driver..." -ForegroundColor Blue
            Expand-Archive -Path $DRIVER_ZIP -DestinationPath $DRIVER_FOLDER -Force
            Write-Host "Listing contents of extracted directory for debugging..." -ForegroundColor Blue
            Get-ChildItem -Path $DRIVER_FOLDER -Recurse
            Write-Host "Installing CP210x driver..." -ForegroundColor Blue
            $infPath = Join-Path -Path $DRIVER_FOLDER -ChildPath "silabser.inf"
            if (Test-Path $infPath) {
                pnputil /add-driver $infPath /install
                Write-Host "Driver installation command executed." -ForegroundColor Green
                Start-Sleep -Seconds 10  # Wait for the system to recognize the driver
                Write-Host "Re-checking for CP210x driver..." -ForegroundColor Blue
                $driver = Get-WmiObject Win32_PnPSignedDriver | Where-Object { $_.DeviceName -like '*CP210*' }
                if (-not $driver) {
                    Write-Host "CP210x driver still not found. Please try the following steps:" -ForegroundColor Red
                    Write-Host "1. Disconnect and reconnect your device." -ForegroundColor Red
                    Write-Host "2. Restart your computer." -ForegroundColor Red
                    Write-Host "3. Install the driver manually from: https://www.silabs.com/developers/usb-to-uart-bridge-vcp-drivers" -ForegroundColor Red
                    exit 1
                }
                Write-Host "CP210x driver found after re-check." -ForegroundColor Green
            } else {
                Write-Host "Installer not found. Please install the driver manually from: https://www.silabs.com/developers/usb-to-uart-bridge-vcp-drivers" -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Host "Please install the driver from: https://www.silabs.com/developers/usb-to-uart-bridge-vcp-drivers" -ForegroundColor Red
            exit 1
        }
    }
    Write-Host "CP210x driver found." -ForegroundColor Green
}

function Reset-SerialPort {
    param($port)
    Write-Host "Resetting serial port $port..." -ForegroundColor Blue
    try {
        $serial = New-Object System.IO.Ports.SerialPort $port
        if ($serial.IsOpen) {
            $serial.Close()
        }
        # Kill any process that might be using the port
        Get-Process | Where-Object { $_.Name -match "putty|terminal|arduino|screen" } | Stop-Process -Force
        Start-Sleep -Seconds 2
    }
    catch {
        Write-Host "Warning: Could not reset serial port: $_" -ForegroundColor Yellow
    }
    finally {
        if ($serial) {
            $serial.Dispose()
        }
    }
}

function Get-ESP32Port {
    Write-Host "Getting ESP32..." -ForegroundColor Blue
    $port = Get-CimInstance -ClassName Win32_SerialPort |
            Where-Object { $_.Name -like '*Arduino*' -or $_.Name -like '*USB*' -or $_.Name -like '*CP210*' } |
            Select-Object -First 1 -ExpandProperty DeviceID

    if ($port) {
        Write-Host "Found ESP32 at: $port" -ForegroundColor Green
        Reset-SerialPort $port
        Start-Sleep -Seconds 3  # Add delay after port reset
        return $port
    }
    Write-Host "No ESP32 found! Please check connection." -ForegroundColor Red
    exit 1
}

function Initialize-Python {
    Write-Host "Setting up Python environment..." -ForegroundColor Blue
    python -m pip install --upgrade pip --user
    # Explicitly install esptool
    python -m pip install esptool --user
    python -m pip install -r requirements.txt --user

    # Verify esptool installation
    python -m pip show esptool
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: esptool not properly installed!" -ForegroundColor Red
        exit 1
    }
}

function Get-Firmware {
    Write-Host "Fetching latest MicroPython firmware URL..." -ForegroundColor Blue
    $html = Invoke-WebRequest -Uri $FIRMWARE_BASE_URL
    # Get all firmware links and select the first stable version (non-preview)
    $firmwareLinks = $html.Links |
        Where-Object { $_.href -match ".*\.bin$" -and $_.href -notmatch "preview" } |
        Sort-Object href -Descending
    $firmwareUrl = $firmwareLinks[0].href

    if (-not $firmwareUrl) {
        Write-Host "Error: Could not find firmware URL." -ForegroundColor Red
        exit 1
    }

    # Extract the filename from the URL
    $firmwareFileName = $firmwareUrl -replace "^.*?([^/]+)$", '$1'
    Write-Host "Using firmware: $firmwareFileName" -ForegroundColor Blue

    # Construct the full download URL
    $downloadUrl = "https://micropython.org/resources/firmware/$firmwareFileName"
    Write-Host "Downloading MicroPython firmware from $downloadUrl..." -ForegroundColor Blue

    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $FIRMWARE_FILE
        if (-not (Test-Path $FIRMWARE_FILE)) {
            throw "Downloaded file not found"
        }
    }
    catch {
        Write-Host "Error downloading firmware: $_" -ForegroundColor Red
        exit 1
    }
}

function Update-Device {
    param($port)
    Write-Host "Preparing to flash Arduino Nano ESP32..." -ForegroundColor Blue

    # Reset port before operations
    Reset-SerialPort $port
    Start-Sleep -Seconds 2

    Write-Host "`nEntering Download Mode - Follow these steps carefully:" -ForegroundColor Yellow
    Write-Host "1. Press and HOLD the BOOT button (hold it down)" -ForegroundColor Yellow
    Read-Host "Press Enter when you're holding the BOOT button"

    Write-Host "2. While HOLDING the BOOT button:" -ForegroundColor Yellow
    Write-Host "   a. Press and hold the RESET button for 1 second" -ForegroundColor Yellow
    Write-Host "   b. Release the RESET button" -ForegroundColor Yellow
    Write-Host "   c. Wait 1 more second" -ForegroundColor Yellow
    Write-Host "   d. Now release the BOOT button" -ForegroundColor Yellow
    Read-Host "Press Enter after completing ALL steps above"

    Write-Host "`nVerifying device is in download mode..." -ForegroundColor Blue
    try {
        # Test connection
        $testResult = python -m esptool --chip esp32 --port $port --baud 115200 chip_id
        if ($LASTEXITCODE -ne 0) {
            Write-Host "`nDevice not detected in download mode. Let's try again:" -ForegroundColor Red
            Write-Host "1. Unplug the USB cable" -ForegroundColor Yellow
            Write-Host "2. Wait 5 seconds" -ForegroundColor Yellow
            Write-Host "3. Plug the USB cable back in" -ForegroundColor Yellow
            Read-Host "Press Enter after reconnecting the device"
            return Update-Device $port  # Recursive call to try again
        }
    }
    catch {
        Write-Host "Error detecting device: $_" -ForegroundColor Red
        return Update-Device $port  # Recursive call to try again
    }

    Write-Host "`nDevice successfully entered download mode!" -ForegroundColor Green
    Start-Sleep -Seconds 2

    Write-Host "`nErasing flash memory..." -ForegroundColor Blue
    python -m esptool --chip esp32 --port $port --baud 921600 erase_flash
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error erasing flash!" -ForegroundColor Red
        exit 1
    }

    Write-Host "`nWriting MicroPython firmware..." -ForegroundColor Blue
    python -m esptool --chip esp32 --port $port --baud 921600 write_flash -z 0x1000 $FIRMWARE_FILE
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error writing firmware!" -ForegroundColor Red
        exit 1
    }

    Write-Host "`nFirmware flashed successfully." -ForegroundColor Green
    Write-Host "Final Steps:" -ForegroundColor Yellow
    Write-Host "1. Press the RESET button once" -ForegroundColor Yellow
    Write-Host "2. Wait 3 seconds for the device to initialize" -ForegroundColor Yellow
    Read-Host "Press Enter after completing these steps"
    Start-Sleep -Seconds 3
}

function Flash-Code {
    param($port)
    Write-Host "Getting WiFi credentials..." -ForegroundColor Blue
    $ssid = Read-Host "Enter WiFi SSID"
    $password = Read-Host "Enter WiFi Password" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
    $wifi_password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    Write-Host "Uploading main.py..." -ForegroundColor Blue
    $env:WIFI_SSID = $ssid
    $env:WIFI_PASSWORD = $wifi_password
    python -m ampy --port $port put ./micropython/main.py /main.py
}

function Cleanup {
    if (Test-Path $FIRMWARE_FILE) {
        Remove-Item $FIRMWARE_FILE
    }
}

# Main installation process
try {
    Check-Admin
    #Check-Driver
    $port = Get-ESP32Port
    Initialize-Python
    Get-Firmware
    Update-Device $port
    Start-Sleep -Seconds 3  # Wait for device to reset
    Flash-Code $port
    Cleanup
    Write-Host "Installation complete!" -ForegroundColor Green
    Write-Host "Note: If the device doesn't respond, press the RESET button." -ForegroundColor Yellow
}
catch {
    Write-Host "An error occurred: $_" -ForegroundColor Red
}

# Keep the script window open
pause
