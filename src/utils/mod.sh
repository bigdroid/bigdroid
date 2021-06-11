use mount;
use iso;
use hook;

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

function println() {
	local RETC
	local PFUNCNAME
	: "${RETC:="$?"}"
	: "${PFUNCNAME:="${FUNCNAME[0]}"}"
	export PFUNCNAME # Expose the function name to other intances
	echo -e "$(date "+%F %T [$(test "$RETC" != 0 && echo "ERROR::$RETC" || echo 'INFO')]") (${0##*/}::$PFUNCNAME): $@"
}

function wipedir() {
	local dir2wipe
	for dir2wipe in "$@"; do
		if [ -e "$dir2wipe" ]; then
			find "$dir2wipe" -mindepth 1 -maxdepth 1 -exec rm -r '{}' \;
		fi
	done
}

function println.cmd() {
	local result args
	args=$(printf '%q ' "$@")
	local string="$@"
	println "Running ${string:0:$((69 - ${#PFUNCNAME}))}..."
	result="$(bash -c "$args" 2>&1)"
	local RETC="$?"
	if test "$RETC" != 0; then
		(exit "$RETC")
		println "$result"
		exit "$RETC"
	fi
}
