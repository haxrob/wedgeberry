###############################################################################
# -- begin system/misc.sh
###############################################################################
function _is_invalid_net() {
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

function is_invalid_net() {
   if [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]{2}$ ]]; then
      echo a
      return 1
   fi
   echo b
   return 0
}

#####
# https://stackoverflow.com/questions/15429420/given-the-ip-and-netmask-how-can-i-calculate-the-network-address-using-bash
######


function ip2int() {
    local a b c d
    { IFS=. read a b c d; } <<< $1
    echo $(((((((a << 8) | b) << 8) | c) << 8) | d))
}

function int2ip() {
    local ui32=$1; shift
    local ip n
    for n in 1 2 3 4; do
        ip=$((ui32 & 0xff))${ip:+.}$ip
        ui32=$((ui32 >> 8))
    done
    echo $ip
}

function netmask() # Example: netmask 24 => 255.255.255.0
{
    local mask=$((0xffffffff << (32 - $1))); shift
    int2ip $mask
}


function broadcast() # Example: broadcast 192.0.2.0 24 => 192.0.2.255
{
    local addr=$(ip2int $1); shift
    local mask=$((0xffffffff << (32 -$1))); shift
    int2ip $((addr | ~mask))
}

function network() # Example: network 192.0.2.0 24 => 192.0.2.0
{
    local addr=$(ip2int $1); shift
    local mask=$((0xffffffff << (32 -$1))); shift
    int2ip $((addr & mask))
}

function hostmin() {
   i=$(ip2int $(network $1 $2))
   int2ip $((i+1))
}

function hostmax() {
   i=$(ip2int $(broadcast $1 $2))
   int2ip $((i-1))
}
