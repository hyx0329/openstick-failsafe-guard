#!/usr/bin/env sh
## A program detects network connection and reinitiate USB
## gadget mode if not connected.


GADGET_CONTROL=/usr/bin/gc
FAILSAFE_AP_CON=failsafe-ap
FAILSAFE_AP_SSID=openstick-failsafe
FAILSAFE_AP_PASSWORD="12345678"
FAILSAFE_AP_CHANNEL=3
FAILSAFE_AP_ADDRESS="192.168.69.1/24"

test_usb_gadget_disconnected() {
  # return normal(0) if in gadget mode and port is suspend(disconnected)
  CMP_VALUE=$(awk '/^PORTSC.*/{ a = strtonum("0x" $3); exit } END { print and(a, 0x880) }' /sys/kernel/debug/usb/ci_hdrc.0/registers)
  STATUS=$(cat /sys/kernel/debug/usb/ci_hdrc.0/role)
  if [ 2176 -eq "$CMP_VALUE" ] && [ "gadget" = "$STATUS" ] ; then
    return 0
  fi
  return 1
}

test_usb_host_connected() {
  CMP_VALUE=$(awk '/^PORTSC.*/{ a = strtonum("0x" $3); exit } END { b = and(a, 0x800); c = and(a, 0x80); if (or(b,c) == b) { print b } else { print 0 }  }' /sys/kernel/debug/usb/ci_hdrc.0/registers)
  STATUS=$(cat /sys/kernel/debug/usb/ci_hdrc.0/role)
  if [ 0 -ne "$CMP_VALUE" ] && [ "host" = "$STATUS" ] ; then
    return 0
  fi
  return 1
}

test_usb_connection_status() {
  # if return 0(no error), then the usb is CONNECTED as a HOST

  # WARNING: Requires gawk! must be explictly installed!
  if awk -W version | grep -i -- GNU Awk ; then
    CMP_VALUE=$(awk '/^PORTSC.*/{ a = strtonum("0x" $3); exit } END { print and(a, 0x80) }' /sys/kernel/debug/usb/ci_hdrc.0/registers)
    if [ 0 -eq "$CMP_VALUE" ] ; then
      return 1  # not connected
    else
      return 0  # connected
    fi
  else
    logger "Warning: Please install gawk explictly to make the detection correct!"
    return 1  # awk not supported, default not connected
  fi
}

test_required_connection_nmcli() {
  # if no error, the device is online

  if nmcli device | awk '{print $2, $3}' | grep -E -- "wifi" | grep " connected" > /dev/null ; then
    return 0  # has wifi(AP/station) or ethernet(usb)
  elif nmcli device | awk '{print $2, $3}' | grep -E -- "ethernet" | grep " connected" > /dev/null ; then
    # we need to test if usb is connected
    if test_usb_connection_status ; then
      return 0  # gadget mode and connected
    else
      return 1  # gadget mode but disconnected
    fi
  else
    return 1  # well, offline, disconnected, whatever
  fi
}

setup_gadget_rndis_network() {
  # Test if host mode and connected to other gadget device.
  # If so, abort.
  # This won't block if device in host mode and connected
  # to a host device.
  if test_usb_host_connected ; then
    return 1
  fi

  echo "gadget" > /sys/kernel/debug/usb/ci_hdrc.0/role
  $GADGET_CONTROL -d        # disable all
  $GADGET_CONTROL -c        # cleanup
  $GADGET_CONTROL -a rndis  # RNDIS network adapter
  $GADGET_CONTROL -e        # enable gadget
  if nmcli connection up USB ; then
    # Linked up using default configuration
    return 0
  else
    # Failed, either missing configuration or USB failure
    return 1
  fi
}

setup_failsafe_ap() {
  # have to manually activate the network
  # use a fail-safe hotspot

  ### setup a failsafe ap ###
  # have to use a password or NM just fails TvT

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
  if test_required_connection_nmcli ; then
    logger "Device online, no action."
    return 0  # device online
  fi
  
  # oops, device offline, try manual activation
  logger "Device offline, trying to activate USB RNDIS interface."
  if setup_gadget_rndis_network ; then
    if test_required_connection_nmcli ; then
      logger "Device back online."
      return 0
    fi
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

