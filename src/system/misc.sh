###############################################################################
# -- begin system/misc.sh
###############################################################################
function is_invalid_net() {
   if [[ -z $1 ]]; then
      return 0
   fi
   if [ "$(ipcalc -n -b $1 | cut -d' ' -f1 | head -1)" != "INVALID" ]; then
      return 1
   fi
   return 0
}

function check_root() {
   if [ "$EUID" -ne 0 ]; then
      echo "Script must be run as root. Try sudo ${BASH_SOURCE}"
      exit
   fi
}

function get_arch() {
   arch=$(dpkg --print-architecture)
   echo "$arch"
}

function whoami() {
   who am i | awk '{print $1}'
}

