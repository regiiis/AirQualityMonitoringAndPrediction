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

# Define the list of files to upload from the logic directory
$logicFiles = @(
    "secure_storage.py",
    "wifi.py",
    "ina219_sensor.py",
    "hyt221_sensor.py",
    "main.py"
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
    .PARAMETER logicFiles
        Array of file names to upload from the logic directory.
    .DESCRIPTION
        Handles the sequential upload of Python files from the logic directory
        and additional libraries to the ESP32 device.
    #>
    param(
        $port,
        $logicFiles
    )

    # Upload files from the logic directory
    foreach ($file in $logicFiles) {
        Write-Host "Uploading $file..." -ForegroundColor Blue
        $sourcePath = Join-Path $LOGIC_DIR $file
        $destinationPath = "/$file"

        $result = Execute-Ampy -port $port -arguments @("put", $sourcePath, $destinationPath)
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to upload $file" -ForegroundColor Red
            exit 1
        }
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

    Write-Host "Code and libraries uploaded." -ForegroundColor Yellow
}

function Reset-ESP32 {
    <#
    .SYNOPSIS
        Reboots the Arduino Nano ESP32 device programmatically.
    .PARAMETER port
        The COM port where ESP32 is connected.
    .DESCRIPTION
        Performs a programmatic reset using MicroPython's machine.reset() function.
    #>
    param($port)

    [string]$ComPort = $port
    [int]$BaudRate = 115200

    Write-Host "Rebooting ESP32 programmatically..." -ForegroundColor Blue
    try {
        # First ensure pyserial is installed for better control
        python -m pip install pyserial --quiet

        # Use Python directly for more reliable reset
        $pythonResetScript = @"
import serial
import time

try:
    # Open the serial connection
    print('Opening serial connection to $ComPort')
    ser = serial.Serial('$ComPort', $BaudRate, timeout=1)

    # Wait for connection to stabilize
    time.sleep(0.5)

    # Send Ctrl+C to interrupt any running program
    print('Interrupting current program')
    ser.write(b'\x03')
    time.sleep(0.5)

    # Clear the input buffer
    ser.reset_input_buffer()

    # Send a few newlines to ensure we're at a fresh prompt
    ser.write(b'\r\n\r\n')
    time.sleep(0.5)

    # Send the reset command
    print('Sending reset command')
    ser.write(b'import machine\r\n')
    time.sleep(0.5)
    ser.write(b'machine.reset()\r\n')

    # Give a small delay before closing to ensure command is sent
    time.sleep(0.2)
    ser.close()

    print('Reset command sent successfully')
    exit(0)
except Exception as e:
    print(f'Error: {str(e)}')
    exit(1)
"@

        # Execute the Python script for reset
        $tempFile = [System.IO.Path]::GetTempFileName() + ".py"
        $pythonResetScript | Out-File -FilePath $tempFile -Encoding utf8

        Write-Host "Executing Python reset script..." -ForegroundColor Blue
        $result = python $tempFile
        $resetSuccess = $LASTEXITCODE -eq 0

        # Clean up temp file
        Remove-Item -Path $tempFile -Force

        if ($resetSuccess) {
            Write-Host "Reset command sent. ESP32 should reboot momentarily." -ForegroundColor Green
            Write-Host "Waiting for ESP32 to reboot..." -ForegroundColor Blue
            return $true
        } else {
            Write-Host "Reset command failed. Output: $result" -ForegroundColor Red
            throw "Reset command failed"
        }
    }
    catch {
        Write-Host "Error during programmatic reset: $_" -ForegroundColor Red

        # Fall back to manual reset
        Write-Host "Automatic reset failed. Please press the RESET button on your Arduino Nano ESP32." -ForegroundColor Yellow
        Read-Host "Press Enter after pressing the reset button"
        return $true
    }
}

function Connect-REPL {
    param($port)
    # Connect to REPL using miniterm
    Write-Host "Connecting to REPL using miniterm..." -ForegroundColor Blue
    python -m serial.tools.miniterm $port 115200
}

# Main upload process
try {
    Initialize-Python
    Download-Libraries
    $port = Get-ESP32Port
    Upload-Code $port $logicFiles
    Reset-ESP32 $port
    Start-Sleep -Seconds 5
    Connect-REPL $port
    Write-Host "Upload successful." -ForegroundColor Yellow
}
catch {
    Write-Host "An error occurred: $_" -ForegroundColor Red
}
