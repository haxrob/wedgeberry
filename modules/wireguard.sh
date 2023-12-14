
# wireguard defaults
WG_IFACE="wg-wedge"
WG_CONF_PATH="/etc/wireguard/${WG_IFACE}.conf"
WG_ROUTE_TABLE=1000

################################################################################
# set a default route for traffic to be sent to the wireguard next hop
# here this is appended to the PostUp directive in the wireguard configuration
# to survive reboot
# TODO: consider if these routes should be placed somewhere else
# returns: 0
################################################################################
function set_wireguard_route() {
   wg_conf="/etc/wireguard/${WG_IFACE}.conf"
   next_hop=$(grep Address /etc/wireguard/${WG_IFACE}.conf | cut -d' ' -f3 | cut -d'/' -f1)
   L1="ip r add default via $next_hop dev $WG_IFACE table $WG_ROUTE_TABLE"
   L2="ip rule add iif $WLAN_IFACE lookup $WG_ROUTE_TABLE"

   $L1
   $L2

   sed -i '/PostUp/d' $wg_conf
   sed -i "/Interface/a PostUp=${L2}" $wg_conf
   sed -i "/Interface/a PostUp=${L1}" $wg_conf

}

################################################################################
# iptables configuration for wireguard
# all traffic originating from WLAN inteface forwarded into the wireguard 
# interface
################################################################################
function set_wireguard_iptables() {
   iptables -F
   iptables -t nat -A POSTROUTING -o $WG_IFACE -j MASQUERADE -m comment --comment WEDGE_TUNNEL_WIREGUARD
   iptables -A FORWARD -i $WLAN_IFACE -o $WG_IFACE -j ACCEPT -m comment --comment WEDGE_TUNNEL_WIREGUARD
   iptables -A FORWARD -i $WG_IFACE -o $WLAN_IFACE -m state --state RELATED,ESTABLISHED -j ACCEPT -m comment --comment WEDGE_TUNNEL_WIREGUARD
   save_iptables
}

################################################################################
# conf_wireguard
################################################################################
function conf_wireguard() {
   if ! is_not_setup; then
      return
   fi
   if [ $? -ne 0 ]; then
      return
   fi
   
   disable_egress_services
   if ! is_installed wireguard; then
      check_internet_connectivity
      if [ $? -ne 0 ]; then
         return $?
      fi

      # will install wireguard-tools as part of wireguard package
      if ! is_installed wireguard; then
         if yesno_box 8 "Wireguard software is not installed. Install?"; then
            apt-get install -y wireguard resolvconf
         else
            msg_box 8 "Wireguard must be installed before continuing"
            return 1
         fi
      fi
   fi

   if [ $STATUS_STATE -ne 1 ]; then
      msg_box 8 "Initial setup not complete, refusing to setup wireguard tunnel"
      return 1
   fi

   options=(
      "1" "Use existing wireguard configuration file"
      "2" "Generate client wireguard configuration"
      "3" "Go back"
   )

   choice=$(menu "Select an option" options)
   if [ $? -ne 0 ]; then
      return 1
   fi

   case $choice in
         1) add_wireguard_conf;;
         2) interactive_wireguard_conf;;
         3) return;;
   esac
   if [ -f "$WG_CONF_PATH" ]; then
      healthcheck silent
      if [ $? -eq 1 ]; then
         msg_box 8 "Note: Health check failed."
      fi

      wireguard_up
      set_wireguard_iptables
      set_wireguard_route
      systemctl enable wg-quick@$WG_IFACE.service
   else
      msg_box 8  "You must add the wireguard configuration to the file ${WG_CONF_PATH} after setup"
   fi

}

################################################################################
# add_wireguard_conf
################################################################################
function add_wireguard_conf() {
   if yesno_box 8 "A text editor will be opened to add the wireguard configuration. Continue?"; then
      if [ ! -f $WG_CONF_PATH ]; then
         echo "# wg-configuration here\n" > $WG_CONF_PATH
      fi
      nano $WG_CONF_PATH
   fi
}

################################################################################
# interactive_wireguard_conf
################################################################################
function  interactive_wireguard_conf() {

   info_msg="\
   You will need the following details before continuing:

     * Local wireguard interface address
     * DNS server
     * Remote wireguard IP address
     * Remote wireguard public key

     Continue?"

   if ! yesno_box 14 "$info_msg"; then
      return
   fi

   private_key=$(wg genkey)
   public_key=$(echo $private_key | wg pubkey)

   address=$(input_box "Local tunnel address" "192.168.0.1")
   dns=$(input_box "dns server" "1.1.1.1")
   endpoint=$(input_box "Remote server address" "")
   svr_public_key=$(input_box "Remote server public key" "")

   wg_conf_contents=(
      "[Interface]"
      "PrivateKey = ${private_key}"
      "Address = ${address}/32"
      "DNS = ${dns}"
      ""
      "[Peer]"
      "PublicKey = ${svr_public_key}"
      "AllowedIPs = 0.0.0.0/0"
      "Endpoint = ${endpoint}"
   )
   printf '%s\n' "${wg_conf_contents[@]}" | sed '/^$/d' > $WG_CONF_PATH

   echo "$public_key" > "${HOME}/wg-pubkey.txt"
   info_msg="The public key of this wireguard endpoint is:\n${public_key}\n
   This key is required to be configured in the remote wireguard endpoint.

   A copy has been saved to '${HOME}/wg-pubkey.txt'"
   msg_box 20 "$info_msg"

}

################################################################################
# wireguard_up
################################################################################
function wireguard_up {
   set_conf_param TUNNEL_TYPE WIREGUARD
   if wireguard_is_iface_setup; then
      wg-quick down $WG_IFACE
   fi
   output=$(wg-quick up $WG_IFACE 2>&1)
   if [[ $output =~ .*error.* ]]; then
      msg_box_scroll "error:\n${output}"
      if yesno_box 8 "Configure again?"; then
         conf_wireguard
      fi
   fi
}

function wireguard_is_iface_setup() {
   # if interface is not configured, non zero return code
   wg show $WG_IFACE > /dev/null 2>&1
   return $?
}

function cleanup_wireguard() {
   wg-quick down $WG_IFACE
   ip route flush table $WG_ROUTE_TABLE 
   systemctl disable wg-quick@$WG_IFACE.service
}