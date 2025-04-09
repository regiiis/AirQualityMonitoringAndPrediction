<#
.SYNOPSIS
    Script to clean MicroPython files from ESP32 devices using ampy.
.DESCRIPTION
    Handles the removal process of MicroPython files from ESP32, deleting all
    user files and directories while preserving system files.
#>

function Get-ESP32Port {
    <#
    .SYNOPSIS
        Detects and returns the COM port for connected ESP32.
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
    #>
    param($port, $arguments)

    try {
        $cmdOutput = & python -m ampy.cli --port $port $arguments 2>&1
        $success = $LASTEXITCODE -eq 0

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

function Clean-ESP32 {
    <#
    .SYNOPSIS
        Cleans MicroPython files from ESP32 using ampy.
    #>
    param($port)

    Write-Host "Installing ampy if not already present..." -ForegroundColor Blue
    python -m pip install adafruit-ampy --quiet

    Write-Host "Cleaning ESP32 filesystem..." -ForegroundColor Yellow

    try {
        # First get a list of files and directories at the root
        $result = Execute-Ampy -port $port -arguments @("ls")

        if (-not $result.Success) {
            Write-Host "Error listing files: $($result.Output)" -ForegroundColor Red
            return $false
        }

        $items = $result.Output -split "`n" | Where-Object { $_ -ne "" }

        # Filter out system files
        $userItems = $items | Where-Object {
            $_ -ne "/boot.py" -and
            $_ -ne "/boot_out.txt"
        }

        # First remove files at the root
        foreach ($item in $userItems) {
            $isTryingDir = $false

            try {
                # Check if it's a directory by trying to list it
                $checkDirResult = Execute-Ampy -port $port -arguments @("ls", $item)
                $isTryingDir = $checkDirResult.Success

                if ($isTryingDir) {
                    # It's a directory, get its contents
                    $subItems = $checkDirResult.Output -split "`n" | Where-Object { $_ -ne "" }

                    # Remove all files in the directory first
                    foreach ($subItem in $subItems) {
                        $fullPath = "$item/$subItem"
                        Write-Host "Removing file: $fullPath" -ForegroundColor Blue
                        $rmResult = Execute-Ampy -port $port -arguments @("rm", $fullPath)

                        if ($rmResult.Success) {
                            Write-Host "Successfully removed $fullPath" -ForegroundColor Green
                        } else {
                            Write-Host "Failed to remove $fullPath" -ForegroundColor Yellow
                        }

                        Start-Sleep -Milliseconds 500
                    }

                    # Then remove the directory
                    Write-Host "Removing directory: $item" -ForegroundColor Blue
                    $rmdirResult = Execute-Ampy -port $port -arguments @("rmdir", $item)

                    if ($rmdirResult.Success) {
                        Write-Host "Successfully removed directory $item" -ForegroundColor Green
                    } else {
                        Write-Host "Failed to remove directory $item" -ForegroundColor Yellow
                    }
                } else {
                    # It's a file
                    Write-Host "Removing file: $item" -ForegroundColor Blue
                    $rmResult = Execute-Ampy -port $port -arguments @("rm", $item)

                    if ($rmResult.Success) {
                        Write-Host "Successfully removed $item" -ForegroundColor Green
                    } else {
                        Write-Host "Failed to remove $item" -ForegroundColor Yellow
                    }
                }
            }
            catch {
                if ($isTryingDir) {
                    Write-Host "Error processing directory $item : $_" -ForegroundColor Yellow
                } else {
                    # Try to remove it as a file anyway
                    Write-Host "Removing file: $item" -ForegroundColor Blue
                    $rmResult = Execute-Ampy -port $port -arguments @("rm", $item)

                    if ($rmResult.Success) {
                        Write-Host "Successfully removed $item" -ForegroundColor Green
                    } else {
                        Write-Host "Failed to remove $item" -ForegroundColor Yellow
                    }
                }
            }

            Start-Sleep -Milliseconds 500
        }

        # Check for known directories that might not be empty
        $knownDirs = @("/modules", "/data_collection", "/data_transmission")

        foreach ($dir in $knownDirs) {
            try {
                # Check if directory exists
                $checkDirResult = Execute-Ampy -port $port -arguments @("ls", $dir)

                if ($checkDirResult.Success) {
                    # Directory exists, try to clean it
                    Write-Host "Attempting to clean directory $dir..." -ForegroundColor Blue

                    # Get list of files in the directory
                    $subItems = $checkDirResult.Output -split "`n" | Where-Object { $_ -ne "" }

                    # Remove each file
                    foreach ($subItem in $subItems) {
                        $fullPath = "$dir/$subItem"
                        Write-Host "Removing file: $fullPath" -ForegroundColor Blue
                        $rmResult = Execute-Ampy -port $port -arguments @("rm", $fullPath)

                        if ($rmResult.Success) {
                            Write-Host "Successfully removed $fullPath" -ForegroundColor Green
                        } else {
                            # Try again but as a directory
                            $rmdirResult = Execute-Ampy -port $port -arguments @("rmdir", $fullPath)
                            if ($rmdirResult.Success) {
                                Write-Host "Successfully removed directory $fullPath" -ForegroundColor Green
                            } else {
                                Write-Host "Failed to remove $fullPath" -ForegroundColor Yellow
                            }
                        }

                        Start-Sleep -Milliseconds 500
                    }

                    # Now try to remove the directory itself
                    $rmdirResult = Execute-Ampy -port $port -arguments @("rmdir", $dir)

                    if ($rmdirResult.Success) {
                        Write-Host "Successfully removed directory $dir" -ForegroundColor Green
                    } else {
                        Write-Host "Failed to remove directory $dir" -ForegroundColor Yellow
                    }
                }
            }
            catch {
                Write-Host "Error processing directory $dir : $_" -ForegroundColor Yellow
            }

            Start-Sleep -Milliseconds 500
        }

        Write-Host "ESP32 cleanup complete." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Error during cleanup: $_" -ForegroundColor Red
        return $false
    }
}

function Reset-ESP32 {
    <#
    .SYNOPSIS
        Reboots the ESP32 device programmatically using direct serial connection.
    #>
    param($port)

    Write-Host "Rebooting ESP32 after cleanup..." -ForegroundColor Blue
    try {
        python -m pip install pyserial --quiet

        $resetScript = @"
import serial
import time

try:
    ser = serial.Serial('$port', 115200, timeout=1)
    time.sleep(0.5)

    # Send Ctrl+C to interrupt any running program
    ser.write(b'\x03\x03')
    time.sleep(0.5)

    # Send reset commands
    ser.write(b'import machine\r\n')
    time.sleep(0.5)
    ser.write(b'machine.reset()\r\n')
    time.sleep(0.5)

    ser.close()
    exit(0)
except Exception as e:
    print(f"Error: {e}")
    exit(1)
"@

        $tempFile = [System.IO.Path]::GetTempFileName() + ".py"
        $resetScript | Out-File -FilePath $tempFile -Encoding utf8

        python $tempFile
        Remove-Item -Path $tempFile -Force

        Write-Host "Reset command sent. ESP32 should reboot momentarily." -ForegroundColor Green
        Start-Sleep -Seconds 5
        return $true
    }
    catch {
        Write-Host "Error during reset: $_" -ForegroundColor Red

        Write-Host "Please reset your ESP32 manually by pressing the reset button." -ForegroundColor Yellow
        Read-Host "Press Enter after resetting the device"
        return $true
    }
}

function Verify-CleanState {
    <#
    .SYNOPSIS
        Verifies if the ESP32 filesystem is clean of user files using ampy.
    #>
    param($port)

    Write-Host "Verifying clean state..." -ForegroundColor Blue
    try {
        $result = Execute-Ampy -port $port -arguments @("ls")

        if (-not $result.Success) {
            Write-Host "Error listing files during verification." -ForegroundColor Red
            return $false
        }

        $items = $result.Output -split "`n" | Where-Object { $_ -ne "" }

        # Filter out system files
        $userItems = $items | Where-Object {
            $_ -ne "/boot.py" -and
            $_ -ne "/boot_out.txt"
        }

        $userItemCount = ($userItems | Measure-Object).Count

        if ($userItemCount -eq 0) {
            Write-Host "Verification successful! No user files or directories remain." -ForegroundColor Green
            return $true
        } else {
            Write-Host "Verification found $userItemCount remaining items:" -ForegroundColor Yellow
            foreach ($item in $userItems) {
                Write-Host "  - $item" -ForegroundColor Yellow
            }
            return $false
        }
    }
    catch {
        Write-Host "Error during verification: $_" -ForegroundColor Red
        return $false
    }
}

# Main execution flow
try {
    Write-Host "ESP32 MicroPython Cleaner" -ForegroundColor Cyan
    Write-Host "------------------------" -ForegroundColor Cyan
    Write-Host "WARNING: This will delete all user files from your ESP32!" -ForegroundColor Red
    $confirmation = Read-Host "Do you want to continue? (y/n)"

    if ($confirmation -ne "y") {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        exit 0
    }

    $port = Get-ESP32Port

    # Perform the cleaning
    $cleanResult = Clean-ESP32 -port $port

    # Reset device after cleaning
    Reset-ESP32 -port $port

    # Give device time to reboot before verification
    Write-Host "Waiting for device to reboot..." -ForegroundColor Blue
    Start-Sleep -Seconds 5

    # Verify clean state
    $verificationResult = Verify-CleanState -port $port

    if ($verificationResult) {
        Write-Host "Cleanup operation fully successful!" -ForegroundColor Green
    } else {
        Write-Host "Cleanup finished but some items might remain." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "An error occurred: $_" -ForegroundColor Red
    exit 1
}
