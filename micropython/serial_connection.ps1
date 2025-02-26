<#
.SYNOPSIS
    Establishes a serial connection to ESP32 devices.
.DESCRIPTION
    Provides a simple way to connect to ESP32 devices via serial REPL.
#>

# Configuration
$LOGIC_DIR = "./logic"
$MAIN_SCRIPT = "main.py"
# Remove direct ampy command and use python -m ampy instead
$AMPY_CMD = "python"

# Serial Connection Configuration
$BAUD_RATE = 115200

function Initialize-Python {
    <#
    .SYNOPSIS
        Initializes Python environment for serial communication.
    .DESCRIPTION
        Ensures pyserial is installed for communication with ESP32.
    #>
    Write-Host "Setting up Python environment..." -ForegroundColor Blue
    python -m pip install --upgrade pip --quiet
    python -m pip install pyserial --quiet
}

function Get-AvailablePorts {
    <#
    .SYNOPSIS
        Lists all available COM ports.
    .DESCRIPTION
        Retrieves and displays a list of all available serial ports
        on the system.
    .OUTPUTS
        Array of available COM port names.
    #>
    Write-Host "Available COM ports:" -ForegroundColor Blue
    $ports = [System.IO.Ports.SerialPort]::GetPortNames()
    foreach ($p in $ports) {
        Write-Host "  - $p"
    }
    return $ports
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

function Send-Command {
    <#
    .SYNOPSIS
        Sends a command to ESP32 via REPL.
    .PARAMETER Command
        The command to execute on ESP32.
    .PARAMETER Port
        The COM port where ESP32 is connected.
    .DESCRIPTION
        Executes a specified command on the ESP32 through REPL
        and returns the response.
    #>
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
    <#
    .SYNOPSIS
        Detects and returns the COM port for connected ESP32.
    .DESCRIPTION
        Searches through available serial ports to find an ESP32 device.
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

function Connect-ESP32REPL {
    <#
    .SYNOPSIS
        Connects to ESP32 REPL using miniterm.
    .PARAMETER port
        The COM port where ESP32 is connected.
    .PARAMETER baudRate
        Baud rate for the serial connection.
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$port,
        [int]$baudRate = 115200
    )

    Write-Host "Connecting to REPL using miniterm..." -ForegroundColor Blue
    Write-Host "Press Ctrl+] to exit miniterm." -ForegroundColor Yellow
    python -m serial.tools.miniterm $port $baudRate
}

# Clean up on script exit
Register-EngineEvent PowerShell.Exiting -Action {
    Disconnect-FromESP32
} | Out-Null

# Main execution
try {
    Initialize-Python
    $port = Get-ESP32Port
    Connect-ESP32REPL -port $port -baudRate $BAUD_RATE
}
catch {
    Write-Host "An error occurred: $_" -ForegroundColor Red
}
