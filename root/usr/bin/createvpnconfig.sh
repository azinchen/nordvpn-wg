#!/usr/bin/with-contenv bash

[[ "${DEBUG,,}" == trace* ]] && set -x

nvcountries=$(cat /etc/nordvpn/countries.json | jq -c '.[]')
nvgroups=$(cat /etc/nordvpn/groups.json | jq -c '.[]')
nvtechnologies=$(cat /etc/nordvpn/technologies.json | jq -c '.[]')

numericregex="^[0-9]+$"

wgfile="/etc/wireguard/wg0.conf"

getcountryid()
{
    input=$1

    if [[ "$input" =~ $numericregex ]]; then
        id=$(echo "$nvcountries" | jq -r --argjson ID $input 'select(.id == $ID) | .id')
    else
        id=$(echo "$nvcountries" | jq -r --arg NAME "$input" 'select(.name == $NAME) | .id')
        if [ -z "$id" ]; then
            id=$(echo "$nvcountries" | jq -r --arg CODE "$input" 'select(.code == $CODE) | .id')
        fi
    fi

    printf "$id"

    if [ -z "$id" ]; then
        return 1
    fi

    return 0
}

getcountryname()
{
    input=$1

    if [[ "$input" =~ $numericregex ]]; then
        name=$(echo "$nvcountries" | jq -r --argjson ID $input 'select(.id == $ID) | .name')
    else
        name=$(echo "$nvcountries" | jq -r --arg NAME "$input" 'select(.name == $NAME) | .name')
        if [ -z "$name" ]; then
            name=$(echo "$nvcountries" | jq -r --arg CODE "$input" 'select(.code == $CODE) | .name')
        fi
    fi

    printf "$name"

    if [ -z "$name" ]; then
        return 1
    fi

    return 0
}

getgroupid()
{
    input=$1

    if [[ "$input" =~ $numericregex ]]; then
        id=$(echo "$nvgroups" | jq -r --argjson ID $input 'select(.id == $ID) | .id')
    else
        id=$(echo "$nvgroups" | jq -r --arg TITLE "$input" 'select(.title == $TITLE) | .id')
        if [ -z "$id" ]; then
            id=$(echo "$nvgroups" | jq -r --arg IDENTIFIER "$input" 'select(.identifier == $IDENTIFIER) | .id')
        fi
    fi

    printf "$id"

    if [ -z "$id" ]; then
        return 1
    fi

    return 0
}

getgrouptitle()
{
    input=$1

    if [[ "$input" =~ $numericregex ]]; then
        title=$(echo "$nvgroups" | jq -r --argjson ID $input 'select(.id == $ID) | .title')
    else
        title=$(echo "$nvgroups" | jq -r --arg TITLE "$input" 'select(.title == $TITLE) | .title')
        if [ -z "$id" ]; then
            title=$(echo "$nvgroups" | jq -r --arg IDENTIFIER "$input" 'select(.identifier == $IDENTIFIER) | .title')
        fi
    fi

    printf "$title"

    if [ -z "$title" ]; then
        return 1
    fi

    return 0
}

echo "Select NordVPN server and create config file"

filterserver="filters\[servers_technologies\]\[id\]=35"

IFS=';'
read -ra RA_GROUPS <<< $GROUP
for value in "${RA_GROUPS[@]}"; do
    if [ ! -z "$value" ]; then
        echo "Apply filter group \"$(getgrouptitle $value)\""
        filterserver="$filterserver""&filters\[servers_groups\]\[id\]=$(getgroupid "$value")"
    fi
done

servers=""

echo "Request list of recommended servers"
if [ -z "$COUNTRY" ]; then
    servers=$(curl -s "https://api.nordvpn.com/v1/servers/recommendations?"$filterserver"" | jq -c '.[]')
    echo "Request nearest servers, "$(echo "$servers" | jq -s 'length')" servers received"
else
    read -ra RA_COUNTRIES <<< $COUNTRY
    for value in "${RA_COUNTRIES[@]}"; do
        if [ ! -z "$value" ]; then
            countryid=$(getcountryid $value)
            serversincountry=$(curl -s "https://api.nordvpn.com/v1/servers/recommendations?"$filterserver"&filters\[country_id\]="$countryid"" | jq -c '.[]')
            echo "Request servers in \"$(getcountryname "$value")\", "$(echo "$serversincountry" | jq -s 'length')" servers received"
            servers="$servers""$serversincountry"
        fi
    done
fi

poollength=$(echo "$servers" | jq -s 'unique | length')
servers=$(echo "$servers" | jq -s -c 'unique | sort_by(.load) | .[]')

if [[ !($RANDOM_TOP -eq 0) ]]; then
    if [[ $RANDOM_TOP -lt poollength ]]; then
        filtered=$(echo $servers | head -n $RANDOM_TOP | shuf)
        servers="$filtered"$(echo $servers | tail -n +$((RANDOM_TOP + 1)))
    else
        servers=$(echo $servers | shuf)
    fi
fi

echo "$poollength"" recommended servers in pool"
if [[ !($poollength -eq 0) ]]; then
    echo "--- Top 20 servers in filtered pool ---"
    echo $(echo $servers | jq -r '[.hostname, .load] | "\(.[0]): \(.[1])"' | head -n 20)
    echo "---------------------------------------"
fi

if [[ $poollength -eq 0 ]]; then
    echo "ERROR: list of selected servers is empty"
fi

server=$(echo $servers | head -n 1)
serverip=$(echo $server | jq -r '.station')
name=$(echo $server | jq -r '.name')
hostname=$(echo $server | jq -r '.hostname')
publickey=$(echo $server |  jq -r '.technologies | .[] | select(.id == 35) | .metadata | .[].value')

echo "Select server \""$name"\" hostname=\""$hostname"\" ip="$serverip" protocol=\"Wireguard\" public key=\""$publickey"\""

echo "[Interface]" > "$wgfile"
echo "PrivateKey = "$PRIVATE_KEY"" >> "$wgfile"
echo "" >> "$wgfile"
echo "[Peer]" >> "$wgfile"
echo "PublicKey = "$publickey"" >> "$wgfile"
echo "AllowedIPs = 0.0.0.0/0, ::/0" >> "$wgfile"
echo "Endpoint = "$serverip":51820" >> "$wgfile"
echo "PersistentKeepalive = 25" >> "$wgfile"

exit 0
