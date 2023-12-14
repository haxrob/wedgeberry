
###############################################################################
# checks that two network interfaces exist by enumerating /sys/class/net
# RETURNS 1 on failure
################################################################################
function check_interface_count {
   
   # ignore loopback
   # TODO: ignore tunnel interfaces
   local count=$(ls /sys/class/net/ | grep -v lo | wc -l)
   if [ $count -lt 2 ]; then
      msg_box 8 "Two network interfaces are required. Only ${count} was detected.\n\
Please add an additional ethernet or wifi USB interface to the Pi"
      return 1
   fi
}
################################################################################
# obtains interface with default route for use in interfaces_list_menu to 
# display all interfaces with the default as the pre-selected
# sets EXT_IFACE
# returns 1 on failure
################################################################################
function set_outbound_interface() {
   default_iface=$(ip r | awk  '/default/ { print $5 }')
   EXT_IFACE=$(interfaces_list_menu "Select outbound interface for outbound network access" $default_iface)
   if [ $? -ne 0 ]; then
      return 1
   fi
   set_conf_param EXT_IFACE $EXT_IFACE
   return 0
}

################################################################################
# displays menu with network interfaces for selection that are wired
# ommits wlan, lo and wireguard interfaces
# returns: 0 on OK
#          1 on Cancel
# stdout:  selected interface name
################################################################################
function interfaces_list_menu() {
   local iface
   local ifaces=()

   # don't show loopback, wlan or vpn interfaces
   declare -A filter
   iface_filter=("lo" "${WLAN_IFACE}" "${WG_IFACE}")
   for i in "${iface_filter[@]}"; do
      filter[$i]=1
   done

   for dir in /sys/class/net/*; do
      if [ -d "$dir" ]; then
         iface=$(basename "$dir")

         # current interface is not in filter list
         if [[ ! ${filter[$iface]} ]]; then 
            ifaces+=($iface " " )
         fi
      fi
   done

   whiptail --title "$WHIP_TITLE" --menu "$1" 10 80 "${#ifaces[@]}" "${ifaces[@]}" 3>&1 1>&2 2>&3
   return $?
}

################################################################################
# lists wireless lan interfaces menu by enumerating /sys/class/net/*/wireless
# returns: 0 OK
#          1 Cancel
# stdout:  selected interface name
################################################################################
function select_wlan_interfaces() {
   local iface
   whip_args=()
   for dir in /sys/class/net/*/wireless; do
      if [ -d "$dir" ]; then
         iface="$(basename "$(dirname "$dir")")"
         whip_args+=( $iface " ")
      fi
  done
  whiptail --title "$WHIP_TITLE" --menu "$1" 10 80 "${#whip_args[@]}" "${whip_args[@]}" 3>&1 1>&2 2>&3
  return $?
}

################################################################################
# check_internet_connectivity
################################################################################
function check_internet_connectivity() {
   echo "checking connection"
   ping -q -c1 debian.org &>/dev/null
   if [ $? -ne 0 ]; then
      msg_box 8 "Unable to reach the Internet. Internet connectivity is required to install required packages"
      return 1
   fi
   return 0
}

function get_public_ip() {
   ipinfo=$(curl --silent https://ipinfo.io)
   formatted=$(echo "$ipinfo" | sed 's/, /\n/g' | tr -d '"{' | sed 's/:/: /g' | sed 's/^ //' | grep -v readme)
   msg_box 15 "$formatted"
}

################################################################################
# direct_no_tunnel
################################################################################
function direct_no_tunnel() {
   disable_egress_services 
   set_conf_param TUNNEL_TYPE DIRECT
   set_direct_iptables
   msg_box 8 "Direct connection (no tunnel) configured."
}