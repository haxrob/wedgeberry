###############################################################################
# -- begin system/menus.sh
###############################################################################
function main_menu {
   local options
   local choice
   local status

   while true; do
      reload_conf
      options=(
         "1 Wireless LAN" "Initial setup and configuration options"
         "2 Connectivity" "Setup optional VPN, proxy or Tor network"
         "3 Mitmproxy" "Configure mitmproxy web service"
         "4 Logging" "DNS logging, flow logging"
         "5 Health check" "Check status of system components"
         "6 Update" "Update this tool to the latest version"
         "7 Uninstall" "Remove all configurations and software"
      )

      status=$(get_status_text)
      if ! choice=$(menu "${status}" options "Finish"); then
         exit
      fi

      case $choice in
         1\ *) wlan_menu;;
         2\ *) tunnel_config_menu ;;
         3\ *) mitmproxy_main_menu;;
         4\ *) logging_menu;;
         5\ *) healthcheck ;;
         6\ *) check_updates ;;
         7\ *) uninstall ;;
      esac
   done
}

function tunnel_config_menu() {
   local options
   local choice

   options=(
      "1 Direct" "Direct via network interface"
      "2 Wireguard" "Route all traffic via Wireguard VPN"
      "3 TOR" "Route all traffic via the TOR network"
      "4 BurpSuite / proxy" "Forward specific ports to proxy"
      "5 Back" "Return to previous menu"
   )

   if ! choice=$(menu "Select outbound traffic configuration" options); then 
      return
   fi

   case $choice in
      1\ *) direct_no_tunnel;;
      2\ *) conf_wireguard;;
      3\ *) conf_tor;;
      4\ *) conf_port_fwd;;
      5\ *) return;;
   esac
}

function ap_setup_menu() {
   local options
   local choice

   options=(
      "1 Automatic" "Use predefined defaults"
      "2 Custom" "Specify custom parameters"
   )
   if ! choice=$(menu "Select setup type" options); then
      return
   fi
   case $choice in
      1\ *) USE_DEFAULTS=1; run_setup ;;
      2\ *) unset USE_DEFAULTS; run_setup;;
   esac
}

function tools_menu() {
   local options
   local choice

   options=(
     "1 MITMProxy" "Transparent proxy traffic inspection"
     "2 Termshark" "(wireshark-like)"
     "3 Back" "Return to previous menu"
   )
   if ! choice=$(menu "Select software to install/configure" options); then
      return
   fi
   case $choice in
      1\ *) mitmproxy_main_menu;;
      2\ *) termshark_run;;
      3\ *) return;;
   esac
   tools_menu
}

function wlan_menu() {
   local ap_text
   local ap_text_2
   local choice

   if [ "$STATUS_STATE" -eq 0 ]; then
      ap_setup_menu
   fi
   if systemctl status hostapd > /dev/null; then
      ap_text="Stop"
      ap_text_2="Stop Wifi AP"
   else
      ap_text="Start"
      ap_text_2="Start Wifi AP"
   fi

   options=(
      "1 ${ap_text} " "${ap_text_2} wifi access point"
      "2 Connected clients" "List connected wifi clients with DHCP lease"
      "3 Set SSID" "Set Wifi network name"
      "4 Configure" "Re-run full configuration options"
      "4 Back" "Return to previous menu"
   )
   if ! choice=$(menu "Select option" options); then
      return
   fi
   case $choice in
      1\ *) toggle_hostapd;;
      2\ *) display_clients;;
      3\ *) set_ssid_menu;;
      4\ *) ap_setup_menu;; 
      5\ *) return;; 
   esac
   wlan_menu
}

function backtitle_text() {
   local ssid
   local hostapd_status
   local station_count
   local mitmweb_url
   local mitmweb_svc

   station_count=$(connected_stations)
   if [ "$station_count" -gt 1 ]; then
      station_text="${station_count} clients"
   fi
   if  [ "$station_count" -eq 0 ]; then
      station_text="0 clients"
   fi
   if [ "$station_count" -eq 1 ]; then
      station_text="1 client"
   fi
   if ssid=$(ssid_from_config); then
      ap_info_text="¦ ssid: '${ssid}' → ${station_text}"
   else
      ap_info_text=""
   fi

   hostapd_status="DOWN "
   if pgrep hostapd > /dev/null 2>&1; then
      if ifconfig $WLAN_IFACE | grep -q 'RUNNING'; then
         hostapd_status="UP "
      fi
   fi 

   mitmweb_url="mitmweb: " 
   mitmweb_svc="$(netstat -nltp | grep $(pgrep mitmweb) | grep python | grep -v 8080 | awk '{print $4}')"
   if [[ $mitmweb_svc != "" ]]; then
      mitmweb_url+="http://${mitmweb_svc}"
   else
      mitmweb_url+="not running"
   fi

   echo -e "| WLAN AP: $hostapd_status${ap_info_text} | ${mitmweb_url} |"
}

