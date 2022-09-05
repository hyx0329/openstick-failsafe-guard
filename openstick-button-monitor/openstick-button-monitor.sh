#!/usr/bin/env sh

DEFAULT_EV_INPUT=$(readlink -f /dev/input/by-path/platform-gpio-keys-event)
DEFAULT_EV_KEY_CODE=408  # KEY_RESET
DEFAULT_PRESS_LONG_DELAY=5  # second
DEFAULT_ACTION_SHORT="logger default short press action"
DEFAULT_ACTION_LONG="action_enable_failsafe_ap"

EV_INPUT=${EV_INPUT:-$DEFAULT_EV_INPUT}
EV_KEY_CODE=${EV_KEY_CODE:-$DEFAULT_EV_KEY_CODE}
PRESS_LONG_DELAY=${PRESS_LONG_DELAY:-$DEFAULT_PRESS_LONG_DELAY}
PRESS_ACTION_SHORT=${PRESS_ACTION_SHORT:-$DEFAULT_ACTION_SHORT}
PRESS_ACTION_LONG=${PRESS_ACTION_LONG:-$DEFAULT_ACTION_LONG}
# This one below can be overwritten to a plain value
INDICATOR_LED=${INDICATOR_LED-"/sys/class/leds/green:/brightness"}

# copied from openstick-gc-guard
FAILSAFE_AP_CON=${FAILSAFE_AP_CON:-"failsafe-ap"}
FAILSAFE_AP_SSID=${FAILSAFE_AP_SSID:-"openstick-failsafe"}
FAILSAFE_AP_PASSWORD=${FAILSAFE_AP_PASSWORD:-"12345678"}
FAILSAFE_AP_CHANNEL=${FAILSAFE_AP_CHANNEL:-"3"}
FAILSAFE_AP_ADDRESS=${FAILSAFE_AP_ADDRESS:-"192.168.69.1/24"}

# Runtime variables
export EVENT_TIME_START=0
export EVENT_LONG_PRESS=0


set_led() {
  if [ ! -e "$INDICATOR_LED" ] ; then
    return
  fi

  if [ "on" = "$1" ] ; then
    echo 1 > "$INDICATOR_LED"
  else
    echo 0 > "$INDICATOR_LED"
  fi
}


action_enable_failsafe_ap() {
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

action_enable_rndis_and_adb() {
  echo "not implemented"
}

do_action_short() {
  $PRESS_ACTION_SHORT
  return $?
}

test_action_long() {
  CURRENT_TIME=$1
  COMPARE_RESULT=$(echo "$EVENT_TIME_START + $PRESS_LONG_DELAY < $CURRENT_TIME" | bc )
  if [ 1 -eq "$COMPARE_RESULT" ] ; then
    return 0  # long enough
  else
    return 1  # not long enough
  fi
}

do_action_long() {
  $PRESS_ACTION_LONG
  return $?
}

do_monitor_key_event() {
  # format: llHHI, l: long int, H: usigned short, I: unsigned int
  # explain: time(second), time(usecond), type, code, value
  # events with code, type, value == 0 are "separators"
  # have to turn off the buffer, or at least change to line buffer(here)
  # The work around won't affect statically linked programs, be careful
  # stdbuf is part of GNU core utils, and is available on most *nix
  # https://unix.stackexchange.com/questions/25372/turn-off-buffering-in-pipe
  stdbuf -oL -eL -- hexdump -e '2/8 "%d " 2/2 " %d" 1/4 " %d " "\n"' "$EV_INPUT"
}

handle_key_up_event() {
  # measure time, do coresponding tasks, and clean up

  set_led off  # an indicator first

  # if a short press, do short job
  # if a long press, test if time delay enough
  case $EVENT_LONG_PRESS in
    (0)
      do_action_short "$1" "$2"
      CODE=$?
      if [ 0 -ne $CODE ] ; then
        logger "Error occured when executing short press action! code=$CODE"
      fi
      ;;
    (1)
      if test_action_long "$1" "$2" ; then
        do_action_long "$1" "$2"
        CODE=$?
        if [ 0 -ne $CODE ] ; then
          logger "Error occured when executing long press action! code=$CODE"
        fi
      else
        logger "Press time not long enough to trigger the long press action."
      fi
      ;;
  esac
}

handle_key_down_event() {
  # set key down time (start time)
  export EVENT_TIME_START="$1"
  export EVENT_LONG_PRESS=0
}

handle_key_long_press_event() {
  export EVENT_LONG_PRESS=1
  if test_action_long "$1" "$2"; then
    set_led off
  else
    set_led on
  fi
}

handle_key_event() {
  # handle incoming key events

  EVENT_TIME=$1
  EVENT_UTIME=$2
  EVENT_TYPE=$3
  EVENT_CODE=$4
  EVENT_VALUE=$5

  # filter the separators
  if [ 0 -ne "$EVENT_TYPE" ] || [ 0 -ne "$EVENT_CODE" ] || [ 0 -ne "$EVENT_VALUE" ] ; then
    ### process the event ###
    if [ "$EVENT_CODE" -ne "$EV_KEY_CODE" ] ; then
      # not expected input
      return
    fi

    case $EVENT_VALUE in
      (0)
        # key up event
        handle_key_up_event "$EVENT_TIME" "$EVENT_UTIME"
        ;;
      (1)
        # key down event
        handle_key_down_event "$EVENT_TIME" "$EVENT_UTIME"
        ;;
      (2)
        # key long press (and repeated) event
        handle_key_long_press_event "$EVENT_TIME" "$EVENT_UTIME"
        ;;
    esac
    ### end process the event ###
  fi
}

main() {
  logger "Start monitoring key $EV_KEY_CODE at $EV_INPUT"
  do_monitor_key_event | while read line ; do
    # don't quote $line as it's passed as a tuple of 5
    handle_key_event $line
  done
}

# Start the main routine
main

