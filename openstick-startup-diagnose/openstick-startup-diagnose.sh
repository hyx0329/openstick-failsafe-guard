#!/usr/bin/env sh
## A program detects network connection and reinitiate USB
## gadget mode if not connected.

# Change variables below in a systemd service overlay.
# command: systemctl --edit openstick-gc-guard.service

GADGET_CONTROL=${GADGET_CONTROL:-"/usr/bin/gc"}
FAILSAFE_AP_CON=${FAILSAFE_AP_CON:-"failsafe-ap"}
FAILSAFE_AP_SSID=${FAILSAFE_AP_SSID:-"openstick-failsafe"}
FAILSAFE_AP_PASSWORD=${FAILSAFE_AP_PASSWORD:-"12345678"}
FAILSAFE_AP_CHANNEL=${FAILSAFE_AP_CHANNEL:-"3"}
FAILSAFE_AP_ADDRESS=${FAILSAFE_AP_ADDRESS:-"192.168.69.1/24"}

# make sure the output is English
unset LANGUAGES
export LANG=C

UDC_SYSFS=/sys/class/udc/ci_hdrc.0
USB_DEBUG=/sys/kernel/debug/usb/ci_hdrc.0
USB_ROLE_DEBUG=$UDC_SYSFS/device/role
USB_REGISTER_DEBUG=$USB_DEBUG/registers
CONFIGFS_GADGET=/sys/kernel/config/usb_gadget

get_usb_role() {
  cat ${USB_ROLE_DEBUG}
}

is_gadget_mode() {
  [ "gadget" = "$(get_usb_role)" ]
}

is_host_mode() {
  [ "host" = "$(get_usb_role)" ]
}

set_usb_mode() {
  CURRENT_USB_ROLE=$(get_usb_role)
  logger "Changing USB from $CURRENT_USB_ROLE mode to $1 mode"
  if [ "$1" = "$CURRENT_USB_ROLE" ]; then
    return
  fi
  echo "$1" > ${USB_ROLE_DEBUG}
  return $?
}

set_usb_gadget_mode() {
  set_usb_mode "gadget"
}

set_usb_host_mode() {
  set_usb_mode "host"
}

is_usb_connected_legacy() {
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

  CMP_VALUE=$(gawk '/^PORTSC.*/{ a = strtonum("0x" $3); exit } END { b = and(a, 0x4); c = and(a, 0x80); if (c == 0) { print b } else { print 0 }  }' ${USB_REGISTER_DEBUG})
  if [ 0 -eq "$CMP_VALUE" ] ; then
    return 1  # not connected
  else
    return 0  # connected
  fi
}

is_usb_connected() {
  if is_gadget_mode; then
    if [ "configured" = "$(cat ${UDC_SYSFS}/state)" ]; then
      return 0  # connected
    else
      return 1  # disconnected
    fi
  elif is_host_mode; then
    is_usb_connected_legacy
    return $?
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

is_adbd_running() {
  pgrep adbd
}

is_gadget_has_rndis() {
  ${GADGET_CONTROL} -l | grep -- "type: rndis" > /dev/null
  return $?
}

add_usb_net() {
  nmcli con del usb-failsafe
  nmcli con add \
    type ethernet ifname usb0 con-name "usb-failsafe" \
    ipv4.addresses "192.168.68.1/24" \
    ipv4.method shared autoconnect yes
}

is_device_online() {
  # if no error, the device is online
  if is_wifi_connected || is_ethernet_connected ; then
    return 0  # has wifi(AP/station), or USB ethernet card connected (NOT RNDIS gadget mode)
  elif is_usb_net_connected && is_gadget_mode && is_usb_connected ; then
    return 0  # gadget mode and connected
  elif is_gadget_mode && is_usb_connected && is_adbd_running && is_gadget_has_rndis ; then
    # has rndis interface, adbd is running, but no usb ethernet
    # activate it and return OK
    # it's ok to fail here
    add_usb_net
    nmcli con up usb-failsafe
    return 0
  else
    return 1  # well, offline, disconnected, whatever
  fi
}

is_modem_crashed() {
  if dmesg | grep -- "crash detected in 4080000.remoteproc" > /dev/null ; then
    return 0
  else
    return 1
  fi
}

is_modemmanager_running() {
  if systemctl status ModemManager | grep -- "Active: active (running)" > /dev/null ; then
    return 0
  else
    return 1
  fi
}

is_modem_registered() {
  if mmcli -L | grep -- "/org/freedesktop/ModemManager1/Modem" > /dev/null ; then
    return 0
  else
    return 1
  fi
}

has_modem_interface() {
  if test -e /dev/wwan0qmi0 ; then
    return 0
  else
    return 1
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

  set_usb_gadget_mode

  $GADGET_CONTROL -d        # disable all
  $GADGET_CONTROL -c        # cleanup
  $GADGET_CONTROL -a rndis  # RNDIS network adapter
  $GADGET_CONTROL -e        # enable gadget

  add_usb_net

  if nmcli connection up usb-failsafe ; then
    # Linked up using default configuration.
    return 0
  else
    # Failed, either missing connection configuration
    return 1
  fi
}

setup_failsafe_ap() {
  # Setup a failsafe AP with known password for recovery

  ### setup a failsafe ap ###
  # it seems a password is required or NM just fails TvT

  # delete old connection anyway
  nmcli connection delete "$FAILSAFE_AP_CON" > /dev/null

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

restart_modemmanager() {
  systemctl restart ModemManager
}

diagnose_network() {
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

diagnose_modem() {
  # The modems on MSM8916 platforms may reset themselves if using a sim
  # card from some carriers. The log says "THIS IS INTENTIONAL RESET,
  # NO RAMDUMP EXPECTED", but the system treat it as crashed. ModemManager
  # disable the QMI interface after the qmi-proxy's connection broken,
  # and will not recover without a service restart. This could be a MM's
  # bug but for the momemnt, there's no easy way to work around.

  if is_modem_crashed ; then
    logger "Oops, it seems the modem crashed before, will investigate."
  fi

  if is_modemmanager_running ; then
    if has_modem_interface && ! is_modem_registered ; then
      logger "Modem is not registered by ModemManager, possibly missed."
      logger "Try to recover by restarting the service."
      restart_modemmanager
      return
    fi
  fi

  logger "Modem looks fine, no action taken."
}

main() {
  logger "Network diagnose start."
  diagnose_network
  logger "Network diagnose complete."

  logger "Modem diagnose start."
  diagnose_modem
  logger "Modem diagnose complete."
}


# start routine
main

