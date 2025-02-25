<#
.SYNOPSIS
    Script to upload MicroPython code to ESP32 devices.
.DESCRIPTION
    Handles the upload process of MicroPython files to ESP32, including automatic port detection
    and verification of successful uploads.
#>

# Configuration
$LOGIC_DIR = "./logic"
$LIB_DIR = "./libs"
$AMPY_CMD = "python"

# Define the libraries and their URLs
$libraries = @(
    @{ Name = "ina219"; Url = "https://raw.githubusercontent.com/chrisb2/pyb_ina219/master/ina219.py" },
    @{ Name = "logging"; Url = "https://raw.githubusercontent.com/micropython/micropython-lib/refs/heads/master/python-stdlib/logging/logging.py" }
)

function Initialize-Python {
    <#
    .SYNOPSIS
        Sets up the Python environment with required packages.
    .DESCRIPTION
        Installs and verifies the presence of required Python packages,
        particularly adafruit-ampy for ESP32 communication.
    #>
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
    <#
    .SYNOPSIS
        Detects and returns the COM port for connected ESP32.
    .DESCRIPTION
        Searches through available serial ports to find an ESP32 device
        by matching common identifiers in the device name.
    .OUTPUTS
        String containing the COM port identifier.
    #>
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
    <#
    .SYNOPSIS
        Executes ampy commands for ESP32 communication.
    .PARAMETER port
        The COM port where ESP32 is connected.
    .PARAMETER arguments
        Array of arguments to pass to ampy.
    .OUTPUTS
        Command output or $false if command fails.
    #>
    param($port, $arguments)
    # Use python -m ampy to execute ampy commands
    $output = & python -m ampy.cli --port $port $arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Command failed: ampy --port $port $arguments" -ForegroundColor Red
        return $false
    }
    return $output
}

function Download-Libraries {
    <#
    .SYNOPSIS
        Downloads required libraries specified in the script.
    .DESCRIPTION
        Checks the defined libraries and downloads them if they are not present in the libs directory.
    #>
    Write-Host "Checking and downloading required libraries..." -ForegroundColor Blue

    foreach ($library in $libraries) {
        $libName = $library.Name
        $libUrl = $library.Url
        $libPath = Join-Path $LIB_DIR "$libName.py"

        if (-not (Test-Path $libPath)) {
            Write-Host "Downloading $libName from $libUrl..." -ForegroundColor Blue
            Invoke-WebRequest -Uri $libUrl -OutFile $libPath
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Failed to download $libName" -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Host "$libName is already present in the libs directory." -ForegroundColor Green
        }
    }
}

function Upload-Code {
    <#
    .SYNOPSIS
        Uploads MicroPython code files to ESP32.
    .PARAMETER port
        The COM port where ESP32 is connected.
    .DESCRIPTION
        Handles the sequential upload of secure_storage.py, wifi.py, main.py,
        and any additional libraries to the ESP32 device.
    #>
    param($port)

    # Upload secure_storage.py
    Write-Host "Uploading secure storage module..." -ForegroundColor Blue
    $storagePath = Join-Path $LOGIC_DIR "secure_storage.py"
    $result = Execute-Ampy -port $port -arguments @("put", $storagePath, "/secure_storage.py")
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to upload secure_storage.py" -ForegroundColor Red
        exit 1
    }

    # Upload wifi.py
    Write-Host "Uploading wifi module..." -ForegroundColor Blue
    $wifiPath = Join-Path $LOGIC_DIR "wifi.py"
    $result = Execute-Ampy -port $port -arguments @("put", $wifiPath, "/wifi.py")
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to upload wifi.py" -ForegroundColor Red
        exit 1
    }

    # Upload ina219_sensor.py
    Write-Host "Uploading ina219_sensor.py..." -ForegroundColor Blue
    $ina219_sensorPyPath = Join-Path $LOGIC_DIR "ina219_sensor.py"
    $result = Execute-Ampy -port $port -arguments @("put", $ina219_sensorPyPath, "/ina219_sensor.py")
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to upload ina219_sensor.py" -ForegroundColor Red
        exit 1
        }

    # Upload main.py
    Write-Host "Uploading main.py..." -ForegroundColor Blue
    $mainPyPath = Join-Path $LOGIC_DIR "main.py"
    $result = Execute-Ampy -port $port -arguments @("put", $mainPyPath, "/main.py")
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to upload main.py" -ForegroundColor Red
        exit 1
    }

    # Upload additional libraries
    Write-Host "Uploading additional libraries..." -ForegroundColor Blue
    $libFiles = Get-ChildItem -Path $LIB_DIR -Filter "*.py"
    foreach ($libFile in $libFiles) {
        $libPath = $libFile.FullName
        $libName = $libFile.Name
        $result = Execute-Ampy -port $port -arguments @("put", $libPath, "/$libName")
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to upload $libName" -ForegroundColor Red
            exit 1
        }
    }

    Write-Host "Code and libraries uploaded. Please press the RESET button on your ESP32 NOW." -ForegroundColor Yellow
    Read-Host "Press Enter to continue after rebooting the ESP32"

    # Connect to REPL using miniterm
    Write-Host "Connecting to REPL using miniterm..." -ForegroundColor Blue
    Write-Host "Please enter the following command in the miniterm window:" -ForegroundColor Yellow
    Write-Host "$pythonCommand" -ForegroundColor Yellow
    python -m serial.tools.miniterm $port 115200
}

# Main upload process
try {
    Initialize-Python
    Download-Libraries
    $port = Get-ESP32Port
    Upload-Code $port
    Write-Host "Upload successful. Please RESET the ESP32 before use!" -ForegroundColor Yellow
}
catch {
    Write-Host "An error occurred: $_" -ForegroundColor Red
}
