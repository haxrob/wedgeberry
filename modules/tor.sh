
################################################################################
# redirect dns and tcp flows to tor services
# returns 0
################################################################################
function set_tor_iptables() {

   # TODO: why flush?
   iptables -F

   # remove prior tunnel related iptables rules
   iptables-save | grep -v WEDGE_TUNNEL | iptables-restore

   # redirect DNS
   iptables -t nat -A PREROUTING -i $WLAN_IFACE -p udp --dport 53 -j REDIRECT --to-ports 53 -m comment --comment WEDGE_TUNNEL_TOR

   # redirect all TCP
   iptables -t nat -A PREROUTING -i $WLAN_IFACE -p tcp --syn -j REDIRECT --to-ports 9040 -m comment --comment WEDGE_TUNNEL_TOR
}

################################################################################
# write torrc file
# returns: 0
################################################################################
function conf_torrc() {
   torrc_contents=(
      "Log notice file /var/log/tor/notices.log"
      "VirtualAddrNetwork 10.192.0.0/10"
      "AutomapHostsOnResolve 1"
      "TransPort ${AP_ADDR}:9040"
      "DNSPort ${AP_ADDR}:53"
   )
   printf '%s\n' "${torrc_contents[@]}" | sed '/^$/d' > /etc/tor/torrc
   systemctl restart tor
}

################################################################################
# conf_tor
################################################################################
function conf_tor() {
   is_not_setup
   if [ $? -ne 0 ]; then
      return
   fi
   disable_egress_services
   if ! is_installed tor; then
      check_internet_connectivity
      if [ $? -ne 0 ]; then
         return $?
      fi
      if ! is_installed tor; then
         msg_box 8 "tor will now be be installed"
         apt-get install -y tor
      fi
   fi
   systemctl enable --now tor
   set_conf_param STATUS_STATE 0
   conf_torrc
   set_tor_iptables
   set_conf_param TUNNEL_TYPE TOR

   # give some time to bootstrap, say 10 seconds
   loop=0
   {
   while [ $loop -ne 100 ]; do
      loop=$(($loop+20))
      echo $loop
      sleep 2
     done
   } | whiptail --title "$WHIP_TITLE" --gauge "Waiting for tor circuit to establish..." 20 80 0

   check_tor_connectivity
   if [ $? -eq 0 ]; then
      msg_box 8 "TOR configured successfully"
   else
      msg_box 8 "TOR configured but there was an issue connecting to the TOR network"
   fi

   # despite to network conecitivty issues, still set the state as setup
   set_conf_param STATUS_STATE 1
}

################################################################################
# check_tor_connectivity
################################################################################
function check_tor_connectivity() {
   retries=0
   success=0
   while [ $retries -le 4 ] && [ $success -ne 1 ]; do
      check_req=$(curl -q -x socks5h://127.0.0.1:9050  https://check.torproject.org/api/ip)
      echo "$check_req" | grep -q 'IsTor":true'
      if [ $? -ne 0 ] && [ $success -ne 1 ]; then
         retries=$(($retries+1))
      else
         success=1
      fi
   done
   if [ $success -eq 0 ]; then
      return 1
   fi
   return 0
}