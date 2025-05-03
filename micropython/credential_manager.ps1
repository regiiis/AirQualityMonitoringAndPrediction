<#
.SYNOPSIS
    Manages credentials stored in ESP32 secure storage.
.DESCRIPTION
    Lists and deletes credentials (WiFi settings, API keys) stored in ESP32's NVS.
#>

# Configuration
$BAUD_RATE = 115200

function Initialize-Python {
    Write-Host "Setting up Python environment..." -ForegroundColor Blue
    python -m pip install --upgrade pip --quiet
    python -m pip install pyserial adafruit-ampy --quiet
}

function Get-ESP32Port {
    Write-Host "Detecting ESP32..." -ForegroundColor Blue
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

function Execute-REPL-Command {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Port,
        [Parameter(Mandatory=$true)]
        [string]$Command
    )

    # Create a temporary Python script to execute via ampy
    $tempFile = New-TemporaryFile
    $pythonScript = @"
from modules.secure_storage import SecureStorage
storage = SecureStorage()
$Command
"@
    Set-Content -Path $tempFile.FullName -Value $pythonScript

    # Execute using ampy
    $result = & python -m ampy.cli --port $Port run $tempFile.FullName 2>&1
    Remove-Item $tempFile -Force

    return $result
}

function Get-StoredCredentials {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Port
    )

    Write-Host "Checking for stored credentials..." -ForegroundColor Blue

    # Check WiFi credentials
    $wifiCommand = @"
ssid, password = storage.get_credentials()
if ssid and password:
    print(f"WiFi credentials found:")
    print(f"SSID: {ssid}")
    print(f"Password: {'*' * len(password)}")
else:
    print("No WiFi credentials found")
"@
    $wifiResult = Execute-REPL-Command -Port $Port -Command $wifiCommand
    Write-Host $wifiResult

    # Check API key
    $apiKeyCommand = @"
api_key = storage.get_api_key()
if api_key:
    print(f"API Key found: {'*' * 4}{api_key[-4:]}")
else:
    print("No API Key found")
"@
    $apiKeyResult = Execute-REPL-Command -Port $Port -Command $apiKeyCommand
    Write-Host $apiKeyResult

    # Return if credentials exist
    $hasWifi = $wifiResult -match "WiFi credentials found"
    $hasApiKey = $apiKeyResult -match "API Key found"

    return @{
        HasWifi = $hasWifi
        HasApiKey = $hasApiKey
    }
}

function Remove-Credentials {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Port,
        [Parameter(Mandatory=$true)]
        [string]$CredentialType
    )

    switch ($CredentialType) {
        "wifi" {
            $command = @"
if storage.clear_credentials():
    print("WiFi credentials successfully deleted")
else:
    print("Failed to delete WiFi credentials")
"@
        }
        "apikey" {
            $command = @"
if storage.clear_api_key():
    print("API key successfully deleted")
else:
    print("Failed to delete API key")
"@
        }
        "all" {
            $command = @"
wifi_result = storage.clear_credentials()
api_result = storage.clear_api_key()
if wifi_result and api_result:
    print("All credentials successfully deleted")
elif wifi_result:
    print("WiFi credentials deleted, but API key deletion failed")
elif api_result:
    print("API key deleted, but WiFi credentials deletion failed")
else:
    print("Failed to delete credentials")
"@
        }
    }

    $result = Execute-REPL-Command -Port $Port -Command $command
    Write-Host $result -ForegroundColor Green
}

# Main script execution
try {
    Clear-Host
    Write-Host "===== ESP32 Credential Manager =====" -ForegroundColor Cyan

    Initialize-Python
    $port = Get-ESP32Port

    # Get current credentials
    $credentials = Get-StoredCredentials -Port $port

    # Prompt for action
    Write-Host "`nSelect credentials to delete:" -ForegroundColor Yellow
    Write-Host "1: WiFi credentials" -ForegroundColor White
    Write-Host "2: API Key" -ForegroundColor White
    Write-Host "3: All credentials" -ForegroundColor White
    Write-Host "4: Exit without deleting" -ForegroundColor White

    $choice = Read-Host "Enter your choice (1-4)"

    switch ($choice) {
        "1" {
            if ($credentials.HasWifi) {
                $confirm = Read-Host "Are you sure you want to delete WiFi credentials? (y/n)"
                if ($confirm -eq "y") {
                    Remove-Credentials -Port $port -CredentialType "wifi"
                }
            } else {
                Write-Host "No WiFi credentials to delete." -ForegroundColor Yellow
            }
        }
        "2" {
            if ($credentials.HasApiKey) {
                $confirm = Read-Host "Are you sure you want to delete the API key? (y/n)"
                if ($confirm -eq "y") {
                    Remove-Credentials -Port $port -CredentialType "apikey"
                }
            } else {
                Write-Host "No API key to delete." -ForegroundColor Yellow
            }
        }
        "3" {
            if ($credentials.HasWifi -or $credentials.HasApiKey) {
                $confirm = Read-Host "Are you sure you want to delete ALL credentials? (y/n)"
                if ($confirm -eq "y") {
                    Remove-Credentials -Port $port -CredentialType "all"
                }
            } else {
                Write-Host "No credentials to delete." -ForegroundColor Yellow
            }
        }
        "4" {
            Write-Host "Exiting without changes." -ForegroundColor Green
        }
        default {
            Write-Host "Invalid choice. Exiting." -ForegroundColor Red
        }
    }

    # Verify final state
    Write-Host "`nFinal credential state:" -ForegroundColor Cyan
    Get-StoredCredentials -Port $port

} catch {
    Write-Host "An error occurred: $_" -ForegroundColor Red
} finally {
    Write-Host "`nScript completed. You may close this window." -ForegroundColor Green
}
