<#
.SYNOPSIS
    Script to upload MicroPython code to ESP32 devices.
.DESCRIPTION
    Handles the upload process of MicroPython files to ESP32, including:
    - Automatic port detection and connection
    - Required library downloads
    - Directory structure creation
    - Code upload from local project to ESP32
    - ESP32 reset after upload
    - REPL connection for immediate testing

    The script maintains the same directory structure on the ESP32 as in the local project.
.NOTES
    Requires Python with adafruit-ampy and pyserial packages.
    Compatible with Arduino Nano ESP32 and similar boards.
.EXAMPLE
    ./upload.ps1
    # Executes the full upload process
#>

# Configuration
$LOGIC_DIR = "./logic"
$LIB_DIR = "./libs"
$AMPY_CMD = "python"

# Define the libraries and their URLs
$libraries = @(
    @{ Name = "ina219"; Url = "https://raw.githubusercontent.com/chrisb2/pyb_ina219/master/ina219.py" },
    @{ Name = "logging"; Url = "https://raw.githubusercontent.com/micropython/micropython-lib/refs/heads/master/python-stdlib/logging/logging.py" },
    @{ Name = "typing"; Url = "https://raw.githubusercontent.com/Josverl/micropython-stubs/refs/heads/main/mip/typing.py" }
)

