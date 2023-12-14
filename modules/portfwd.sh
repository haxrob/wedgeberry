
function conf_port_fwd() {
   valid_input=1
   desthost=$(input_box "Enter proxy host and port (e.g. 1.2.3.4:8080)" "127.0.0.1:8080" $UPSTREAM_PROXY_HOST)
   if [ $? -ne 0 ]; then
      return 1
   fi
   while [ $valid_input -eq 1 ]; do
      ports=$(input_box "Enter ports to forward (seperated by a ,)" "80,443")
      if [ $? -ne 0 ]; then
         return 1
      fi
      for port in ${ports//,/ }; do
         if ! [[ $port =~ ^[0-9]+$ ]]; then
            msg_box 8 "Invalid port number: $port"
            valid_input=1
         else
            valid_input=0
         fi
      done
   done
   msg_box 12 "Selected ports will be forwarded to ${desthost}.\nNote in BurpSuite you must select 'Support invisible proxying' under 'Request handling' in the listening proxy settings"

   set_conf_param UPSTREAM_PROXY_HOST "$desthost"
   set_conf_param TUNNEL_TYPE INLINE_PROXY

   disable_egress_services
   iptables -t nat -A POSTROUTING -o $EXT_IFACE -j MASQUERADE
   for port in ${ports//,/ }; do
      iptables -t nat -A PREROUTING -i $WLAN_IFACE -p tcp --dport $port -j DNAT --to-destination $desthost
   done

}