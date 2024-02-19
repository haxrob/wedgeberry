###############################################################################
# -- begin system/sysctl.sh
###############################################################################
function set_ipfwd() {
   sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
   echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
   sysctl -p > /dev/null 2>&1
}

function cleanup_sysctl() {
   sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
   sysctl -p
}
