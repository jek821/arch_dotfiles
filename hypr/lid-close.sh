#!/bin/bash
# only disable the panel if an external monitor is present
if hyprctl monitors -j | grep -q '"name": "HDMI'; then
    echo 'monitor = eDP-1, disable' > ~/.config/hypr/edp-state.conf
    hyprctl reload
fi
