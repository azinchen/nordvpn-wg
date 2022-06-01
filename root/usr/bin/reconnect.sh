#!/command/with-contenv bash

[[ "${DEBUG,,}" == trace* ]] && set -x

createvpnconfig.sh

echo "Reconnect to selected VPN server"
s6-svc -h /run/service/nordvpnd

exit 0
