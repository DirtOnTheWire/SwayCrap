#!/usr/bin/env bash

profile="$(powerprofilesctl get 2>/dev/null || echo unknown)"

case "$profile" in
  performance)
    echo "PERF"
    ;;
  balanced)
    echo "BAL"
    ;;
  power-saver)
    echo "SAVE"
    ;;
  *)
    echo "PWR"
    ;;
esac
