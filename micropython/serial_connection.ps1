# Serial Connection Configuration
$BAUD_RATE = 115200
$DATA_BITS = 8
$STOP_BITS = [System.IO.Ports.StopBits]::One
$PARITY = [System.IO.Ports.Parity]::None

function Get-AvailablePorts {
    Write-Host "Available COM ports:" -ForegroundColor Blue
    $ports = [System.IO.Ports.SerialPort]::GetPortNames()
    foreach ($p in $ports) {
        Write-Host "  - $p"
    }
    return $ports
}

function Connect-ToESP32 {
    param (
        [Parameter(Mandatory=$true)]
        [string]$PortName
    )

    try {
        $script:port = New-Object System.IO.Ports.SerialPort $PortName, $BAUD_RATE, $PARITY, $DATA_BITS, $STOP_BITS
        $script:port.ReadTimeout = 1000
        $script:port.WriteTimeout = 1000
        $script:port.DtrEnable = $true
        $script:port.RtsEnable = $true

        $script:port.Open()
        Write-Host "Connected to $PortName successfully!" -ForegroundColor Green
        return $true
    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-Host "Error connecting to $PortName`: $errorMessage" -ForegroundColor Red
        return $false
    }
}

function Send-Command {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Command
    )

    if (-not $script:port -or -not $script:port.IsOpen) {
        Write-Host "Error: Not connected to any port" -ForegroundColor Red
        return
    }

    try {
        $script:port.WriteLine($Command)
        Start-Sleep -Milliseconds 100

        # Read response
        $response = ""
        while ($script:port.BytesToRead -gt 0) {
            $response += $script:port.ReadExisting()
        }

        if ($response) {
            Write-Host "Response:" -ForegroundColor Green
            Write-Host $response
        }
    }
    catch {
        Write-Host "Error sending command: $_" -ForegroundColor Red
    }
}

function Disconnect-FromESP32 {
    if ($script:port -and $script:port.IsOpen) {
        $script:port.Close()
        $script:port.Dispose()
        Write-Host "Disconnected from port." -ForegroundColor Yellow
    }
}

function Get-ESP32Port {
    Write-Host "Detecting ESP32..." -ForegroundColor Blue
    $ports = Get-CimInstance -ClassName Win32_SerialPort |
            Where-Object { $_.Name -like '*Arduino*' -or $_.Name -like '*USB*' -or $_.Name -like '*CP210*' }

    if (-not $ports) {
        Write-Host "No ESP32 found! Available ports:" -ForegroundColor Red
        [System.IO.Ports.SerialPort]::GetPortNames() | ForEach-Object { Write-Host "  $_" }
        exit 1
    }

    # Take the first matching port
    $port = $ports[0].DeviceID
    Write-Host "Found ESP32 at: $port" -ForegroundColor Green
    return $port
}

function Start-InteractiveSession {
    $ports = Get-AvailablePorts
    if ($ports.Count -eq 0) {
        Write-Host "No COM ports found!" -ForegroundColor Red
        return
    }

    $portName = Get-ESP32Port
    if (Connect-ToESP32 $portName) {
        Write-Host "`nInteractive Session Started" -ForegroundColor Green
        Write-Host "Enter commands to send to ESP32 (type 'exit' to quit)`n" -ForegroundColor Yellow

        while ($true) {
            $command = Read-Host "ESP32>"
            if ($command -eq "exit") {
                break
            }
            Send-Command $command
        }

        Disconnect-FromESP32
    }
}

# Clean up on script exit
Register-EngineEvent PowerShell.Exiting -Action {
    Disconnect-FromESP32
} | Out-Null

# Start interactive session if script is run directly
if ($MyInvocation.InvocationName -ne ".") {
    Start-InteractiveSession
}
