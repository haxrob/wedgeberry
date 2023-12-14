

# TODO: Seperate functionality into each "module" file
function healthcheck() {
   fail_text="$1"
   pass_text="$2"

   issues=()
   if [ ! -f $IPTABLES_PERSIST_FILE ]; then
      issues+=( "iptables rules will not persist on reboot" )
   fi
   grep -q "net.ipv4.ip_forward*=*1" /etc/sysctl.conf
   if [ $? -ne 0 ]; then
      issues+=( "ip forwarding not enabled" )
   fi
   if [ ! -f "/etc/dhcpcd.conf" ]; then
      issues+=( "no dhcpcd configuration found" )
   fi

   if [ ! -f "/etc/dnsmasq.conf" ]; then
      issues+=( "no dnsmasq conf" )
   fi

   if [ ! -f "/etc/hostapd/hostapd.conf" ]; then
      issues+=( "no hostapd.conf" )
   fi

   if [ ! -f "/etc/default/hostapd" ]; then
      issues+=( "no /etc/default/hostapd" )
   fi

   missing_required_packages=()
   for package in "${REQUIRED_PACKAGES[@]}"; do
      if ! is_installed "$package"; then
         issues+=( "package '${package}' is not installed" )
         missing_required_packages+=( "$package" )
      fi
   done

   for service in "${REQUIRED_SERVICES[@]}"; do
      systemctl is-active --quiet "$service"
      if [ $? -ne 0 ]; then
         issues+=( "service '${service}' is not running" )
      fi
   done

   if [[ -z $TUNNEL_TYPE ]] && [[ $TUNNEL_TYPE = "WIREGUARD" ]]; then
      wg show | grep -q peer
      if [ $? -ne 0 ]; then
         issues+=( "Wireguard is configured to be used, but there is no peer up" )
      fi
      ip route show table 1000 | grep -q $WG_IFACE
      if [ $? -ne 0 ]; then
         issues+=( "Missing wireguard routing table" )
      fi
   fi

   if [[ -z $TUNNEL_TYPE ]] && [[ $TUNNEL_TYPE = "TOR" ]]; then
      systemctl is-active --quiet tor
      if [ $? -ne 0 ]; then
         issues+=( "TOR is configured to be used, but the service is not running" )
      fi
   fi

   if [[ -z $MITMWEB_SERVICE ]] && [[ $MITMWEB_SERVICE -eq 1 ]]; then
      if [[ $(systemctl is-active mitmweb.service) != "active" ]]; then
         issues+=( "mitmweb is configured as a service, but the service is not running" )
      fi
   fi

   if [ "${#issues}" -ne 0 ]; then
      if [ -z "$fail_text" ]; then
         text="The following problems were found:\n\n"
      else
         text="${fail_text}:\n\n"
      fi

      for issue in "${issues[@]}"; do
         text="${text}\n* ${issue}"
      done
      msg_box_scroll "$text"

      if [ "${#missing_required_packages}" -gt 0 ]; then
         msg_box 8 "Please (re)run setup to install missing (required) packages"
      fi
      return 1
   else
      if [ -z "$pass_text" ]; then
         msg_box 8 "Healthcheck passed all checks"
      else
         msg_box 8 "$pass_text"
      fi
   fi
   set_conf_param STATUS_STATE 1
   return 0
}
