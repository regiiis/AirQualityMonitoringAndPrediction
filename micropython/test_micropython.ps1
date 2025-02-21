# Configuration
$BAUD_RATE = 115200
$TEST_COMMAND = "import sys; print('MicroPython ' + sys.version)"

function Get-ESP32Port {
    Write-Host "Getting ESP32..." -ForegroundColor Blue
    $ports = Get-CimInstance -ClassName Win32_SerialPort |
            Where-Object { $_.Name -like '*Arduino*' -or $_.Name -like '*USB*' -or $_.Name -like '*CP210*' }

    if (-not $ports) {
        Write-Host "No ESP32 found! Available ports:" -ForegroundColor Red
        [System.IO.Ports.SerialPort]::GetPortNames() | ForEach-Object { Write-Host "  $_" }
        exit 1
    }

    if ($ports.Count -gt 1) {
        Write-Host "Multiple possible devices found:" -ForegroundColor Yellow
        $ports | ForEach-Object { Write-Host "  $($_.DeviceID) - $($_.Description)" }
        $portName = Read-Host "Enter port name to use"
        return $portName
    }

    $port = $ports[0].DeviceID
    Write-Host "Found ESP32 at: $port" -ForegroundColor Green
    return $port
}

function Test-MicroPython {
    param($port)
    Write-Host "`nTesting MicroPython installation on port $port..." -ForegroundColor Blue

    try {
        $serial = New-Object System.IO.Ports.SerialPort $port, $BAUD_RATE
        $serial.ReadTimeout = 2000
        $serial.WriteTimeout = 2000
        $serial.DtrEnable = $true
        $serial.RtsEnable = $true

        Write-Host "Opening serial connection..." -ForegroundColor Blue
        $serial.Open()
        Start-Sleep -Milliseconds 500

        # Clear any pending input
        while ($serial.BytesToRead -gt 0) {
            $null = $serial.ReadExisting()
        }

        # Send test command
        Write-Host "Sending test command..." -ForegroundColor Blue
        $serial.WriteLine($TEST_COMMAND)
        Start-Sleep -Milliseconds 500

        # Read response
        $response = ""
        $retries = 3
        while ($retries -gt 0) {
            try {
                while ($serial.BytesToRead -gt 0) {
                    $response += $serial.ReadExisting()
                }
                if ($response) { break }
                Start-Sleep -Milliseconds 500
                $retries--
            }
            catch {
                $retries--
                Start-Sleep -Milliseconds 500
            }
        }

        # Analyze response
        if ($response -match "MicroPython \d+\.\d+\.\d+") {
            Write-Host "`nMicroPython detected!" -ForegroundColor Green
            Write-Host "Version: $($matches[0])" -ForegroundColor Green
            return $true
        }
        elseif ($response -match ">>>") {
            Write-Host "`nMicroPython REPL detected but version check failed." -ForegroundColor Yellow
            Write-Host "Raw response: $response" -ForegroundColor Gray
            return $true
        }
        else {
            Write-Host "`nMicroPython not detected." -ForegroundColor Red
            Write-Host "Raw response: $response" -ForegroundColor Gray
            return $false
        }
    }
    catch {
        Write-Host "`nError testing MicroPython: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    finally {
        if ($serial -and $serial.IsOpen) {
            $serial.Close()
            $serial.Dispose()
        }
    }
}

# Main test process
try {
    $port = Get-ESP32Port
    $result = Test-MicroPython $port

    if ($result) {
        Write-Host "`nTest Result: MicroPython is correctly installed." -ForegroundColor Green
    } else {
        Write-Host "`nTest Result: MicroPython is not installed or not responding correctly." -ForegroundColor Red
        Write-Host "You may need to run install.ps1 to install or repair MicroPython." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "An error occurred: $_" -ForegroundColor Red
}
