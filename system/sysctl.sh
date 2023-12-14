
################################################################################
# set_ipfw
# returns: 0
################################################################################
function set_ipfwd() {
   echo "Setting ipv4.ip_forward"
   sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
   echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
   sysctl -p
}

function cleanup_sysctl() {
   sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
   sysctl -p
}