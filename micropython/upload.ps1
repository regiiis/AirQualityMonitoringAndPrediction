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
    @{ Name = "logging"; Url = "https://raw.githubusercontent.com/micropython/micropython-lib/refs/heads/master/python-stdlib/logging/logging.py" },
    @{ Name = "typing"; Url = "https://raw.githubusercontent.com/Josverl/micropython-stubs/refs/heads/main/mip/typing.py" },
    @{ Name = "abc"; Url = "https://raw.githubusercontent.com/micropython/micropython-lib/master/python-stdlib/abc/abc.py" }
)

# Define directories to create and populate on ESP32
$directories = @(
    "/modules",
    "/data_collection",
    "/data_collection/port",
    "/data_collection/adapter"
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
        PSObject with Success and Output properties.
    #>
    param($port, $arguments)

    # Use python -m ampy to execute ampy commands
    try {
        $cmdOutput = & python -m ampy.cli --port $port $arguments 2>&1
        $success = $LASTEXITCODE -eq 0

        if (-not $success) {
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
    param($port)

    # Create directories on ESP32 - one by one without -p flag
    Write-Host "Creating directory structure on ESP32..." -ForegroundColor Blue

    # Try to create individual directories without using -p flag
    # First create parent directories, then subdirectories
    $orderedDirs = @(
        "/modules",
        "/data_collection",
        "/data_collection/port",
        "/data_collection/adapter"
    )

    foreach ($dir in $orderedDirs) {
        try {
            # First check if directory exists to avoid errors
            $checkResult = Execute-Ampy -port $port -arguments @("ls", "/")

            # Try to make directory (without -p flag)
            Write-Host "Creating directory: $dir" -ForegroundColor Blue
            $result = Execute-Ampy -port $port -arguments @("mkdir", $dir)

            if ($result.Success) {
                Write-Host "Created directory: $dir" -ForegroundColor Green
            } else {
                # Directory might already exist which is fine
                Write-Host "Note: Could not create directory $dir (might already exist)" -ForegroundColor Yellow
            }

            # Add longer delay after directory operations
            Start-Sleep -Seconds 2
        }
        catch {
            Write-Host "Error with directory $dir : $_" -ForegroundColor Yellow
            # Continue anyway as the directory might still work for uploads
        }
    }

    # Upload main.py to the root directory
    Write-Host "Uploading main.py..." -ForegroundColor Blue
    $mainPath = Join-Path $LOGIC_DIR "main.py"
    $result = Execute-Ampy -port $port -arguments @("put", $mainPath, "/main.py")

    if ($result.Success) {
        Write-Host "Successfully uploaded main.py" -ForegroundColor Green
        # If main.py uploads successfully, we have a good connection
        Start-Sleep -Seconds 3
    } else {
        Write-Host "Failed to upload main.py - check ESP32 connection" -ForegroundColor Red
        exit 1
    }

    # Process each directory's files
    foreach ($dir in $directories) {
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

        # Upload each file
        foreach ($file in $pyFiles) {
            $sourcePath = $file.FullName
            $destPath = "$dir/$($file.Name)"
            $fileName = $file.Name

            $maxRetries = 3
            $retryCount = 0
            $uploadSuccess = $false

            while (-not $uploadSuccess -and $retryCount -lt $maxRetries) {
                if ($retryCount -gt 0) {
                    Write-Host "Retry $retryCount for $fileName..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 3  # Longer delay between retries
                }

                Write-Host "Uploading $fileName to $destPath..." -ForegroundColor Blue

                # Try direct file upload first - simpler and might work
                $result = Execute-Ampy -port $port -arguments @("put", $sourcePath, $destPath)

                if ($result.Success) {
                    $uploadSuccess = $true
                    Write-Host "Successfully uploaded $fileName" -ForegroundColor Green
                } else {
                    # If direct upload fails, try via temp file
                    try {
                        $content = Get-Content -Path $sourcePath -Raw
                        $tempFile = [System.IO.Path]::GetTempFileName()
                        $content | Out-File -FilePath $tempFile -Encoding utf8 -NoNewline

                        $result = Execute-Ampy -port $port -arguments @("put", $tempFile, $destPath)
                        Remove-Item -Path $tempFile -Force

                        if ($result.Success) {
                            $uploadSuccess = $true
                            Write-Host "Successfully uploaded $fileName (via temp file)" -ForegroundColor Green
                        }
                    }
                    catch {
                        Write-Host "Error during alternative upload: $_" -ForegroundColor Red
                    }
                }

                $retryCount++
                Start-Sleep -Seconds 1
            }

            if (-not $uploadSuccess) {
                Write-Host "Failed to upload $fileName after $maxRetries attempts" -ForegroundColor Red
                # Try a different approach - upload to root and then move?
                try {
                    $rootResult = Execute-Ampy -port $port -arguments @("put", $sourcePath, "/$fileName")
                    if ($rootResult.Success) {
                        Write-Host "Uploaded $fileName to root as fallback" -ForegroundColor Yellow
                    }
                }
                catch {
                    # Last resort failed, continue with next file
                }
            }
        }
    }

    # Upload libraries to root
    Write-Host "Uploading additional libraries..." -ForegroundColor Blue
    $libFiles = Get-ChildItem -Path $LIB_DIR -Filter "*.py"

    foreach ($lib in $libFiles) {
        $libPath = $lib.FullName
        $libName = $lib.Name

        $maxRetries = 2
        for ($i = 0; $i -lt $maxRetries; $i++) {
            Write-Host "Uploading $libName to root..." -ForegroundColor Blue
            $result = Execute-Ampy -port $port -arguments @("put", $libPath, "/$libName")

            if ($result.Success) {
                Write-Host "Successfully uploaded $libName" -ForegroundColor Green
                break
            } else {
                Write-Host "Failed to upload $libName, retrying..." -ForegroundColor Yellow
                Start-Sleep -Seconds 2
            }
        }
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
    Upload-Code $port
    Reset-ESP32 $port
    Start-Sleep -Seconds 5
    Connect-REPL $port
    Write-Host "Upload successful." -ForegroundColor Yellow
}
catch {
    Write-Host "An error occurred: $_" -ForegroundColor Red
}
