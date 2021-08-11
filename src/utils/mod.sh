use logExt;
use bash;

#######################
#######################
##                   ##
##      PRIVATE      ##
##                   ##
#######################
#######################

function get.systemimg() {
	local IMG_BASE="$1"
	export SYSTEM_IMAGE="$(
		if test -e "$IMG_BASE/system.img"; then
			echo "$IMG_BASE/system.img"
		elif test -e "$IMG_BASE/system.sfs"; then
			echo "$IMG_BASE/system.sfs"
		else
			(exit 1)
			println "System image not found"
			exit 1
		fi
	)"
}


#######################
#######################
##                   ##
##      PUBLIC       ##
##                   ##
#######################
#######################

function gclone(){
	echo -e "============= ${GREEN}Progress${RC} = ${ORANGE}Speed${RC} ========================================"
	rsync -ah --info=progress2 "$@"
}


function wipedir() {
	local dir2wipe
	for dir2wipe in "$@"; do
		if [ -e "$dir2wipe" ]; then
			find "$dir2wipe" -mindepth 1 -maxdepth 1 -exec rm -r '{}' \;
		fi
	done
}
