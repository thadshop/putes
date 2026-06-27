#!/usr/bin/env bash

echo "$(date) firing ${0}" >> /home/thad/log/tevent.log

# For an explanation of this, refer to "remapping mouse buttons.txt" in my "Toolbox" under "Linux PC".

#######################################
#
# DEPENDENCY: ${HOME}/etc/my_xbindkeys_rc.txt
#
#######################################

MOUSE_LISTING_REGEX='\S   \S Logitech Performance MX\s+id=[1-9][0-9]*\s+\[slave\s+pointer\s+\([0-9]+\)\]'

for mouseID in $(xinput list | egrep "${MOUSE_LISTING_REGEX}" | cut -d= -f2 | awk '{print $1}'); do
    xinput set-button-map ${mouseID} 1 16 3 4 5 6 7 8 9 2 11 12 13 14 15 16 17 18 19 20
done

if [[ $(pgrep xbindkeys) ]]; then
    killall xbindkeys
fi
xbindkeys --file "${HOME}/etc/my_xbindkeys_rc.txt"
