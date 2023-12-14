
DEBUG_LOG="./wedge-debug.log"

# configuration options. When run as sudo this will be in root's home directory
CONF_FILE="${HOME}/.config/wedge.conf"

# -d switch to write to debug log
if [[ $1 = "-d" ]]; then
   exec 5> $DEBUG_LOG 
   BASH_XTRACEFD="5"
   PS4='${LINENO}: '
   set -x
fi


# configuration parameters are reloaded 'from disk' each time a menu page is displayed
function reload_conf() {
   . $CONF_FILE
}

# config file already written before
if [ -e $CONF_FILE ]; then
   reload_conf
fi

################################################################################
# main_menu
################################################################################
function main_menu {
   while true; do
      reload_conf
      options=(
         "1 Setup" "Initial setup and configuration options"
         "2 Clients" "Display connected client information"
         "3 Connectivity" "Setup optional VPN, proxy or Tor network"
         "4 Tools" "Configure or run inspection tools"
         "5 Health check" "Check status of system components"
         "6 Update" "Update this tool to the latest version"
         "7 Uninstall" "Remove all configurations and software"
      )

      status=$(get_status_text)
      choice=$(menu "${status}" options "Finish")

      if [ $? -ne 0 ]; then
         exit
      fi

      case $choice in
         1\ *) ap_setup_menu;;
         2\ *) display_clients;;
         3\ *) tunnel_config_menu ;;
         4\ *) tools_menu;;
         5\ *) healthcheck ;;
         6\ *) check_updates ;;
         7\ *) uninstall ;;
      esac
   done
}

function is_not_setup() {
   # TODO
   return 0
   if [ $STATUS_STATE -ne 1 ]; then
      if yesno_box 8 "Initial setup has not been run. Would you like to run it now?"; then
         ap_setup_menu
         return 1
      fi
      msg_box 8 "Initial setup must be run before continuing"
      return 0
   fi
   msg_box 8 "returning 1"
   return 1
}

function tunnel_config_menu() {

   options=(
      "1 Direct" "Direct via network interface"
      "2 Wireguard" "Route all traffic via Wireguard VPN"
      "3 TOR" "Route all traffic via the TOR network"
      "4 BurpSuite / external proxy" "Forward specific ports to proxy"
      "5 MITMProxy" "Forward specific ports MITMproxy on Pi"
      "6 Back" "Return to previous menu"
   )

   choice=$(menu "Select tunnel configuration" options)
   if [ $? -ne 0 ]; then
      return
   fi

   case $choice in
      1\ *) direct_no_tunnel;;
      2\ *) conf_wireguard;;
      3\ *) conf_tor;;
      4\ *) conf_port_fwd;;
      5\ *) set_mitmproxy_iptables;;
      6\ *) return;;
   esac
}

function ap_setup_menu() {
   options=(
      "1 Automatic" "Use predefined defaults"
      "2 Custom" "Specify custom parameters"
   )
   choice=$(menu "Select setup type" options)
   if [ $? -ne 0 ]; then
      return
   fi
   case $choice in
      1\ *) USE_DEFAULTS=1; run_setup ;;
      2\ *) unset USE_DEFAULTS; run_setup;;
   esac
}

function tools_menu() {
   options=(
     "1 MITMProxy" ""
     "2 Termshark" "(wireshark-like)"
     "3 Back" "Return to previous menu"
   )
   choice=$(menu "Select software to install/configure" options)
   if [ $? -ne 0 ]; then
      return
   fi
   case $choice in
      1\ *) mitmproxy_setup;;
      2\ *) termshark_run;;
      3\ *) return;;
   esac
}



################################################################################
# conf_file_setup
################################################################################
function conf_file_setup {
   if [ ! -e "${HOME}/.config" ]; then
      mkdir "${HOME}/.config"
   fi
   if [ ! -e "$CONF_FILE" ]; then
      echo "STATUS_STATE=0" > $CONF_FILE
      echo "TUNNEL_TYPE=DIRECT" >> $CONF_FILE
   fi
}

################################################################################
# sets a configuration parameter, specified as an argument and also 'saves'
# it in the persistant configuration file
# returns 0
################################################################################
function set_conf_param() {
   param=$1
   value=$2
   declare "${param}"="${value}"
   sed -i "/${param}=/d" $CONF_FILE
   echo "${param}=${value}" >> $CONF_FILE
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

   if [ $MITMPROXY_ENABLED -ne 0 ]; then
      mitmproxy_text=" MITMProxy"
   fi

   text="\n       "

   station_count=$(connected_stations)
   if [ $station_count -gt 1 ]; then
      station_text="${station_count} connected clients"
   fi
   if  [ $station_count -eq 0 ]; then
      station_text="no connected clients"
   fi
   if [ $station_count -eq 1 ]; then
      station_text="1 connected client"
   fi

   text+="SSID: ${AP_SSID}, ${station_text}\n"
   text+="       "
   text+="${WLAN_IFACE} -> [pi${mitmproxy_text}] -> ${EXT_IFACE} -> "
   case $TUNNEL_TYPE in
      DIRECT) text+="Internet";;
      WIREGUARD) text+="Wireguard VPN"
      if ! wireguard_is_iface_setup; then
         text+="(DOWN)"
      fi
      ;;
      TOR) text+="TOR";;
      INLINE_PROXY) text+="$UPSTREAM_PROXY_HOST";;
   esac
   echo "$text"
}

function main() {
   check_root
   conf_file_setup
   main_menu
}

