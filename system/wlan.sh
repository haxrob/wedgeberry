

# wifi defaults
DEFAULT_WIFI_CHANNEL=11
DEFAULT_SSID=wedge-ap
DEFAULT_WIFI_PASSWORD="012345678"

################################################################################
# present a list of country codes in a menu
# returns: 0 OK
#          1 Cancel
# stdout:  selected country code 
################################################################################
function wifi_country() {
   value=$(sed '/^#/d' /usr/share/zoneinfo/iso3166.tab | tr '\t\n' '/')
   oIFS="$IFS"
   IFS="/"
   REGDOMAIN=$(whiptail --menu "Select the country in which the Pi is to be used" 20 60 10 ${value} 3>&1 1>&2 2>&3)
   ret=$?
   IFS="$oIFS"
   echo "$REGDOMAIN"
   return $ret
}

################################################################################
# create hostap configuration file
# if country code is not prior set (via raspi-config), present oppertunity to
# choose here as this value must be defined in the hostap configuraiton.
# returns: 1 on any cancel
# sets: conf AP_SSID
#       hostap_contents
# TODO: support more then WPA2
# TODO: fix no password / public
################################################################################
function setup_hostap() {
   regdomain="$(iw reg get | sed -n "0,/country/s/^country \(.\+\):.*$/\1/p")"
   if [ -z $regdomain ] || [ $regdomain = "00" ]; then
      regdomain=$(wifi_country)
      if [ $? -ne 0 ]; then
        msg_box "Country must be chosen. You can also set this in rasp-config. Aborting"
        return 1
      fi
      raspi-config nonint do_wifi_country "$regdomain"
   fi
   hostap_conf="/etc/hostapd/hostapd.conf"

   if [[ ! $USE_DEFAULTS ]]; then

      # access point name
      while [[ -z "$AP_SSID" ]]; do
         AP_SSID=$(input_box "SSID" $DEFAULT_SSID)
         if [ $? -ne 0 ]; then
            return 1
         fi
         if [ -z $AP_SSID ]; then
            msg_box "Enter valid SSID"
         fi
      done
      set_conf_param AP_SSID $AP_SSID
      
      # radio channel
      AP_CHANNEL=$(input_box "channel" $DEFAULT_WIFI_CHANNEL)
      if [ $? -ne 0 ]; then
         return 1
      fi

      if [[ -z $AP_CHANNEL ]]; then
         AP_CHANNEL=$DEFAULT_WIFI_CHANNEL
      fi

      # access point password
      AP_PASSWORD=$(input_box "Wifi password. Leave empty for no password (public wifi)")
      if [ $? -ne -0 ]; then
         return 1
      fi
      
      # allow 0 or 8 or more characters. 0 means public wifi
      len=${#AP_PASSWORD}
      while [[ $len -ne 0 ]] && [[ $len -le 7 ]]; do
         msg_box "Password must be longer or equal to 8 characters"
         AP_PASSWORD=$(input_box "Wifi password. Empty if none")
         if [ $? -ne 0 ]; then
            return 1
         fi
         len=${#AP_PASSWORD}
      done
   else
      AP_SSID=$DEFAULT_SSID
      set_conf_param AP_SSID $AP_SSID
      AP_CHANNEL=$DEFAULT_WIFI_CHANNEL
      AP_PASSWORD=$DEFAULT_WIFI_PASSWORD
   fi

   hostap_contents=(
      "interface=${WLAN_IFACE}"
      "driver=nl80211"
      "ssid=${AP_SSID}"
      "country_code=${regdomain}"
      "hw_mode=g"
      "channel=${AP_CHANNEL}"
      "macaddr_acl=0"
      "auth_algs=1"
      "wmm_enabled=0"
   )

   # TODO: fix public wifi
   if [[ -n $AP_PASSWORD ]]; then
      hostap_contents+=(
         "wpa=2"
         "wpa_passphrase=${AP_PASSWORD}"
         "wpa_key_mgmt=WPA-PSK"
         "wpa_pairwise=TKIP"
         "rsn_pairwise=CCMP"
      )
   fi
}

################################################################################
# configure wifi parameters
# sets:    conf WLAN_IFACE
# returns: 0 on success
#          1 if cancel selected
################################################################################
function set_wifi_network() {

   WLAN_IFACE=$(select_wlan_interfaces "Select Wifi access point interface")
   if [ $? -ne 0 ]; then
      return 1
   fi
   set_conf_param WLAN_IFACE $WLAN_IFACE
   if [ $USE_DEFAULTS ]; then
      AP_ADDR="10.10.0.1"
      set_conf_param AP_ADDR $AP_ADDR
      WIFI_NET="10.10.0.0/24"
      WIFI_NET_HOST_MAX="10.10.0.254"
      WIFI_NET_MASK="255.255.255.0"
      WLAN_STATIC_ADDR="10.10.0.1/24"
      return 0
   fi

   while is_invalid_net $WIFI_NET ; do
      WIFI_NET=$(input_box "Wifi network" "10.10.0.0/24")
      if is_invalid_net "$WIFI_NET"; then
         msg_box 8 "Enter valid network"
      fi
   done
   ipcalc=$(ipcalc -n -b $WIFI_NET)
   AP_ADDR=$(echo "$ipcalc" | grep HostMin | awk '{print $2}')
   set_conf_param AP_ADDR $AP_ADDR
   WIFI_NET_HOST_MAX=$(echo "$ipcalc" | grep HostMax | awk '{print $2}')
   WIFI_NET_MASK=$(echo "$ipcalc" | grep Netmask | awk '{print $2}')
   subnet_bits=$(echo $WIFI_NET | cut -d'/' -f2)
   WLAN_STATIC_ADDR="${AP_ADDR}/${subnet_bits}"
}
################################################################################
# write hostap_contents to the hostapd configuration file(s)
# returns: 0
################################################################################
function write_hostap_conf() {
   printf '%s\n' "${hostap_contents[@]}" | sed '/^$/d' > $hostap_conf

   # delete (prevent duplicate lines)
   sed -i '/^DAEMON_CONF/d' /etc/default/hostapd
   echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' >> /etc/default/hostapd
}

################################################################################
# confirm wifi ap settings
# returns: 0 Ok
#        : 1 Cancel
################################################################################
function confirm_settings {
   ap_password_text="$AP_PASSWORD"
   if [[ -z $AP_PASSWORD ]]; then
      ap_password_text="none (public)"
   fi

   local text=(
                "=========================================="
                "Wifi access point interface: ${WLAN_IFACE}"
                "Outbound traffic interface : ${EXT_IFACE}"
                "Wifi internal network      : ${WIFI_NET}"
                "Access point name          : ${AP_SSID}"
                "Access point password      : ${ap_password_text}"
                "Access point channel       : ${AP_CHANNEL}"
                "Country                    : ${regdomain}"
                "=========================================="
               )
   local text2=$(printf '%s\n' "${text[@]}")
   if yesno_box 20 "The following will be configured:\n\n${text2}\n\nContinue?"; then
      return 0
   else
      return 1
   fi
}

################################################################################
# get number of connected wlan clients
# returns: 0
# stdout:  integer of number of connections
################################################################################
function connected_stations() {
   count=$(iw dev $WLAN_IFACE station dump | grep connected | wc -l)
   echo "$count"
}

################################################################################
# display connected wifi client details
# these are wlan stations that have an IP address allocated
# returns: 0
################################################################################
function display_clients() {
   leases_file="/var/lib/misc/dnsmasq.leases"
   declare -A clients
   oIFS="$IFS"
   IFS=$'\n'
   for station in $(iw dev wlan0 station dump | egrep "Station|connected" | paste -sd ' \n' | tr -d '\t'); do
      mac=$(echo $station | cut -d' ' -f2)
      time=$(echo $station | cut -d' ' -f5-)
      clients["$mac"]="$time"
   done
   if [ ${#clients[@]} -eq 0 ]; then
      msg_box 8 "No wifi stations connected"
      return
   fi
   IFS="$oIFS"
   lines=""
   
   # TODO: what is difference between mac1 and mac2?
   while read -r ts mac1 ip name mac2; do
      if [[ ${clients["$mac1"]} ]]; then
         t=${clients["$mac1"]}
         clients["$mac1"]="$ip $t [$name]"
      fi
   done < $leases_file
   for a in "${!clients[@]}"; do
     lines+="${a} ${clients[$a]}\n"
   done
   msg_box_scroll "Connected Wifi clients with leased IP:\n\n$lines"
}

function cleanup_hostapd() {
   rm -f /etc/default/hostapd
   rm -f /etc/hostapd/hostapd.conf
}