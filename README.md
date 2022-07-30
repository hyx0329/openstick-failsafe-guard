# Failsafe systemd service for OpenStick

This is a fail-safe service for MSM8919 devices running debian with systemd.

## Main features

+ If no network connection (wifi, ethernet or usb gadget) 1 min after boot up,
  the script will try to re-enable network connections.
  + If the device is connected to a host device, it'll try to activate
    the USB gadget mode.
  + If the device is connected to any USB gadget __as a HOST__, it WON'T
    try to activate the USB gadget mode, to make sure connected devices
    working properly(so you can use USB ethernet adapters, etc.).
  + If USB gadget RNDIS interface cannot enable or not connected, the
    script will try to open an Access Point and open the serial terminal
    at `/dev/ttyMSM0`
    + Access Point's name defaults to `openstick-failsafe`, and password is
      `12345678`

__WARNING: If you set up a CUSTOM AP, the SCRIPT will assume that the device is ONLINE! So please remember your AP's password!__

## How to use
 
```bash
apt install -y gawk  # required
cp openstick-gc-guard.service openstick-gc-guard.timer /etc/systemd/system/
cp openstick-gc-guard.sh /usr/sbin/
chmod +x /usr/sbin/openstick-gc-guard.sh
systemctl enable openstick-gc-guard.timer
```
 
## TODOs

+ [ ] enable a Bluetooth network interface
+ [ ] use environment variables defined in the service script