################################################################################
# Status text shown at top of main menu
# Shows wifi clients connected and traffic forward/routes/tunnels
################################################################################
function get_status_text() {
   local text=""
   if [ $STATUS_STATE -eq 0 ]; then
      text="\nStatus: Initial setup"
      if wireguard_is_iface_setup; then
         text+=" (Note: wireguard tunnel up)"
      fi
      echo "$text"
      return
   fi

   if [ $STATUS_STATE -eq 2 ]; then
      text="Status: Initial setup failed. Resolve issues and re-run setup"
      echo "$text"
      return
   fi

   if redir=$(mitmproxy_is_redirected); then
      mitmproxy_text="[${redir}]¬ mitmproxy -»"
   fi

   #text="\n       "
   text="\n"

   
   if ! ifconfig "$WLAN_IFACE" > /dev/null 2>&1; then
      BACKTITLE+="[DOWN]"
   fi

   text+="${WLAN_IFACE} -» ${mitmproxy_text}${EXT_IFACE} -» "
   case $TUNNEL_TYPE in
      DIRECT) text+="Internet";;
      WIREGUARD) text+="Wireguard"
      if ! wireguard_is_iface_setup; then
         text+="(DOWN)"
      fi
      ;;
      TOR) text+="TOR";;
      INLINE_PROXY) text+="$UPSTREAM_PROXY_HOST";;
   esac
   echo "$text"
}

function is_not_setup() {
   if [ "$STATUS_STATE" -ne 1 ]; then
      if yesno_box 8 "Initial setup has not been run. Would you like to run it now?"; then
         ap_setup_menu
         return 1
      fi
      msg_box 8 "Initial setup must be run before continuing"
      return 0
   fi
   return 1
}

function set_ssid_menu() {
    options=(
      "1 Manual" "Enter SSID Wifi network name" 
      "2 Random" "Generate random SSID and BSSID (mac address)" 
      "3 Back" "Return to previous menu"
   )
   if ! choice=$(menu "Select option" options); then
      return
   fi
   case $choice in
      1\ *) set_ssid_text;;
      2\ *) set_random_ssid;;
      3\ *) return;; 
   esac
}

function mitmproxy_main_menu() {
   local options
   local choice 

   if [ ! -e "/opt/mitmproxy/venvs/mitmproxy/bin/mitmproxy" ]; then
      if yesno_box 8 "Mitmproxy is not installed and configured. Install?"; then
         mitmweb_install_service
      fi
   fi

   options=(
      "1 Port forwarding" "Specify ports to forward to mitmproxy" 
      "2 Disable forwarding" "Remove port forwarding to mitmproxy" 
      "3 Uninstall" "Uninstall mitmproxy"
      "4 Back" "Return to previous menu"
   )
   if ! choice=$(menu "Select option" options); then
      return
   fi

   case $choice in
      1\ *) set_mitmproxy_iptables;;
      2\ *) unset_mitmproxy_iptables;;
      3\ *) mitmweb_uninstall;; 
      4\ *) return;; 
   esac
}

function logging_menu() {
   local options
   local choice
   local start_stop

   if pgrep tshark; then
      start_stop="Stop"
   else
      start_stop="Start"
   fi

   options=(
     "1 ${start_stop} capture" "${start_stop} packet capture of connected station"
     "2 Filter conversations" "Generate conversation file based on capture"
     "3 Show DNS log" "Display records in DNS log"
     "4 Clear DNS log" "Clear all records from DNS log"
     "5 Back" "Return to previous menu"
   )
   if ! choice=$(menu "Select an option" options); then
      return
   fi
   case $choice in
      1\ *) packet_capture_toggle;;
      2\ *) packet_capture_conversations;;
      3\ *) show_dns_log;;
      4\ *) clear_dns_log;;
      5\ *) return;;
   esac
   logging_menu
}
