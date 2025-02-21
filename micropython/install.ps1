# Configuration
$FIRMWARE_URL = "https://micropython.org/resources/firmware/ESP32_GENERIC-20240105-v1.22.1.bin"
$FIRMWARE_FILE = "ESP32_GENERIC.bin"

function Get-ESP32Port {
    Write-Host "Getting ESP32..." -ForegroundColor Blue
    $port = Get-CimInstance -ClassName Win32_SerialPort |
            Where-Object { $_.Name -like '*Arduino*' -or $_.Name -like '*USB*' -or $_.Name -like '*CP210*' } |
            Select-Object -First 1 -ExpandProperty DeviceID

    if ($port) {
        Write-Host "Found ESP32 at: $port" -ForegroundColor Green
        return $port
    }
    Write-Host "No ESP32 found! Please check connection." -ForegroundColor Red
    exit 1
}

function Initialize-Python {
    Write-Host "Setting up Python environment..." -ForegroundColor Blue
    python -m pip install --upgrade pip --user
    python -m pip install setuptools --user
    python -m pip install esptool ampy --user
}

function Get-Firmware {
    Write-Host "Downloading MicroPython firmware..." -ForegroundColor Blue
    Invoke-WebRequest -Uri $FIRMWARE_URL -OutFile $FIRMWARE_FILE
}

function Update-Device {
    param($port)
    Write-Host "Flashing ESP32..." -ForegroundColor Blue
    python -m esptool --chip esp32 --port $port erase_flash
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error erasing flash!" -ForegroundColor Red
        exit 1
    }

    python -m esptool --chip esp32 --port $port --baud 460800 write_flash -z 0x1000 $FIRMWARE_FILE
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error writing firmware!" -ForegroundColor Red
        exit 1
    }
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
    python -m ampy --port $port put sensor/main.py
}

function Cleanup {
    if (Test-Path $FIRMWARE_FILE) {
        Remove-Item $FIRMWARE_FILE
    }
}

# Main installation process
try {
    $port = Get-ESP32Port
    Initialize-Python
    Get-Firmware
    Update-Device $port
    Flash-Code $port
    Cleanup
    Write-Host "Installation complete!" -ForegroundColor Green
}
catch {
    Write-Host "An error occurred: $_" -ForegroundColor Red
    exit 1
}
