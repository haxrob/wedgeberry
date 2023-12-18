

# configuration options. When run as sudo this will be in root's home directory
CONF_FILE="${HOME}/.config/wedge.conf"

DEBUG_LOG="./wedge-debug.log"
# -d switch to write to debug log

if [[ $1 = "-d" ]]; then
   exec 5> $DEBUG_LOG 
   BASH_XTRACEFD="5"
   PS4='${LINENO}: '
   set -x
fi


# configuration parameters are reloaded 'from disk' each time a menu page is displayed
function reload_conf() {
   . $CONF_FILE
}

# config file exists, reload 
if [ -e $CONF_FILE ]; then
   reload_conf
fi



function is_not_setup() {
   if [ "$STATUS_STATE" -ne 1 ]; then
      if yesno_box 8 "Initial setup has not been run. Would you like to run it now?"; then
         ap_setup_menu
         return 1
      fi
      msg_box 8 "Initial setup must be run before continuing"
      return 0
   fi
   return 1
}



################################################################################
# conf_file_setup
################################################################################
function conf_file_setup {
   if [ ! -e "${HOME}/.config" ]; then
      mkdir "${HOME}/.config"
   fi
   if [ ! -e "$CONF_FILE" ]; then
      echo "STATUS_STATE=0" > $CONF_FILE
      echo "TUNNEL_TYPE=DIRECT" >> $CONF_FILE
   fi
}

################################################################################
# sets a configuration parameter, specified as an argument and also 'saves'
# it in the persistant configuration file
# returns 0
################################################################################
function set_conf_param() {
   param=$1
   value=$2
   declare "${param}"="${value}"
   sed -i "/${param}=/d" $CONF_FILE
   echo "${param}=${value}" >> $CONF_FILE
}

function main() {
   check_root
   conf_file_setup
   main_menu
}

