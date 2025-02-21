# Configuration
$INSTALLER_REPO = "https://github.com/arduino/lab-micropython-installer.git"
$INSTALLER_DIR = "micropython-installer-arduino"
$DRIVER_URL = "https://www.silabs.com/documents/public/software/CP210x_Universal_Windows_Driver.zip"
$DRIVER_ZIP = "CP210x_Universal_Windows_Driver.zip"
$DRIVER_FOLDER = "CP210x_Universal_Windows_Driver"

function Check-Prerequisites {
    Write-Host "Checking prerequisites..." -ForegroundColor Blue

    # Check if Git is installed
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "Git is not installed. Please install Git from https://git-scm.com/" -ForegroundColor Red
        exit 1
    }

    # Check if Node.js is installed
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        Write-Host "Node.js is not installed. Please install Node.js from https://nodejs.org/" -ForegroundColor Red
        exit 1
    }

    # Check if npm is installed
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Host "npm is not installed. Please install Node.js from https://nodejs.org/" -ForegroundColor Red
        exit 1
    }
}

function Install-MicroPython {
    Write-Host "Setting up Arduino Lab MicroPython Installer..." -ForegroundColor Blue

    # Clone the repository if it doesn't exist
    if (-not (Test-Path $INSTALLER_DIR)) {
        git clone $INSTALLER_REPO $INSTALLER_DIR
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Error cloning repository!" -ForegroundColor Red
            exit 1
        }
    }

    # Navigate to the installer directory
    Push-Location $INSTALLER_DIR

    try {
        # Install dependencies
        Write-Host "Installing dependencies..." -ForegroundColor Blue
        npm install
        if ($LASTEXITCODE -ne 0) {
            throw "Error installing dependencies"
        }

        # Start the installer
        Write-Host "Starting Arduino Lab MicroPython Installer..." -ForegroundColor Green
        Write-Host "Please follow the GUI instructions to install MicroPython." -ForegroundColor Yellow
        npm run start
        if ($LASTEXITCODE -ne 0) {
            throw "Error running the installer"
        }
    }
    catch {
        Write-Host "Error: $_" -ForegroundColor Red
        exit 1
    }
    finally {
        # Return to original directory
        Pop-Location
    }
}

function Get-ESP32Port {
    Write-Host "Getting ESP32..." -ForegroundColor Blue
    $port = Get-CimInstance -ClassName Win32_SerialPort |
            Where-Object { $_.Name -like '*Arduino*' -or $_.Name -like '*USB*' -or $_.Name -like '*CP210*' } |
            Select-Object -First 1 -ExpandProperty DeviceID

    if ($port) {
        Write-Host "Found ESP32 at: $port" -ForegroundColor Green
        Start-Sleep -Seconds 3  # Add delay after port detection
        return $port
    }
    Write-Host "No ESP32 found! Please check connection." -ForegroundColor Red
    exit 1
}

function Test-MicroPython {
    param($port)
    Write-Host "Checking for existing MicroPython installation..." -ForegroundColor Blue

    try {
        # Initialize serial connection
        $serial = New-Object System.IO.Ports.SerialPort $port, 115200
        $serial.ReadTimeout = 1000
        $serial.WriteTimeout = 1000
        $serial.DtrEnable = $true
        $serial.RtsEnable = $true

        # Open port and send Enter to trigger REPL
        $serial.Open()
        Start-Sleep -Milliseconds 500
        $serial.WriteLine("`r`n")
        Start-Sleep -Milliseconds 500

        # Read response
        $response = ""
        try {
            while ($serial.BytesToRead -gt 0) {
                $response += $serial.ReadExisting()
            }
        }
        catch {
            # Ignore timeout exceptions
        }

        # Check for MicroPython prompt
        if ($response -match ">>>" -or $response -match "MicroPython") {
            Write-Host "MicroPython is already installed!" -ForegroundColor Green
            return $true
        }

        Write-Host "MicroPython not detected." -ForegroundColor Yellow
        return $false
    }
    catch {
        Write-Host "Error checking MicroPython: $_" -ForegroundColor Yellow
        return $false
    }
    finally {
        if ($serial -and $serial.IsOpen) {
            $serial.Close()
            $serial.Dispose()
        }
    }
}

# Main installation process
try {
    Check-Prerequisites
    $port = Get-ESP32Port

    # Check if MicroPython is already installed
    $micropythonInstalled = Test-MicroPython $port

    if (-not $micropythonInstalled) {
        Write-Host "MicroPython not found. Starting installation..." -ForegroundColor Yellow
        Install-MicroPython
        Start-Sleep -Seconds 3  # Wait for device to reset after installation

        # Verify installation
        if (Test-MicroPython $port) {
            Write-Host "MicroPython installation successful!" -ForegroundColor Green
        } else {
            Write-Host "MicroPython installation could not be verified." -ForegroundColor Red
        }
    } else {
        Write-Host "MicroPython is already installed." -ForegroundColor Green
    }
}
catch {
    Write-Host "An error occurred: $_" -ForegroundColor Red
}
