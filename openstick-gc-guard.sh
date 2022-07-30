#!/usr/bin/env sh
## A program detects network connection and reinitiate USB
## gadget mode if not connected.


GADGET_CONTROL="/usr/bin/gc"
FAILSAFE_AP_CON="failsafe-ap"
FAILSAFE_AP_SSID="openstick-failsafe"
FAILSAFE_AP_PASSWORD="12345678"
FAILSAFE_AP_CHANNEL="3"
FAILSAFE_AP_ADDRESS="192.168.69.1/24"

get_usb_role() {
  cat /sys/kernel/debug/usb/ci_hdrc.0/role
}

is_gadeget_mode() {
  [ "gadget" = "$(get_usb_role)" ]
}

is_host_mode() {
  [ "host" = "$(get_usb_role)" ]
}

is_usb_connected() {
  # get status from usb registers, return normal(0) if connected
  # else suspended or disabled
  # following EHCI standard
  # 0x4 PE bit 1 mask
  # 0x80 SUSP bit 1 mask

  # PE | SUSP | STATUS
  # 0  |  x   | Disabled
  # 1  |  0   | Enabled(conncected)
  # 1  |  1   | Suspended

  # Connected to a HOST device in HOST mode is not considered connected,
  # so it's safe to use this function to check current USB status.

  CMP_VALUE=$(awk '/^PORTSC.*/{ a = strtonum("0x" $3); exit } END { b = and(a, 0x4); c = and(a, 0x80); if (c == 0) { print b } else { print 0 }  }' /sys/kernel/debug/usb/ci_hdrc.0/registers)
  if [ 0 -eq "$CMP_VALUE" ] ; then
    return 1  # not connected
  else
    return 0  # connected
  fi
}

is_wifi_connected() {
  nmcli device | awk '{print $2, $3}' | grep -E -- "wifi" | grep " connected" > /dev/null
}

is_ethernet_connected() {
  # exclude usb interfaces
  nmcli device | awk '{print $1, $2, $3}' | grep -E -- "ethernet" | grep -i -v -- "usb" | grep " connected" > /dev/null
}

is_usb_net_connected() {
  nmcli device | awk '{print $1, $2, $3}' | grep -E -- "usb" | grep " connected" > /dev/null
}

is_device_online() {
  # if no error, the device is online
  if is_wifi_connected || is_ethernet_connected ; then
    return 0  # has wifi(AP/station), or USB ethernet card connected (NOT RNDIS gadget mode)
  elif is_usb_net_connected && is_gadeget_mode && is_usb_connected ; then
    return 0  # gadget mode and connected
  else
    return 1  # well, offline, disconnected, whatever
  fi
}

setup_gadget_rndis_network() {
  # Setup the usb gadget internet interface if device is not
  # connected to any USB gadgets as a host.

  # Test if host mode and connected to other gadget device.
  # If so, abort. So connected usb devices will still work.
  # Note: connection to a host device in host mode is treated
  # as disconnected, so don't worry about that.
  if is_host_mode && is_usb_connected ; then
    return 1
  fi

  echo "gadget" > /sys/kernel/debug/usb/ci_hdrc.0/role
  $GADGET_CONTROL -d        # disable all
  $GADGET_CONTROL -c        # cleanup
  $GADGET_CONTROL -a rndis  # RNDIS network adapter
  $GADGET_CONTROL -e        # enable gadget
  if nmcli connection up USB ; then
    # Linked up using default configuration.
    return 0
  else
    # Failed, either missing connection configuration
    # named USB in NetworkManager, or a potential USB failure.
    return 1
  fi
}

setup_failsafe_ap() {
  # Setup a failsafe AP with known password for recovery

  ### setup a failsafe ap ###
  # it seems a password is required or NM just fails TvT

  # delete old connection anyway
  nmcli connection delete $FAILSAFE_AP_CON > /dev/null

  # setup connection
  # note: ipv4.method must be shared or will be likely to
  # conflict with other existing connections
  nmcli connection add \
    type wifi ifname wlan0 con-name "$FAILSAFE_AP_CON" \
    ssid "$FAILSAFE_AP_SSID" autoconnect no \
    ipv4.addresses "$FAILSAFE_AP_ADDRESS" \
    ipv4.method shared \
    wifi.mode ap \
    wifi.band bg wifi.channel "$FAILSAFE_AP_CHANNEL" \
    wifi-sec.key-mgmt wpa-psk \
    wifi-sec.proto rsn \
    wifi-sec.group ccmp wifi-sec.pairwise ccmp \
    wifi-sec.psk "$FAILSAFE_AP_PASSWORD"
  nmcli connection up "$FAILSAFE_AP_CON"
} 

setup_serial_ttyMSM0() {
  # anyway we are saving the device, don't lose a chance
  [ -e /dev/ttyMSM0 ] && systemctl enable --now getty@ttyMSM0.service
}

main() {
  if is_device_online ; then
    logger "Device online, good to go."
    return 0  # device online
  fi
  
  # oops, device offline, try manual activation
  logger "Device offline, trying to activate USB RNDIS interface."
  if setup_gadget_rndis_network && is_device_online ; then
    logger "Device back online now. Lucky!"
    return 0
  fi

  # oops, all failed
  # activating fail-safe interfaces
  logger "Device offline and cannot open RNDIS interface, activating fail-safe interfaces"
  logger "Activating serial console"
  setup_serial_ttyMSM0
  logger "Activating fail-safe AP"
  setup_failsafe_ap
}

# start routine
main

