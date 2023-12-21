###############################################################################
# -- begin modules/dhcpcd.sh
###############################################################################

################################################################################
# writes dhcpcd configuration
# returns: 0
################################################################################
function set_dhcpcd() {

   wlan_contents=(
      "interface ${WLAN_IFACE}"
      "static ip_address=${WLAN_STATIC_ADDR}"
      "nohook wpa_supplicant"
   )
   lines=$(printf '%s\n' "${wlan_contents[@]}" | sed '/^$/d')

   # replace everything under "interface <wlan interface>" until blank line
   # TODO: I don't think this is the best approach, but we don't want to 
   # blast away any existing config. need to evaluate this furter.
   
   sed -i "/interface ${WLAN_IFACE}/,/^$/d" /etc/dhcpcd.conf
   echo "$lines" >> /etc/dhcpcd.conf

   # different approach (not used), find line number if existing config and then delete
   # from there

   #lineno=$(grep -n "interface wlan0" /etc/dhcpcd.conf | cut -d: -f1)
   #if [ $? -ne 0 ]; then
   #   echo "$lines" >> /etc/dhcpcd.conf
   #   return
   #fi

   #edit from line number
   #sed "$lineno,$((lineno+2))s/static ip_address=.*/static ip_address=$host_min/g" /etc/dhcpcd.conf
}

function cleanup_dhcpcd() {
   rm -f /etc/dhcpcd.conf
   
   # note service will be stopped from stop_services later
}
