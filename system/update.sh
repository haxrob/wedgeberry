
SCRIPT_GITHUB_URL="https://raw.githubusercontent.com/haxrob/wedgeberry/main/wedge-conf.sh"
function check_updates() {
    current_script="${BASH_SOURCE[0]}"
    contents=$(curl --silent $SCRIPT_GITHUB_URL) 
    remote_hash=$(echo -n $contents | md5sum | cut -d' ' -f1)
    my_hash=$(cat $current_script | md5sum | cut -d' ' -f1)
    if [[ $remote_hash != $my_hash ]]; then
        if yesno_box 8 "A newer version was found. ?"; then
            echo "$contents" > $current_script
            exec $current_script 
        fi
    else
       msg_box 8 "No new updates found"
    fi
}