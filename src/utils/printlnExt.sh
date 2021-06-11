function println() {
	local RETC
	local PFUNCNAME
	: "${RETC:="$?"}"
	: "${PFUNCNAME:="${FUNCNAME[0]}"}"
	export PFUNCNAME # Expose the function name to other intances
	echo -e "$(date "+%F %T [$(test "$RETC" != 0 && echo "ERROR::$RETC" || echo 'INFO')]") (${0##*/}::$PFUNCNAME): $@"
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

