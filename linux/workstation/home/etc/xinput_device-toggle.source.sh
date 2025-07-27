# This is Bash shell code sourced by:
#   ~/bin/touchpad-toggle
#   ~/bin/trackpoint-toggle

case "${1}" in
    enable | disable )
        TOGGLE_TO="${1}"
        ;;
    * )
        echo "ERROR: valid options are 'enable' or 'disable'"
        exit 1
        ;;
esac
for deviceID in $(xinput list | egrep "${DEVICE_LISTING_REGEX}" | cut -d= -f2 | awk '{print $1}'); do
    xinput --${TOGGLE_TO} ${deviceID}
    echo "${DEVICE_MONIKER} ${TOGGLE_TO}d (device ID ${deviceID})"
done
