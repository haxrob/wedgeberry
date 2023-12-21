###############################################################################
# -- begin modules/mitmproxy.sh
###############################################################################

################################################################################
# set ports to redirect to mitmproxy service
# prompts port numbers in comma-seperated format, e.g 80,443
# sets conf MITMPROXY_ENABLED
# returns 0
################################################################################
function set_mitmproxy_iptables() {
   valid_input=1
   
   # validate first
   while [ $valid_input -eq 1 ]; do
      ports=$(input_box "Enter ports to forward (seperated by a ,)" "80,443")
      if [ $? -ne 0 ]; then
         return 1
      fi
      for port in ${ports//,/ }; do
         if ! [[ $port =~ ^[0-9]+$ ]]; then
            msg_box 8 "Invalid port number: $port"
            valid_input=1
         else
            valid_input=0
         fi
      done
   done
   set_conf_param MITMPROXY_ENABLED 1
   
   # remove any prior rules
   iptables-save | grep -v WEDGE_MITMPROXY | iptables-restore

   for port in ${ports//,/ }; do
      iptables -t nat -A PREROUTING -i $WLAN_IFACE -p tcp --dport $port -j  REDIRECT --to-port 8080 -m comment --comment WEDGE_MITMPROXY
      iptables -t nat -A PREROUTING -i $WLAN_IFACE -p tcp --dport $port -j REDIRECT --to-port 8080 -m comment --comment WEDGE_MITMPROXY
   done

   # mitmproxy documentation recommends this
   sysctl -w net.ipv4.conf.all.send_redirects=0
   sysctl -p
}

################################################################################
# remove iptables rules related to mitmproxy
# this is done by grepping out marker comments 
# sets: conf MITMPROXY_ENABLED 
# returns: 0
################################################################################
function unset_mitmproxy_iptables() {
   iptables-save | grep -v MITMPROXY | iptables-restore
   set_conf_param MITMPROXY_ENABLED 0
   return
}

function mitmproxy_uninstall() {
   sudo -u mitmproxy pipx uninstall mitmproxy
   set_conf_param MITMPROXY_ENABLED 0 
   unset_mitmproxy_iptables
}

function mitmweb_install_service() {
   if ! is_installed pipx; then
      msg_box 8 "pipx is required to install mitmproxy. Continue?"
      sudo apt update
      apt-get -y install pipx
   else
      return
   fi

   if ! msg_box 8 "mitmproxy will be installed under /opt/mitmproxy. mitmweb will be run as a systemd service 'mitmweb.service'. Continue?"; then
      return
   fi
   mkdir /opt/mitmproxy
   addgroup --system mitmproxy
   adduser --system --home /opt/mitmproxy --shell /usr/sbin/nologin --no-create-home --gecos 'mitmproxy' --ingroup mitmproxy --disabled-login --disabled-password mitmproxy
   chown -R mitmproxy:mitmproxy /opt/mitmproxy
   PIPX_HOME=/opt/mitmproxy sudo -E pipx install mitmproxy
   
   mitmweb_svc_path="/etc/systemd/system/mitmweb.service"
   mitmweb_listen_addr=$(ip -f inet addr show eth0 | awk '/inet / {print $2}' | cut -d/ -f1)
   # https://gist.github.com/avoidik/84ba17cc47987785cd7e5fe1b1aee603
   if [[ $(systemctl is-active mitmweb.service) = "active" ]]; then
      systemctl stop mitmweb.service
   fi
   mitmweb_svc_contents=(
      "[Unit]"
      "Description=mitmweb service"
      "After=network-online.target"
      "[Service]"
      "Type=simple"
      "User=mitmproxy"
      "Group=mitmproxy"
      "ExecStart=/opt/mitmproxy/venvs/mitmproxy/bin/mitmweb --mode transparent --showhost --no-web-open-browser --web-host ${mitmweb_listen_addr}"
      "Restart=on-failure"
      "RestartSec=10"
      "LimitNOFILE=65535"
      "LimitNPROC=4096"
      "PrivateTmp=true"
      "PrivateDevices=true"
      "ProtectHome=true"
      "ProtectSystem=strict"
      "NoNewPrivileges=true"
      "DevicePolicy=closed"
      "ProtectControlGroups=yes"
      "ProtectKernelModules=yes"
      "ProtectKernelTunables=yes"
      "RestrictNamespaces=yes"
      "RestrictRealtime=yes"
      "RestrictSUIDSGID=yes"
      "LockPersonality=yes"
      "WorkingDirectory=/opt/mitmproxy"
      "ReadOnlyDirectories=/"
      "ReadWriteDirectories=/opt/mitmproxy"
      "[Install]"
      "WantedBy=multi-user.target"
   )

   printf '%s\n' "${mitmweb_svc_contents[@]}" | sed '/^$/d' > $mitmweb_svc_path
   systemctl daemon-reload
   systemctl enable mitmweb.service
   systemctl start mitmweb.service
   if [ $? -ne 0 ]; then
      msg_box 8 "There was an error starting mitmweb systemd service. See journalctl -u mitmweb.service"
      return 1
   fi
   set_conf_param MITMWEB_SERVICE 1 
   msg_box 8 "mitmweb can be accessed on http://${mitmweb_listen_addr}:8081"
}

function mitmproxy_is_redirected() {

   # mitmweb is runnning and redirection rules in nat table configured
   if pgrep mitmweb > /dev/null; then 
      if iptables -L -t nat | grep WEDGE_MITMPROXY > /dev/null 2>&1; then
         i=$(iptables -n -L -t nat | grep WEDGE_MITMPROXY | grep dpt | awk '{ print $7 }' | cut -d':' -f2 | sort -u | tr '\n' ',')
         # remove trailing , character
         echo "${i::-1}"
         return 0
      fi
   fi
   return 1
}
function remove_mitmweb_service() {
   systemctl stop mitmweb.service
   rm /etc/systemd/system/mitmproxy.service
   systemctl daemon-reload
   unset_mitmproxy_iptables
   set_conf_param MITMWEB_SERVICE 0
}
