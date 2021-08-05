# function println() {
# 	local RETC
# 	local PFUNCNAME
# 	: "${RETC:="$?"}"
# 	: "${PFUNCNAME:="${FUNCNAME[0]}"}"
# 	export PFUNCNAME # Expose the function name to other intances
# 	echo -e "$(date "+%F %T [$(test "$RETC" != 0 && echo "ERROR::$RETC" || echo 'INFO')]") (${0##*/}::$PFUNCNAME): $@"
# }

function log::cmd() {
	local _result;
	local _result_retcode=0;
	
	local _string="$@";
	# args=$(printf '%q ' "$@")
	# local string="$@"
	# println "Running ${string:0:$((69 - ${#PFUNCNAME}))}..."
	if test "$_arg_no_verbose" == "off"; then {
		log::info "Running ${_string::69}...";
	} fi
	# result="$(bash -c "$args" 2>&1)"
	_result="$("$@" 2>&1)" || _result_retcode=$?;

	if test "$_result_retcode" != 0; then {
		log::error "${_string} exited with errorcode ${_result_retcode}\n$_result" $_result_retcode || exit;
	} fi
	
}

