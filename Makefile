.DEFAULT_GOAL := wedge-conf.sh

all: wedge-conf.sh 

wedge-conf.sh: system/* modules/* 
	echo '#!/bin/bash' > "$@"
	echo "# generated $(shell date)\n" >> "$@"
	cat LICENSE | sed 's/^/# /' >> "$@"
	cat header.sh >> "$@"
	cat $^ >> "$@" || (rm -f "$@"; exit 1)
	cat footer.sh >> "$@"
	chmod u+x "$@"

clean: 
	rm wedge-conf.sh
