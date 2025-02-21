# Configuration
$LOGIC_DIR = "./logic"
$MAIN_SCRIPT = "main.py"

function Initialize-Python {
    Write-Host "Setting up Python environment..." -ForegroundColor Blue
    python -m pip install --upgrade pip --user
    python -m pip install adafruit-ampy --user

    # Verify ampy installation
    python -m pip show adafruit-ampy
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: adafruit-ampy not properly installed!" -ForegroundColor Red
        exit 1
    }
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

function Upload-Code {
    param($port)
    Write-Host "Getting WiFi credentials..." -ForegroundColor Blue
    $ssid = Read-Host "Enter WiFi SSID"
    $password = Read-Host "Enter WiFi Password" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
    $wifi_password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    # Set environment variables for the Python script
    $env:WIFI_SSID = $ssid
    $env:WIFI_PASSWORD = $wifi_password

    Write-Host "Uploading main.py..." -ForegroundColor Blue
    $mainPyPath = Join-Path $LOGIC_DIR $MAIN_SCRIPT

    if (-not (Test-Path $mainPyPath)) {
        Write-Host "Error: $MAIN_SCRIPT not found in $LOGIC_DIR" -ForegroundColor Red
        exit 1
    }

    # Use ampy command directly from Scripts directory
    $ampy = Join-Path ([System.IO.Path]::GetDirectoryName((Get-Command python).Path)) "Scripts\ampy.exe"
    if (-not (Test-Path $ampy)) {
        Write-Host "Error: ampy.exe not found! Trying alternative methods..." -ForegroundColor Yellow
        # Try alternative installation
        python -m pip install --user adafruit-ampy --upgrade
        $ampy = Join-Path $env:APPDATA "Python\Python312\Scripts\ampy.exe"
    }

    if (Test-Path $ampy) {
        & $ampy --port $port put $mainPyPath main.py
    } else {
        Write-Host "Error: Cannot find ampy executable!" -ForegroundColor Red
        exit 1
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error uploading code!" -ForegroundColor Red
        exit 1
    }

    Write-Host "Code uploaded successfully!" -ForegroundColor Green
}

# Main upload process
try {
    Initialize-Python
    $port = Get-ESP32Port
    Upload-Code $port
    Write-Host "Press the RESET button to start running the code." -ForegroundColor Yellow
}
catch {
    Write-Host "An error occurred: $_" -ForegroundColor Red
}
