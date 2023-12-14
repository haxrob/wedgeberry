
function mitmproxy_setup() {

   options=()
   
   user=$(who am i | awk '{print $1}')
   sudo -u $user pipx list 2>/dev/null | grep -q mitmproxy
   if [ $? -eq 0 ] || [ $MITMWEB_SERVICE -eq 1 ] ; then 
      if [ $(iptables -L -t nat | grep -q MITMPROXY)$? -ne 0 ]; then
         options+=( "1 Enable" "Enable port forwarding to MITMproxy" )
      else
         options+=( "1 Disable" "Disable forwarding to MITMProxy" )
      fi
      options+=( "2 Uninstall" "Remove MITMProxy packages" )
   else
      options+=( "1 Install" "Install MITMProxy" )
   fi

   choice=$(menu "Select options configure" options)
   if [ $? -ne 0 ]; then
      return
   fi
   case $choice in
      1\ Enable) set_mitmproxy_iptables;;
      1\ Disable) unset_mitmproxy_iptables;;
      1\ Install) mitmproxy_install;;
      2\ Uninstall) mitmproxy_uninstall;;
   esac

}

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

function mitmproxy_install() {
   if ! is_installed pipx; then
      msg_box 8 "pipx is required to install mitmproxy - will install"
      sudo apt update
      apt-get -y install pipx
   fi

   if yesno_box 8 "Would you like to install mitmweb as a system service? Selecting yes will install mitmproxy into /opt/mitmproxy"; then
      mitmweb_install_service
      return
   fi
   # as script is being run as sudo, get the user that invoked sudo, otherwise everything
   # will be installed under /root
   user=$(who am i | awk '{print $1}')

   sudo -u $user pipx list | grep -q mitmproxy
   if [ $? -ne 0 ]; then
      msg_box 8 "mitmproxy will be installed user '${user}'"
      sudo -u $user pipx install mitmproxy
      sudo -u $user pipx ensurepath
   fi
}

function mitmproxy_uninstall() {
   user=$(who am i | awk '{print $1}')
   sudo -u $user pipx uninstall mitmproxy
   set_conf_param MITMPROXY_ENABLED 0 
   unset_mitmproxy_iptables
}

function mitmweb_install_service() {
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

function remove_mitmweb_service() {
   systemctl stop mitmweb.service
   rm /etc/systemd/system/mitmproxy.service
   systemctl daemon-reload
   set_conf_param MITMWEB_SERVICE 0
}