###############################################################################
# -- begin system/setup.sh
###############################################################################
function run_setup() {
   if [ $STATUS_STATE -eq 1 ]; then
      yesno_box 8 "AP mode is already setup. Continuing will override existing configuration. Continue?"
      if [ $? -eq 1 ]; then
         return 1
      fi
   fi
   setup_items
   case $? in
      1) msg_box 8 "Setup cancelled, please re-run setup or run health check";;
      2) msg_box 8 "Setup failed, please resolve issues or run health check";;
   esac
}

function setup_items() {
   if ! check_interface_count; then
      return 2
   fi
   set_conf_param STATUS_STATE 0
   set_conf_param MITMPROXY_ENABLED 0
   set_conf_param TUNNEL_TYPE DIRECT
   disable_egress_services
   if ! set_wifi_network; then
      return 1
   fi
   if ! set_outbound_interface; then
      return 1
   fi
   if ! setup_hostap; then
      return 1
   fi
   if ! confirm_settings; then
      return
   fi
   deps_install
   write_hostap_conf
   set_dhcpcd
   conf_dnsmasq
   set_ipfwd

   # isues if wg is down

   set_conf_param TUNNEL_TYPE DIRECT
   set_direct_iptables
   start_services

   healthcheck "Setup not complete, issues were found" "Setup complete!"
   if [ $? -ne 0 ]; then
      set_conf_param STATUS_STATE 2
      return
   fi
   set_conf_param STATUS_STATE 1
}
