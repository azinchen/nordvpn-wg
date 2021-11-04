#!/usr/bin/with-contenv bash

[[ "${DEBUG,,}" == trace* ]] && set -x

createvpnconfig.sh

echo "Reconnect to selected VPN server"

exit 0
