
# final bash script is generated via Makefile. Inform user if they attempt to run wrong script
if ! type -t healthcheck > /dev/null; then
   echo "Required functions undefined. Please run generated wedge-conf.sh, e.g. 'make; ./wedge-conf.sh'"
   exit
fi

main