# Define directories to create and populate on ESP32
$orderedDirs = @(
    "/modules",
    "/data_collection",
    "/data_collection/port",
    "/data_collection/adapter",
    "/data_transmission",
    "/data_transmission/port",
    "/data_transmission/adapter",
    "/data_transmission/service"
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
    .PARAMETER SuppressError
        Switch to suppress error messages for expected failures.
    .DESCRIPTION
        Wrapper function for executing ampy commands to communicate with ESP32.
        Returns a hashtable with Success status and command Output.
    .OUTPUTS
        Hashtable with Success (Boolean) and Output (String) properties.
    .EXAMPLE
        Execute-Ampy -port "COM5" -arguments @("ls", "/")
        # Lists files in the root directory
    #>
    param(
        $port,
        $arguments,
        [switch]$SuppressError
    )

    # Use python -m ampy to execute ampy commands
    try {
        $cmdOutput = & python -m ampy.cli --port $port $arguments 2>&1
        $success = $LASTEXITCODE -eq 0

        if (-not $success -and -not $SuppressError) {
            Write-Host "Command failed: ampy --port $port $arguments" -ForegroundColor Red
        }

        # Return both success status and output
        return @{
            Success = $success
            Output = $cmdOutput
        }
    }
    catch {
        Write-Host "Exception executing ampy: $_" -ForegroundColor Red
        return @{
            Success = $false
            Output = $_.Exception.Message
        }
    }
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
        Uploads MicroPython code to an ESP32 device.
    .PARAMETER port orderedDirs
        The COM port where ESP32 is connected.
    .DESCRIPTION
        Creates necessary directory structure on the ESP32 and uploads Python files
        from the local project structure. Handles main.py, module files, and libraries.
        Files are uploaded to their respective directories based on the project structure.
    .EXAMPLE
        Upload-Code -port "COM5"
        # Uploads all code to the ESP32 connected to COM5
    #>
    param($port, $orderedDirs)

    # Create directories on ESP32 - one by one without -p flag
    Write-Host "Creating directory structure on ESP32..." -ForegroundColor Blue

    # Try to create individual directories without using -p flag
    # First create parent directories, then subdirectories
    foreach ($dir in $orderedDirs) {
        try {
            # First check if directory exists (suppress error since we expect it might not exist)
            Write-Host "Checking if directory exists: $dir" -ForegroundColor Blue
            $checkResult = Execute-Ampy -port $port -arguments @("ls", "$dir") -SuppressError

            if ($checkResult.Success) {
                Write-Host "Directory $dir already exists" -ForegroundColor Green
            } else {
                # Directory doesn't exist, try to create it
                Write-Host "Creating directory: $dir" -ForegroundColor Blue
                $result = Execute-Ampy -port $port -arguments @("mkdir", $dir)

                if ($result.Success) {
                    Write-Host "Created directory: $dir" -ForegroundColor Green
                } else {
                    Write-Host "Failed to create directory: $dir" -ForegroundColor Red
                }
            }

            # Add small delay after directory operations
            Start-Sleep -Seconds 1
        }
        catch {
            Write-Host "Error processing directory $dir : $_" -ForegroundColor Yellow
        }
    }

    # Upload main.py to the root directory
    Write-Host "Uploading main.py..." -ForegroundColor Blue
    $mainPath = Join-Path $LOGIC_DIR "main.py"
    $result = Execute-Ampy -port $port -arguments @("put", $mainPath, "/main.py")

    if ($result.Success) {
        Write-Host "Successfully uploaded main.py" -ForegroundColor Green
        Start-Sleep -Seconds 1
    } else {
        Write-Host "Failed to upload main.py - check ESP32 connection" -ForegroundColor Red
        exit 1
    }

    # Process each directory's files
    foreach ($dir in $orderedDirs) {
        # Convert ESP32 path to local path
        $localDir = $dir -replace "^/", ""  # Remove leading slash
        $localPath = Join-Path $LOGIC_DIR $localDir

        if (-not (Test-Path $localPath)) {
            Write-Host "Local directory $localPath not found, skipping" -ForegroundColor Yellow
            continue
        }

        # Get Python files
        $pyFiles = Get-ChildItem -Path $localPath -Filter "*.py"
        Write-Host "Found $($pyFiles.Count) Python files in $localPath" -ForegroundColor Blue

        # Upload each file - no retries
        foreach ($file in $pyFiles) {
            $sourcePath = $file.FullName
            $destPath = "$dir/$($file.Name)"
            $fileName = $file.Name

            Write-Host "Uploading $fileName to $destPath..." -ForegroundColor Blue

            # Try direct file upload
            $result = Execute-Ampy -port $port -arguments @("put", $sourcePath, $destPath)

            if ($result.Success) {
                Write-Host "Successfully uploaded $fileName" -ForegroundColor Green
            } else {
                # If direct upload fails, try via temp file (one attempt)
                try {
                    $content = Get-Content -Path $sourcePath -Raw
                    $tempFile = [System.IO.Path]::GetTempFileName()
                    $content | Out-File -FilePath $tempFile -Encoding utf8 -NoNewline

                    $result = Execute-Ampy -port $port -arguments @("put", $tempFile, $destPath)
                    Remove-Item -Path $tempFile -Force

                    if ($result.Success) {
                        Write-Host "Successfully uploaded $fileName (via temp file)" -ForegroundColor Green
                    } else {
                        Write-Host "Failed to upload $fileName" -ForegroundColor Red

                        # Try to upload to root as last resort (one attempt)
                        $rootResult = Execute-Ampy -port $port -arguments @("put", $sourcePath, "/$fileName")
                        if ($rootResult.Success) {
                            Write-Host "Uploaded $fileName to root as fallback" -ForegroundColor Yellow
                        } else {
                            Write-Host "All upload attempts for $fileName failed" -ForegroundColor Red
                        }
                    }
                }
                catch {
                    Write-Host "Error during file upload: $_" -ForegroundColor Red
                }
            }

            # Small delay between files
            Start-Sleep -Milliseconds 500
        }
    }

    # Upload libraries to root - no retries
    Write-Host "Uploading additional libraries..." -ForegroundColor Blue
    $libFiles = Get-ChildItem -Path $LIB_DIR -Filter "*.py"

    foreach ($lib in $libFiles) {
        $libPath = $lib.FullName
        $libName = $lib.Name

        Write-Host "Uploading $libName to root..." -ForegroundColor Blue
        $result = Execute-Ampy -port $port -arguments @("put", $libPath, "/$libName")

        if ($result.Success) {
            Write-Host "Successfully uploaded $libName" -ForegroundColor Green
        } else {
            Write-Host "Failed to upload $libName" -ForegroundColor Red
        }

        # Small delay between libraries
        Start-Sleep -Milliseconds 500
    }

    Write-Host "Upload process completed." -ForegroundColor Yellow
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
    <#
    .SYNOPSIS
        Connects to the ESP32's MicroPython REPL interface.
    .PARAMETER port
        The COM port where ESP32 is connected.
    .DESCRIPTION
        Opens a serial connection to the ESP32's REPL (Read-Eval-Print Loop) interface
        using miniterm. This allows direct interaction with the MicroPython environment.
    .NOTES
        Press Ctrl+] to exit the REPL connection.
    #>
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
    Upload-Code $port $orderedDirs
    Reset-ESP32 $port
    Start-Sleep -Seconds 5
    Connect-REPL $port
    Write-Host "Upload successful." -ForegroundColor Yellow
}
catch {
    Write-Host "An error occurred: $_" -ForegroundColor Red
}
