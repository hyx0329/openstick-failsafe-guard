# Failsafe systemd service for OpenStick

This repo has evolved into a collection of tool scripts/services to
help playing with MSM8916 sticks. Some are fail-safe services to regain
access to the device, the others may be utilities to help the system
runs better.

## how to create deb packages

Just run (on a system with dpkg-deb, fakeroot, gnumake)

```sh
make all-deb
```

then you'll find the packages at the root of the repo.

## Main features and usages
 
### openstick-startup-diagnose

+ If no network connection (wifi, ethernet or usb gadget) is detected,
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
+ Test if modem is working as expected. If not, try to recover by restarting
  ModemManager.
+ Executed 1 min after boot up.

__WARNING: If you set up a CUSTOM AP, the SCRIPT will assume that the device is ONLINE! So please remember your AP's password!__

#### usage

```bash
apt install -y gawk  # required
cp openstick-gc-guard.service openstick-gc-guard.timer /etc/systemd/system/
cp openstick-gc-guard.sh /usr/sbin/
chmod +x /usr/sbin/openstick-gc-guard.sh
systemctl enable openstick-gc-guard.timer
```

### reset button monitor

Monitor the reset button and trigger relevant actions. The defined action will be
excuted directly(in posix shell). If you decide to modify the action to "exit 0",
it will exit.

#### usage

```bash
apt install -y bsdmainutils bc  # required: hexdump, bc(calculator)
cp openstick-button-monitor.service /etc/systemd/system/
cp openstick-button-monitor.sh /usr/sbin/
systemctl enable --now openstick-button-monitor.service
```

You might want to edit the environment variables through systemd to
define your button behavior. ~~Defaults to do nothing except logging.~~
Long-press behavior changed to activate the failsafe access point.

With supported kernel, the led will on while the button is pressed,
until the long-press time threshold has been exceeded.

### openstick-gc-startup

Test and enable USB gadget mode if USB is not connected or connected to a host
machine. Predefined action is to enable RNDIS and ADB interface.

#### usage

Enable the service and edit the Environment in the service unit script.

### openstick-sim-changer

Switch sim card according to the configuration at startup, for UFI001/UFI003
series. ~~This also ensures the sim card is fully powered up so ModemManager
don't need to be restarted after boot up.~~ That's a complicated issue.

Note that I'm not aware of any method to reload the sim card info without a
reboot, so I created this service to switch the sim cards before ModemManager
initialize the modem.

#### usage

Enable the service and edit the Environment in the service unit script.

### Others

Not useful for most users, as they are intended to help a new installation setup.

## Notes

### How to modify the environment variables in systemd service

see https://serverfault.com/questions/413397/how-to-set-environment-variable-in-systemd-service
 
## TODOs

+ [ ] enable a Bluetooth network interface
+ [x] enable ADB interface
+ [x] use environment variables defined in the service script
+ [ ] packaging(deb)
  - [x] packed in package
  - [ ] follow packaging guide?
