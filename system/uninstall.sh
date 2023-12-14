
function uninstall() {
   if ! yesno_box 8 "Remove all configuration files?"; then
      return
   fi

   rm "$CONF_FILE"
   reload_conf

   cleanup_iptables
   cleanup_sysctl
   cleanup_dhcpcd
   cleanup_hostapd
   cleanup_dnsmasq
   cleanup_hostapd
   cleanup_wireguard

   stop_services

   if [ -z "$MITM_SERVICE" ] && [ "$MITMWEB_SERVICE" -eq 1 ]; then
      remove_mitmweb_service
   fi

   set_conf_param STATUS_STATE 0
   if ! yesno_box 8 "Remove all installed software packages?"; then
      return
   fi

   for package in "${REQUIRED_PACKAGES[@]}"; do
      apt-get -y remove "$package"
   done

   for package in "${OPTIONAL_PACKAGES[@]}"; do
      apt-get -y remove "$package"
   done

   if yesno_box 8 "Recommended to reboot. Continue?";then
      /usr/sbin/reboot
   fi

}