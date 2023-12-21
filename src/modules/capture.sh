###############################################################################
# -- begin modules/capture.sh
###############################################################################

function hosts_with_leases() {

    leases_file="/var/lib/misc/dnsmasq.leases"
    stations=$(iw dev wlan0 station dump | grep Station | cut -d' ' -f2 | tr '\n' ' ')
    ip_list=()
    for mac in $stations; do
        if grep -q "$mac" "$leases_file"; then
            ip_list+=( $(cat $leases_file | cut -d' ' -f3) )
        fi
    done
    echo "$ip_list"
}

function packet_capture_toggle() {
    capture_dir="$HOME/wedge-captures"
    if pgrep tshark > /dev/null 2>&1; then
        pkill tcpdump 
        return
    fi
    tmp_file=$(mktemp)
    client_ip=$(hosts_with_leases)
    tcpdump -i wlan0 -w $tmp_file host $client_ip 2>/dev/null & 
    if ! pgrep tcpdump; then
        msg_box 8 "tcpdump could not run"
        return
    fi
    msg_box 8 "Capturing traffic for ${client_ip}. Press enter to stop"
    pkill tcpdump 
    if [ ! -d "$capture_dir" ]; then
        mkdir "$capture_dir"
    fi

    new_file="$capture_dir/${client_ip}_$(date +%Y%m%d_%H%M%S).pcap"
    mv $tmp_file $new_file
    msg_box 8 "Capture saved at '$new_file'"

}
