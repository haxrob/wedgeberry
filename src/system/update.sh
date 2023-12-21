###############################################################################
# -- begin system/update.sh
###############################################################################
SCRIPT_GITHUB_URL="https://raw.githubusercontent.com/haxrob/wedgeberry/main/build/wedge-conf.sh"
function check_updates() {
    current_script="${BASH_SOURCE[0]}"
    temp_file=$(mktemp)
    if ! curl --silent "$SCRIPT_GITHUB_URL" -o "$temp_file"; then
        msg_box 8 "Unable to fetch update"
        return
    fi
    remote_hash=$(md5sum "$temp_file" | cut -d' ' -f1)
    my_hash=$(md5sum "$current_script" | cut -d' ' -f1)
    if [[ $remote_hash != $my_hash ]]; then
        if yesno_box 8 "A newer version was found. Update?"; then
            mv $temp_file $current_script
            chmod a+rwx $current_script
            exec $current_script 
            msg_box 8 blah
        fi
    else
       msg_box 8 "No new updates found"
       unlink $temp_file
    fi
}
