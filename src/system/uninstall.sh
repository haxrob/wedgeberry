###############################################################################
# -- begin system/uninstall.sh
###############################################################################
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

   remove_mitmweb_service

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

   apt -f autoremove

   if yesno_box 8 "Recommended to reboot. Continue?";then
      /usr/sbin/reboot
   fi

}
