

# iptables defaults
IPTABLES_PERSIST_FILE="/etc/network/if-pre-up.d/iptables"
IPTABLES_SAVE_FILE="/etc/iptables.up.conf"

################################################################################
# iptables configuration for nat / masq
# returns: 0
################################################################################
function set_direct_iptables() {
   iptables -t nat -F
   iptables -t nat -A POSTROUTING -o $EXT_IFACE -j MASQUERADE -m comment --comment WEDGE_TUNNEL_DIRECT
   save_iptables
}

################################################################################
# save iptables config to survive reboot 
# returns: 0
################################################################################
function save_iptables {
   iptables-save > $IPTABLES_SAVE_FILE
   if [ ! -f $IPTABLES_PERSIST_FILE ]; then
      echo "#!/bin/sh" > $IPTABLES_PERSIST_FILE
      echo "/sbin/iptables-restore < /etc/iptables.up.conf" >> $IPTABLES_PERSIST_FILE
      chmod +x $IPTABLES_PERSIST_FILE
   fi
}

function cleanup_iptables {
   iptables -F
   iptables -F -t nat
   
   rm -f $IPTABLES_PERSIST_FILE
   rm -f $IPTABLES_SAVE_FILE
}
