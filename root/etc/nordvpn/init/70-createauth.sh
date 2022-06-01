#!/command/with-contenv bash

[[ "${DEBUG,,}" == trace* ]] && set -x

authfile="/tmp/auth"

echo "Create auth file"

echo "$USER" > "$authfile"
echo "$PASS" >> "$authfile"
chmod 0600 "$authfile"

exit 0
