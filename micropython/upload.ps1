# Configuration
$LOGIC_DIR = "./logic"
$MAIN_SCRIPT = "main.py"
# Remove direct ampy command and use python -m ampy instead
$AMPY_CMD = "python"

function Initialize-Python {
    Write-Host "Setting up Python environment..." -ForegroundColor Blue
    python -m pip install --upgrade pip --quiet
    python -m pip install adafruit-ampy --quiet

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

function Execute-Ampy {
    param($port, $arguments)
    # Use python -m ampy to execute ampy commands
    $output = & python -m ampy.cli --port $port $arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Command failed: ampy --port $port $arguments" -ForegroundColor Red
        return $false
    }
    return $output
}

function Upload-Code {
    param($port)

    # First upload the secure storage module
    Write-Host "Uploading secure storage module..." -ForegroundColor Blue
    $storagePath = Join-Path $LOGIC_DIR "secure_storage.py"
    Execute-Ampy -port $port -arguments @("put", $storagePath, "/secure_storage.py")
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to upload secure_storage.py" -ForegroundColor Red
        exit 1
    }

    # Upload main script
    Write-Host "Uploading main.py..." -ForegroundColor Blue
    $mainPyPath = Join-Path $LOGIC_DIR $MAIN_SCRIPT
    Execute-Ampy -port $port -arguments @("put", $mainPyPath, "/main.py")
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to upload main.py" -ForegroundColor Red
        exit 1
    }

    Write-Host "Code uploaded. Please press the RESET button on your ESP32 NOW." -ForegroundColor Yellow
    Read-Host "Press Enter to continue after rebooting the ESP32"

    # Get WiFi credentials securely
    Write-Host "Getting WiFi credentials..." -ForegroundColor Blue
    $ssid = Read-Host "Enter WiFi SSID"
    $password = Read-Host "Enter WiFi Password" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
    $wifi_password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    # Create and run script to store credentials in NVS
    Write-Host "Storing WiFi credentials in secure storage..." -ForegroundColor Blue
    $tempScript = @"
from secure_storage import SecureStorage
storage = SecureStorage()
storage.store_credentials('$ssid', '$wifi_password')
print("WiFi credentials stored.")
"@
    $tempFile = Join-Path $env:TEMP "store_creds.py"
    Set-Content -Path $tempFile -Value $tempScript

    # Upload credential storage
    Write-Host "Uploading credential storage script..." -ForegroundColor Blue
    $putResult = Execute-Ampy -port $port -arguments @("put", $tempFile, "/store_creds.py")
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to upload /store_creds.py" -ForegroundColor Red
        exit 1
    }

    # Execute credential storage
    Write-Host "Executing credential storage script..." -ForegroundColor Blue
    $runResult = Execute-Ampy -port $port -arguments @("run", "/store_creds.py")
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to run /store_creds.py" -ForegroundColor Red
        exit 1
    }

    Remove-Item $tempFile

    Write-Host "Credentials uploaded." -ForegroundColor Green
}

# Main upload process
try {
    Initialize-Python
    $port = Get-ESP32Port
    Upload-Code $port
    Write-Host "Upload successful. Please RESET the ESP32 before use." -ForegroundColor Yellow
}
catch {
    Write-Host "An error occurred: $_" -ForegroundColor Red
}
