###############################################################################
# -- begin modules/dnsmasq.sh
###############################################################################

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

   printf '%s\n' "${dnsmasq_contents[@]}" | sed '/^$/d' > $dnsmasq_conf

}

function cleanup_dnsmasq() {
   rm -f /etc/dnsmasq.conf
}


function show_dns_entries() {
   source_ip="$1"
   temp_file=$(mktemp)
   grep -a "from ${source_ip}" $DNS_LOG_FILE | cut -d' ' -f1,2,3,6 > "$temp_file"
   nano "$temp_file"
   unlink "$temp_file"
}

function clear_dns_log() {
   echo > $DNS_LOG_FILE
}
## todo
function show_dns_log() {
   hosts="$(leased_ips)"
   host_items=()
   for host in $hosts; do
      echo "==== $host"
      host_items+=( $host " " )
   done
   if ! choice=$(menu "Select host" host_items ); then
      return
   fi
   show_dns_entries $choice
}
