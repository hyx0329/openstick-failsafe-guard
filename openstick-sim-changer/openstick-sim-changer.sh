#!/bin/sh

LED_PATH=/sys/class/leds
SIM_ENABLED=${SIM_ENABLED:-sim0}

get_sims() {
  # shellcheck disable=SC2010
  ls /sys/class/leds | grep sim
}

disable_all_sim() {
  for sim in $(get_sims) ; do
    echo 0 > "$LED_PATH/$sim/brightness"
  done
}

enable_sim() {
  #echo 1 > "$LED_PATH/sim_enable/brightness"
  disable_all_sim
  sim="$(get_sims | grep -e "^$1")"
  echo 1 > "$LED_PATH/$sim/brightness"
  #echo 0 > "$LED_PATH/sim_enable/brightness"
}

main() {
  enable_sim "$SIM_ENABLED"

  # Wait a few seconds before SIM card powered up.
  # This is required or you have to manually restart ModemManager.
  sleep 5
}

main

