#!/bin/sh
. /lib/functions.sh

NFT_FILE="/var/run/eqosplus_native.nft"

check_firewall_hook() {
    if ! uci show firewall | grep -q "path='/usr/bin/eqosplus'"; then
        uci add firewall include >/dev/null
        uci set firewall.@include[-1].type='script'
        uci set firewall.@include[-1].path='/usr/bin/eqosplus'
        uci set firewall.@include[-1].fw4_compatible='1'
        uci commit firewall
    fi
}

start() {
    check_firewall_hook
    config_load eqosplus

    echo "table inet fw4 {" > $NFT_FILE
    echo "    chain custom_qos_enforce {" >> $NFT_FILE
    echo "        type filter hook forward priority filter - 5; policy accept;" >> $NFT_FILE
    echo "    }" >> $NFT_FILE
    echo "}" >> $NFT_FILE
    
    echo "flush chain inet fw4 custom_qos_enforce" >> $NFT_FILE
    
    echo "table inet fw4 {" >> $NFT_FILE
    echo "    chain custom_qos_enforce {" >> $NFT_FILE

    # --- THE MAGIC BYPASS RULE ---
    # If LAN talks to LAN, accept it immediately and skip the limits below
    echo "        ip saddr { 192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12 } ip daddr { 192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12 } accept" >> $NFT_FILE
    # -----------------------------

    config_foreach generate_rule device

    echo "    }" >> $NFT_FILE
    echo "}" >> $NFT_FILE

    nft -f $NFT_FILE
}

generate_rule() {
    local cfg="$1"
    local enable ip_target download upload

    config_get_bool enable "$cfg" enable 0
    [ "$enable" -eq 0 ] && return 0

    config_get ip_target "$cfg" mac
    config_get download "$cfg" download
    config_get upload "$cfg" upload

    local dl_kb=$(awk -v dl="$download" 'BEGIN { printf "%.0f", dl * 1000 }')
    local ul_kb=$(awk -v upload="$upload" 'BEGIN { printf "%.0f", upload * 1000 }')

    if [ "$dl_kb" -gt 0 ]; then
        local dl_burst=$((dl_kb * 2))
        echo "        ip daddr $ip_target limit rate over $dl_kb kbytes/second burst $dl_burst kbytes drop" >> $NFT_FILE
    fi

    if [ "$ul_kb" -gt 0 ]; then
        local ul_burst=$((ul_kb * 2))
        echo "        ip saddr $ip_target limit rate over $ul_kb kbytes/second burst $ul_burst kbytes drop" >> $NFT_FILE
    fi
}

stop() {
    nft "delete chain inet fw4 custom_qos_enforce" 2>/dev/null
    rm -f $NFT_FILE
}

case "$1" in
    stop) stop ;;
    *) start ;;
esac
