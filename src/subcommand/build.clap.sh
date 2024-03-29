# Created by argbash-init v2.10.0
# ARG_OPTIONAL_BOOLEAN([debug])
# ARG_OPTIONAL_BOOLEAN([release])
# ARG_POSITIONAL_SINGLE([path])
# ARG_DEFAULTS_POS()
# ARG_HELP([<The general help message of my script>])
# ARGBASH_GO()
# needed because of Argbash --> m4_ignore([

# ENSURE ROOT
if test "$EUID" -ne 0; then {
	if ! sudo -nv 2>/dev/null; then {
		log::warn "Build command needs root for some operations, reqesting root...";
		sudo -v;

		# Perserve the root access
		(
			while sleep 60 && test -e "/proc/$___self_PID"; do {
				sudo -v;
			} done
		) &
	} fi
} fi


# THE DEFAULTS INITIALIZATION - POSITIONALS
_positionals=();
_subcommand_hook_args=();
_arg_path=;
# THE DEFAULTS INITIALIZATION - OPTIONALS
_arg_debug="off";
_arg_release="off";
_arg_run="off";
_arg_hooks_only="off";
_arg_image_only="off";
_arg_reply_yes="off";
_arg_no_squashfs="off";

parse_commandline()
{
	_positionals_count=0;
	while test $# -gt 0; do {
		_key="$1"
		case "$_key" in
			--debug)
				_arg_debug="on";
				;;
			--release)
				_arg_release="on";
				;;
			--run)
				_arg_run="on";
				;;
			--hooks-only)
				_arg_hooks_only="on";
				;;
			--image-only)
				_arg_image_only="on";
				;;
			--no-squashfs)
				_arg_no_squashfs="on";
				;;
			--reply-yes)
				_arg_reply_yes="on";
				;;
			--help)
				print_help && exit 0;
				;;
			--dev|--force|--sync)
				_subcommand_hook_args+=("$_key"); # For subcommand::hook()
				;;
			--) # Do not parse anymore if _run_target_args are found.
				return 0;
				;;
			*)
				_last_positional="$1";
				_positionals+=("$_last_positional");
				_positionals_count=$((_positionals_count + 1));
				;;
		esac
		shift
	} done
}


handle_passed_args_count()
{
	local _required_args_string="'path'";
	test "${_positionals_count}" -ge 1 || log::error "Not enough positional arguments - we require exactly 1 (namely: $_required_args_string), but got only ${_positionals_count}." 1 || exit;
	test "${_positionals_count}" -le 1 || log::error "There were spurious positional arguments --- we expect exactly 1 (namely: $_required_args_string), but got ${_positionals_count} (the last one was: '${_last_positional}')." 1 || exit;
}


assign_positional_args()
{
	local _positional_name _shift_for=$1;
	_positional_names="_arg_path ";

	shift "$_shift_for";
	for _positional_name in ${_positional_names}; do {
		test $# -gt 0 || break;
		eval "$_positional_name=\${1}" || log::error "Error during argument parsing, possibly an Argbash bug." 1 || exit;
		shift;
	} done
}

parse_runargs()
{
	for _arg in "${@}"; do { 
		if test "$_arg" != '--'; then { 
			shift;
		} else {
			shift; # Escapes the `--` itself.
			_run_target_args=("$@");
			readonly _run_target_args;
			break;
		} fi
	} done
}

parse_commandline "$@";
# Parse _run_target_args
parse_runargs "$@";
# handle_passed_args_count
assign_positional_args 1 "${_positionals[@]}";

function gettop() {
	# Taken from AOSP build/envsetup.sh with slight modifications
    local TOPFILE="$_bigdroid_meta_name";
	local TOPDIR="$_src_dir_name";
	local TOP=;
	local T;
    if [ -n "$TOP" ] && [ -f "$TOP/$TOPFILE" ] && [ -d "$TOPFILE" ]; then {
        # The following circumlocution ensures we remove symlinks from TOP.
        (cd "$TOP"; echo "$PWD");
    } else {
        if [ -f "$TOPFILE" ] && [ -d "$TOPDIR" ]; then {
            # The following circumlocution (repeated below as well) ensures
            # that we record the true directory name and not one that is
            # faked up with symlink names.
            echo "$PWD";
		} else {
            local HERE="$PWD";
            while [ \( ! \( -f "$TOPFILE" -a "$TOPDIR" \) \) -a \( "$PWD" != "/" \) ]; do {
                \cd ..;
                T="$(readlink -f "$PWD")";
			} done
            \cd "$HERE";
            if [ -f "$T/$TOPFILE" ] && [ -d "$T/$TOPDIR" ]; then {
                echo "$T";
			} fi
		} fi
	} fi
}

: "${_arg_path:="$PWD"}";
_arg_path="$(readlink -f "$_arg_path")"; # Pull full path
if test ! -e "$_arg_path/$_bigdroid_meta_name"; then {
	_top="$(gettop)";
	if test -n "$_top"; then {
		_arg_path="$_top";
		unset _top;
	} else {
		log::error "$_arg_path is not a valid bigdroid project" 1 || exit;
	} fi
} fi

readonly _arg_path;
# readonly _hooks_dir="$_arg_path/$_hooks_dir_name";
readonly _src_dir="$_arg_path/$_src_dir_name" && mkdir -p "$_src_dir";
readonly _mount_dir="$_arg_path/$_mount_dir_name" && mkdir -p "$_mount_dir";
readonly _overlay_dir="$_mount_dir/$_overlay_dir_name" && mkdir -p "$_overlay_dir";
readonly _bigdroid_meta_file="$_arg_path/$_bigdroid_meta_name";

readonly _target_dir="$_arg_path/$_target_dir_name";
readonly _target_release_dir="$_target_dir/$_release_dir_name";
readonly _target_debug_dir="$_target_dir/$_debug_dir_name";

# Now lets detect the run variant
_build_variant="$(
	if test "$_arg_release" == "on"; then {
		echo "${_target_release_dir##*/}";
	} else {
		echo "${_target_debug_dir##*/}";
	} fi
)"; # TODO: Need to add more cases depending on args.
readonly _build_variant;
readonly _target_workdir="$_target_dir/$_build_variant";
readonly _build_dir="$_target_workdir/build";
# Make sure to empty the temporary dir
readonly _tmp_dir="$_target_workdir/$_tmp_dir_name" && mkdir -p "$_tmp_dir" && wipedir "$_tmp_dir";
export _applied_hooks_statfile="$_tmp_dir/.applied_hooks" && readonly _applied_hooks_statfile;

### Create mount dirs
for _mdir in system initial_ramdisk install_ramdisk secondary_ramdisk; do {
	# PFUNCNAME="mount_dir" println.cmd mkdir -p "$MOUNT_DIR/$_dir" && chmod 755 "$MOUNT_DIR/$_dir"
	eval "export ${_mdir^^}_MOUNT_DIR=\"$_mount_dir/$_mdir\"" # EXPORTS
	mkdir -p "$_mount_dir/$_mdir";
} done
unset _mdir;


### END OF CODE GENERATED BY Argbash (sortof) ### ])
