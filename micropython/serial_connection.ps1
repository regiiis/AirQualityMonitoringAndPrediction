# Configuration
$LOGIC_DIR = "./logic"
$MAIN_SCRIPT = "main.py"
# Remove direct ampy command and use python -m ampy instead
$AMPY_CMD = "python"

# Serial Connection Configuration
$BAUD_RATE = 115200

function Initialize-Python {
    Write-Host "Setting up Python environment..." -ForegroundColor Blue
    python -m pip install --upgrade pip --quiet
    python -m pip install adafruit-ampy --quiet
    python -m pip install pyserial --quiet

    # Verify ampy installation
    python -m pip show adafruit-ampy
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: adafruit-ampy not properly installed!" -ForegroundColor Red
        exit 1
    }
}

function Get-AvailablePorts {
    Write-Host "Available COM ports:" -ForegroundColor Blue
    $ports = [System.IO.Ports.SerialPort]::GetPortNames()
    foreach ($p in $ports) {
        Write-Host "  - $p"
    }
    return $ports
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

function Send-Command {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Command,
        [Parameter(Mandatory=$true)]
        [string]$Port
    )

    # Construct the ampy command to execute the given command
    $ampyCommand = "repl -c `"$Command`""

    # Execute the ampy command
    $result = Execute-Ampy -port $Port -arguments $ampyCommand.Split(" ")

    # Output the result
    if ($result) {
        Write-Host "Response:" -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Host "No response or error occurred." -ForegroundColor Red
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

# Clean up on script exit
Register-EngineEvent PowerShell.Exiting -Action {
    Disconnect-FromESP32
} | Out-Null

# Main execution
try {
    Initialize-Python
    $port = Get-ESP32Port

    if ($port) {
        Write-Host "Connecting to REPL using miniterm..." -ForegroundColor Blue
        Write-Host "Press Ctrl+] to exit miniterm." -ForegroundColor Yellow
        python -m serial.tools.miniterm $port $BAUD_RATE
    }
}
catch {
    Write-Host "An error occurred: $_" -ForegroundColor Red
}
