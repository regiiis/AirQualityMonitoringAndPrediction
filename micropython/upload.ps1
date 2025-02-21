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

function Upload-Code {
    param($port)

    # First upload the secure storage module
    Write-Host "Uploading secure storage module..." -ForegroundColor Blue
    $storagePath = Join-Path $LOGIC_DIR "secure_storage.py"

    # Fixed ampy command execution using python -m
    Start-Process -FilePath $AMPY_CMD -ArgumentList "-m", "ampy", "--port", $port, "put", $storagePath, "/secure_storage.py" -NoNewWindow -Wait
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to upload secure_storage.py" -ForegroundColor Red
        exit 1
    }

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
print("Verifying stored credentials...")
stored_ssid, _ = storage.get_credentials()
if stored_ssid == '$ssid':
    print("Credentials stored successfully!")
else:
    print("Error: Credential verification failed!")
"@
    $tempFile = Join-Path $env:TEMP "store_creds.py"
    Set-Content -Path $tempFile -Value $tempScript

    # Upload and execute credential storage - fix these calls too
    Start-Process -FilePath $AMPY_CMD -ArgumentList "-m", "ampy", "--port", $port, "put", $tempFile, "/store_creds.py" -NoNewWindow -Wait
    Start-Process -FilePath $AMPY_CMD -ArgumentList "-m", "ampy", "--port", $port, "run", "/store_creds.py" -NoNewWindow -Wait
    Remove-Item $tempFile

    # Upload main script - fix this call too
    Write-Host "Uploading main.py..." -ForegroundColor Blue
    $mainPyPath = Join-Path $LOGIC_DIR $MAIN_SCRIPT
    Start-Process -FilePath $AMPY_CMD -ArgumentList "-m", "ampy", "--port", $port, "put", $mainPyPath, "/main.py" -NoNewWindow -Wait

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
