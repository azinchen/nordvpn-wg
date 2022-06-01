#!/command/with-contenv bash

shopt -s globstar
for i in /etc/nordvpn/init/*.sh; do # Whitespace-safe and recursive
    echo "*** Process file ""$i"" ***"
    sh -c "$i"
done
