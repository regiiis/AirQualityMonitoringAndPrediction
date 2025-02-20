# Variables
PORT ?= /dev/ttyUSB0  # Default Linux port, override with PORT=/dev/ttyUSB1
FIRMWARE_URL := https://micropython.org/resources/firmware/ESP32_GENERIC-20240105-v1.22.1.bin
FIRMWARE := ESP32_GENERIC.bin
PYTHON := python3
ESPTOOL := esptool.py

# Auto-detect port (add before other targets)
detect_port:
	@echo "Detecting ESP32 port..."
	@if uname -r | grep -i microsoft > /dev/null; then \
		echo "Running in WSL, detecting ports via PowerShell..."; \
		echo "Available ports:"; \
		powershell.exe -Command "Get-CimInstance -ClassName Win32_SerialPort | Format-Table Name, DeviceID" 2>/dev/null || echo "No ports available"; \
		PORT=$$(powershell.exe -Command "Get-CimInstance -ClassName Win32_SerialPort | Where-Object { \$$_.Name -like '*Arduino*' -or \$$_.Name -like '*USB*' -or \$$_.Name -like '*CP210*' } | Select-Object -First 1 -ExpandProperty DeviceID"); \
		if [ ! -z "$$PORT" ]; then \
			echo "Found ESP32 at: $$PORT"; \
			echo "WSL port will be: /dev/ttyS$$(echo $$PORT | grep -o '[0-9]*')"; \
		else \
			echo "No ESP32 found. Please check:"; \
			echo "1. Device is connected"; \
			echo "2. Device is recognized in Windows"; \
			echo "3. Run 'make detect_port' again after connecting the device"; \
			PORT=/dev/ttyUSB0; \
		fi \
	else \
		echo "Running on native Linux"; \
		if ls /dev/ttyUSB* 1> /dev/null 2>&1; then \
			echo "Found USB devices:"; \
			ls -l /dev/ttyUSB*; \
			PORT=$$(ls /dev/ttyUSB* | head -n1); \
			echo "Using: $$PORT"; \
		else \
			echo "No USB devices found. Please check connection."; \
			echo "Will use default port: /dev/ttyUSB0"; \
			PORT=/dev/ttyUSB0; \
		fi \
	fi

.PHONY: all clean download flash install setup detect_port setup_wifi

all: detect_port setup flash

setup:
	$(PYTHON) -m pip install -r requirements.txt

download:
	wget -O $(FIRMWARE) $(FIRMWARE_URL)

flash: download
	$(PYTHON) -m $(ESPTOOL) --chip esp32 --port $(PORT) erase_flash
	$(PYTHON) -m $(ESPTOOL) --chip esp32 --port $(PORT) --baud 460800 write_flash -z 0x1000 $(FIRMWARE)

# Add new target for WiFi setup
setup_wifi:
	@if [ -z "$$WIFI_SSID" ]; then \
		read -p "Enter WiFi SSID: " ssid; \
		export WIFI_SSID=$$ssid; \
	fi
	@if [ -z "$$WIFI_PASSWORD" ]; then \
		stty -echo; \
		read -p "Enter WiFi Password: " pwd; \
		stty echo; \
		echo ""; \
		export WIFI_PASSWORD=$$pwd; \
	fi

# Modify upload target to include WiFi setup
upload: setup_wifi
	WIFI_SSID="$$WIFI_SSID" WIFI_PASSWORD="$$WIFI_PASSWORD" ampy --port $(PORT) put sensor/main.py

clean:
	rm -f $(FIRMWARE)

# Modify install target to include WiFi setup
install: setup setup_wifi download flash upload
