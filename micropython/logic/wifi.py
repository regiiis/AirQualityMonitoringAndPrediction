import network  # type: ignore
import time


def check_wifi_status(wlan):
    if not wlan.active():
        return "WiFi interface inactive"
    if not wlan.isconnected():
        return "WiFi disconnected"

    status = wlan.status()
    print(f"WiFi status: {status}")


def connect_wifi(ssid, password):
    if not ssid or not password:
        raise Exception("WiFi credentials not found in secure storage")

    if not isinstance(ssid, str) or not isinstance(password, str):
        raise Exception("WiFi credentials not a string")

    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)

    time.sleep(1)
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
            time.sleep(2)

        if not wlan.isconnected():
            raise Exception("Failed to connect to WiFi")

    return wlan, ssid
