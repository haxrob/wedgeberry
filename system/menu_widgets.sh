
WHIP_TITLE="Wedgeberry Pi Configuration Tool (wedge-config)"

################################################################################
########## // whiptail widgets #################################################
################################################################################
function input_box() {
   local text="$1"
   local default_value="$2"
   local custom_value="$3"
   if [ -n "$custom_value" ]; then
      default_value="$custom_value"
   fi
   whiptail --title "$WHIP_TITLE" --inputbox "$text" 10 80 "$default_value" 3>&1 1>&2 2>&3
}

function msg_box() {
   local height="$1"
   local text="$2"
   whiptail --title "$WHIP_TITLE" --msgbox "$text" $height 80
}

function yesno_box() {
   local lines="$1"
   local text="$2"
   #local lines=$(printf "%s" "$text" | wc -l)
   #lines=$(($lines+11))
   whiptail --title "${WHIP_TITLE}" --yesno "$text" $lines 80 3>&1 1>&2 2>&3
   return $?
}

function msg_box_scroll() {
   local tmp=$(mktemp)
   echo "$1" > $tmp
   whiptail --scrolltext --title "${WHIP_TITLE}" --textbox $tmp 20 80
   rm $tmp
}

function menu() {
   local -n opts="$2"
   local l="${#opts[@]}"
   local len=$(($l / 2))
   local cancel_text="$3"
   
   if [ -z "$cancel_text" ]; then
      cancel_text="Back"
   fi
   whiptail --backtitle "$(backtitle_text)" --fb --title "${WHIP_TITLE}" --menu --cancel-button "$cancel_text" --ok-button Select "$1" 20 80 $len "${opts[@]}" 3>&1 1>&2 2>&3
   ret=$?
   return $ret
}