# Configuration
$FIRMWARE_BASE_URL = "https://micropython.org/download/ESP32_GENERIC_S3/"
$FIRMWARE_FILE = "esp32s3_latest.bin"
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
    python -m pip install -r requirements.txt --user
}

function Get-Firmware {
    Write-Host "Fetching latest MicroPython firmware URL..." -ForegroundColor Blue
    $html = Invoke-WebRequest -Uri $FIRMWARE_BASE_URL
    $firmwareUrl = ($html.Links | Where-Object { $_.href -match ".*\.bin$" }).href
    if (-not $firmwareUrl) {
        Write-Host "Error: Could not find firmware URL." -ForegroundColor Red
        exit 1
    }
    $firmwareUrl = "https://micropython.org" + $firmwareUrl
    Write-Host "Downloading MicroPython firmware from $firmwareUrl..." -ForegroundColor Blue
    Invoke-WebRequest -Uri $firmwareUrl -OutFile $FIRMWARE_FILE
}

function Update-Device {
    param($port)
    Write-Host "Erasing flash memory..." -ForegroundColor Blue
    Start-Sleep -Seconds 2  # Add a delay before flashing
    python -m esptool.py --chip esp32s3 --port $port erase_flash
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error erasing flash!" -ForegroundColor Red
        exit 1
    }

    Write-Host "Writing firmware to flash memory..." -ForegroundColor Blue
    python -m esptool.py --chip esp32s3 --port $port --baud 460800 write_flash -z 0x1000 $FIRMWARE_FILE
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
    Flash-Code $port
    Cleanup
    Write-Host "Installation complete!" -ForegroundColor Green
}
catch {
    Write-Host "An error occurred: $_" -ForegroundColor Red
}

# Keep the script window open
pause
