<#
.SYNOPSIS
    Manages credentials stored in ESP32 secure storage.
.DESCRIPTION
    Lists and deletes credentials (WiFi settings, API credentials) stored in ESP32's NVS.
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

    # Simple Python script to check all credentials with clean error handling
    $checkCredentialsCommand = @"
# Check WiFi credentials
try:
    ssid, password = storage.get_credentials()
    if ssid and password:
        print("WIFI_STATUS:FOUND")
        print(f"WiFi credentials found:")
        print(f"SSID: {ssid}")
        print(f"Password: {'*' * len(password)}")
    else:
        print("WIFI_STATUS:NONE")
        print("No WiFi credentials found")
except Exception as e:
    print("WIFI_STATUS:ERROR")
    print(f"Error checking WiFi credentials: {e}")

# Check API credentials
try:
    api_key, api_endpoint = storage.get_api_info()
    if api_key and api_endpoint:
        print("API_STATUS:FOUND")
        print(f"API credentials found:")
        print(f"API Key: {'*' * (len(api_key)-4)}{api_key[-4:]}")
        print(f"API Endpoint: {api_endpoint}")
    else:
        print("API_STATUS:NONE")
        print("No API credentials found")
except Exception as e:
    print("API_STATUS:ERROR")
    print(f"Error checking API credentials: {e}")
"@

    $result = Execute-REPL-Command -Port $Port -Command $checkCredentialsCommand
    Write-Host $result

    # Parse results using simple markers
    $hasWifi = $result -match "WIFI_STATUS:FOUND"
    $hasApiKey = $result -match "API_STATUS:FOUND"

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

    $command = switch ($CredentialType) {
        "wifi" { @"
if storage.clear_credentials():
    print("WiFi credentials successfully deleted")
else:
    print("Failed to delete WiFi credentials")
"@
        }
        "apikey" { @"
if storage.clear_api_credentials():
    print("API credentials successfully deleted")
else:
    print("Failed to delete API credentials")
"@
        }
        "all" { @"
wifi_result = storage.clear_credentials()
api_result = storage.clear_api_credentials()
if wifi_result and api_result:
    print("All credentials successfully deleted")
elif wifi_result:
    print("WiFi credentials deleted, but API credentials deletion failed")
elif api_result:
    print("API credentials deleted, but WiFi credentials deletion failed")
else:
    print("Failed to delete credentials")
"@
        }
        default { "print('Invalid credential type specified')" }
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
    Write-Host "2: API credentials" -ForegroundColor White
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
                $confirm = Read-Host "Are you sure you want to delete the API credentials? (y/n)"
                if ($confirm -eq "y") {
                    Remove-Credentials -Port $port -CredentialType "apikey"
                }
            } else {
                Write-Host "No API credentials to delete." -ForegroundColor Yellow
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
