
DNS_LOG_FILE="${HOME}/wedge-dns.log"

################################################################################
# configure dnsmasq needed to issue IP addresses to wlan clients
# returns: 0
################################################################################
function conf_dnsmasq() {
   dnsmasq_conf="/etc/dnsmasq.conf"

   last_octet=$(echo $AP_ADDR | cut -d'.' -f 4)
   dhcp_start_addr="$(echo $AP_ADDR | cut -d. -f1,2,3).$((last_octet+1))"

   dnsmasq_contents=(
      "interface=${WLAN_IFACE}"
      "listen-address=${AP_ADDR}"
      "dhcp-range=${dhcp_start_addr},${WIFI_NET_HOST_MAX},${WIFI_NET_MASK},24h"
      "bind-dynamic"
      "domain-needed"
      "bogus-priv"
      "log-queries"
      "log-facility=${DNS_LOG_FILE}"
   )

   echo "writing to ${dnsmasq_conf}"
   printf '%s\n' "${dnsmasq_contents[@]}" | sed '/^$/d' > $dnsmasq_conf

}

function cleanup_dnsmasq() {
   rm -f /etc/dnsmasq.conf
}