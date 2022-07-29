# Failsafe systemd service for OpenStick


This is a fail-safe service for OpenStick devices running debian.

## Main features

+ If no network connection (wifi and usb gadget) 1 min after boot up,
  the script will try to open fail-safe network connections.
+ If the device is connected to a host device, it'll try to activate
  the USB gadget mode.
+ If the device is connected to a USB gadget, it WON'T try to activate the
  USB gadget mode.
+ If USB gadget mode and RNDIS interface cannot enable, the script will try
  to open an Access Point and open the serial terminal at `/dev/ttyMSM0`
    + Access Point's name defaults to `openstick-failsafe`, and password is
      `12345678`

## How to use
 
```bash
apt install -y gawk  # required
cp openstick-gc-guard.service openstick-gc-guard.timer /etc/systemd/system/
cp openstick-gc-guard.sh /usr/sbin/
chmod +x /usr/sbin/openstick-gc-guard.sh
systemctl enable openstick-gc-guard.timer
```

