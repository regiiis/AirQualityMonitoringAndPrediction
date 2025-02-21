import network
import time
import os


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


def connect_wifi(ssid: str, password: str):
    if not ssid or not password:
        raise Exception("WiFi credentials not found in environment variables")

    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)

    if not wlan.isconnected():
        print("Connecting to network...")
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

    return wlan


def main():
    try:
        # Get credentials from environment variables
        ssid = os.getenv("WIFI_SSID")
        password = os.getenv("WIFI_PASSWORD")
        if not ssid or not password:
            raise Exception("WiFi credentials not found in environment variables")

        # Connect to WiFi
        wlan = connect_wifi(ssid, password)

        # Main monitoring loop
        print("Starting WiFi monitoring...")
        while True:
            status = check_wifi_status(wlan)
            print(status)
            print(f"SSID - {ssid}")
            time.sleep(5)

    except Exception as e:
        print(f"Error: {e}")
        while True:
            print("Error state - WiFi configuration failed")
            print(f"SSID - {ssid}")
            time.sleep(5)


if __name__ == "__main__":
    main()
