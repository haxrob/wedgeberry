
REQUIRED_SERVICES=(dnsmasq hostapd dhcpcd)
# resolvconf required for wireguard
OPTIONAL_SERVICES=(tor resolvconf )

################################################################################
# disable tunnels or other connectivity 
# returns 0
################################################################################
function disable_egress_services() {

   # TODO: do we want to stop the mitmweb service here? Flushing iptables will
   # stop routing selected ports to mitmproxy

   # a hammer
   iptables -F

   iptables-save | grep -v WEDGE_TUNNEL | iptables-restore

   # tor
   if [[ $(systemctl is-active tor) = "active" ]]; then
      msg_box 8 "Disabling previously enabled tor service"
      systemctl disable --now tor 
   fi

   # wireguard
   wgservice="wg-quick@${WG_IFACE}.service"
   if [[ $(systemctl is-active $wgservice) = "active" ]]; then
      msg_box 8 "Disabling previously enabled wireguard interface service"
      systemctl disable --now $wgservice
   fi


}
################################################################################
# start mandatory services
# returns 0 
################################################################################
function start_services {

   # hostapd
   if pgrep hostapd > /dev/null; then
      systemctl restart hostapd
   else
      if [[ $(systemctl is-enabled hostapd.service) != "enabled" ]]; then
         systemctl unmask hostapd.service
         systemctl enable --now hostapd.service
      fi
   fi
   # resolved TODO: (is this only required for wireguard)
   if [[ $(systemctl is-active systemd-resolved) = "active" ]]; then
      echo "stopping systemd-resolved"
      systemctl stop systemd-resolved
      systemctl mask systemd-resolved
   fi 

   # dnsmasq
   systemctl enable --now dnsmasq
   #systemctl restart dnsmasq

   # dhcpcd
   systemctl enable --now dhcpcd
   #systemctl restart dhcpcd
}

################################################################################
# stops both required services and any optional service that is active
# these are defined in the arrays REQUIRED_SERVICES and OPTIONAL_SERVICES at 
# the start of the script
################################################################################
function stop_services() {
   all_services=( "${REQUIRED_SERVICES[@]}" "${OPTIONAL_SERVICES[@]}" )
   for service in "${all_services[@]}"; do
      if [[ $(systemctl is-active "$service") = "active" ]];then 

         # disabling and stopping dhcpcd will kill the current session, so let's not stop this
         if [[ $service != "dhcpcd" ]]; then
            systemctl disable --now $service
         fi
      fi
   done

}
