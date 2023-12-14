
function termshark_run() {
    termshark_check_install
    msg_box 8 "termshark will now listen on ${WLAN_IFACE}"
    termshark -i $WLAN_IFACE
}
function termshark_check_install() {
    if ! is_installed "termshark"; then
        if yesno_box 8 "Termshark is not installed. Install now?"; then
            check_if_apt_update
            apt install -y termshark
        fi
    fi
}
