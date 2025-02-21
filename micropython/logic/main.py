import network
import time
from secure_storage import SecureStorage


def check_wifi_status(wlan):
    if not wlan.active():
        return "WiFi interface inactive"
    if not wlan.isconnected():
        return "WiFi disconnected"

    status = wlan.status()
    if status == network.STAT_IDLE:
        return "WiFi idle"
    elif status == network.STAT_CONNECTING:
        return "WiFi connecting..."
    elif status == network.STAT_WRONG_PASSWORD:
        return "WiFi wrong password"
    elif status == network.STAT_NO_AP_FOUND:
        return "WiFi no access point found"
    elif status == network.STAT_CONNECT_FAIL:
        return "WiFi connection failed"
    elif status == network.STAT_GOT_IP:
        return f"WiFi connected - IP: {wlan.ifconfig()[0]}"

    return f"WiFi unknown status: {status}"


def connect_wifi():
    # Get credentials from secure storage
    storage = SecureStorage()
    ssid, password = storage.get_credentials()

    if not ssid or not password:
        raise Exception("WiFi credentials not found in secure storage")

    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)

    if not wlan.isconnected():
        print(f"Connecting to network: {ssid}...")
        wlan.connect(ssid, password)

        # Wait for connection with timeout
        max_wait = 10
        while max_wait > 0:
            status = check_wifi_status(wlan)
            print(status)
            if wlan.isconnected():
                break
            max_wait -= 1
            time.sleep(1)

        if not wlan.isconnected():
            raise Exception("Failed to connect to WiFi")

    return wlan, ssid


def main():
    wlan = None
    ssid = None

    try:
        # Connect to WiFi using secure storage
        wlan, ssid = connect_wifi()
        if not wlan or not ssid:
            raise Exception("Failed to get WiFi connection details")

        # Main monitoring loop
        print("Starting WiFi monitoring...")
        while True:
            status = check_wifi_status(wlan)
            print(status)
            if wlan.isconnected():
                print(f"Connected to: {ssid}")
            else:
                print("Not connected to any network")
            time.sleep(5)

    except Exception as e:
        print(f"Error: {e}")
        if wlan:
            wlan.disconnect()
        while True:
            print("Error state - WiFi configuration failed")
            time.sleep(10)


if __name__ == "__main__":
    main()
