.DEFAULT_GOAL := wedge-conf.sh

all: wedge-conf.sh 

wedge-conf.sh: ./src/system/* ./src/modules/* 
	echo '#!/bin/bash' > "$@"
	echo "# Generated $(shell date)\n" >> "$@"
	cat LICENSE | sed 's/^/# /' >> "$@"
	cat ./src/header.sh >> "$@"
	cat $^ >> "$@" || (rm -f "$@"; exit 1)
	cat ./src/footer.sh >> "$@"
	chmod u+x "$@"
	mv "$@" ./build

clean: 
	rm ./build/wedge-conf.sh
