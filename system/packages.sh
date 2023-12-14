
REQUIRED_PACKAGES=(iptables ipcalc dnsmasq hostapd dhcpcd resolvconf)
OPTIONAL_PACKAGES=(tor wireguard termshark)

################################################################################
# check if package is installed on system. (lifted from raspi-conf)
# returns: 0 if packge is installed
#          1 if package is not installed 
################################################################################
is_installed() {
  if [ "$(dpkg -l "$1" 2> /dev/null | tail -n 1 | cut -d ' ' -f 1)" != "ii" ]; then
    return 1
  else
    return 0
  fi
}

################################################################################
# enumerate mandatory packages and install any that are missing
# returns: 0
################################################################################
function deps_install() {
   missing_packages=()
   apt_list=()
   for package in "${REQUIRED_PACKAGES[@]}"; do
      if ! is_installed $package; then
         missing_packages+=( "\n" "* ${package}" )
         apt_list+=( "${package}" )
      fi
   done
   if [ "${#missing_packages}" -ne 0 ]; then
      check_internet_connectivity
      if [ $? -ne 0 ]; then
         msg_box "No internet connectivity. This is required for package installation"
      fi
      size=$((${#apt_list} + 8))
      msg_box $size "The following packages will be installed:\n${missing_packages[*]}"
      check_if_apt_update
      apt install -y "${apt_list[@]}"
   fi

}

################################################################################
# calculate days between now and the last time 'apt-get' was run
# /var/catch/apt/pkgcache.bin MTIME seems to be a useful filename to check
# returns: 0
################################################################################
function days_apt_last_run() {
   now=$(date +'%s')
   apt_stat=$(stat --format='%Y' /var/cache/apt/pkgcache.bin)
   delta=$(($now-$apt_stat))
   echo $(($delta / 86400))
}


################################################################################
# prompt user if should run apt-get update. running this every time apt-get 
# install is invoked adds significant delay 
# returns: 0
################################################################################
function check_if_apt_update() {
   local update_threshold=10
   if (($(days_apt_last_run) > update_threshold));then
      if yesno_box 8 "'apt-get update' has not been run for ${update_threshold} days. Would you like to update?"; then
         apt-get update
      fi
   fi
}

