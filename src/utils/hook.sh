#######################
#######################
##                   ##
##      PRIVATE      ##
##                   ##
#######################
#######################

function load.hooks() {
# TODO: Better error message



	function hook::parse_option() {
		local input="$1"
		local range="${2:-1}"
		local values
		values=($(sed 's|,| |g' <<<"$input"))

		local lines
		for value in "${values[@]}"; do
			lines+="$(echo -e "\n${value}")"
		done

		# If the specified range is larger than input string
		# Then we just return the 1st line.
		if test "$(wc -l <<<"$lines")" -lt "$range"; then
			head -n1 <<<"$lines"
		else
			sed -n "${range}p" <<<"$lines"
		fi
	}

	function hook::install() {
		(
			HOOK_NAME="$1"
			HOOK_PATH="$(hook::fetch_path "$HOOK_NAME")"
			export HOOK_BASE="$HOOK_PATH"

			# Ignore hook if necessary
			if test -e "$HOOK_PATH/bd.ignore.sh"; then
				exit 0
			fi

			# Read metadata
			set -a
			source "$HOOK_PATH/bd.meta.sh" ||	{
													r=$?
													RETC=$r println "Failed to load $HOOK_NAME metadata"
													exit $r
												}
			set +a
			# Satisfy dependencies
			for dep in "${DEPENDS[@]}"; do
				! grep -qI "^${dep}\b" "$APPLIED_HOOKS_STAT_FILE" && {
					hook::install "$dep" || exit
				}
			done
			
			println "Hooking ${HOOK_NAME}"
			chmod +x "$HOOK_PATH/$COMMON_HOOK_FILE_NAME" || exit

			if test -z "$AUTO_REPLY" \
				|| test "$(hook::parse_option "$INTERACTIVE" 1)" == yes; then
				bash -e "$HOOK_PATH/$COMMON_HOOK_FILE_NAME" || exit
			else
				yes | bash -e "$HOOK_PATH/$COMMON_HOOK_FILE_NAME" || exit
			fi

			# Log the installed hook on success
			echo "$CODENAME" >> "$APPLIED_HOOKS_STAT_FILE"
			unset HOOK_BASE
		)
	}


	### Starting point of the function
	##################################

	# A lazy way to assume if we have mountpoints loaded up
	! mountpoint -q "$SYSTEM_MOUNT_DIR" && {
		(exit 1)
		println "You need to load-image first"
		exit 1
	}

	# Cleanup previously created statfile if exists
	for _file in "$APPLIED_HOOKS_STAT_FILE" "$GENERATED_HOOKS_LIST_FILE"; do
		test -e "$_file" && {
			rm "$_file" || exit
		}
	done
	touch "$APPLIED_HOOKS_STAT_FILE" || exit

	# Load native gearlock functions
	source "$SRC_DIR/libgearlock.sh" || exit

	println "Attaching hooks"

	# Get the list of hooks
	if test -e "${HOOKS_LIST_FILE:="$HOOKS_DIR/hooks_list.sh"}"; then
		mapfile -t hooks < <(awk 'NF' < "$HOOKS_LIST_FILE" | sed '/#.*/d' \
							| awk -v hook_dir="$HOOKS_DIR" -v file_name="$COMMON_HOOK_FILE_NAME" \
							'{print hook_dir "/"$0"/file_name"}')
	else
		readarray -d '' hooks < <(find "$HOOKS_DIR" -type f -name "$COMMON_HOOK_FILE_NAME" -print0)
	fi

	# Generate the hooks list
	for hook in "${hooks[@]}"; do
		echo "$hook" >> "$GENERATED_HOOKS_LIST_FILE" || exit
	done

	# Process the hooks
	for hook in "${hooks[@]}"; do

		hook="${hook%/*}"
		hook="${hook##*/}"

		! grep -qI "^${hook}\b" "$APPLIED_HOOKS_STAT_FILE" && {
			hook::install "${hook}" || { 
					r=$?
					RETC=$r println "The last hook invoking exited unexpectedly"
					exit $r
				}
		}

		unset hook

	done

	unset PFUNCNAME
	unset APPLIED_HOOKS_STAT_FILE
}


#######################
#######################
##                   ##
##      PUBLIC       ##
##                   ##
#######################
#######################

function hook::fetch_path() {
	local HOOK_NAME="$1"
	test -z "$GENERATED_HOOKS_LIST_FILE" \
		&& RETC=1 println "\$GENERATED_HOOKS_LIST_FILE variable is not defined" && exit 1

	local HOOK_DIR
	HOOK_DIR="$(grep -I "/.*/$HOOK_NAME/$COMMON_HOOK_FILE_NAME" "$GENERATED_HOOKS_LIST_FILE")"

	if test -z "$HOOK_DIR"; then
		RETC=1 println "Failed to fetch HOOK_DIR"
		exit 1
	else
		echo "${HOOK_DIR%/*}"
	fi

}

function hook::wait_until_done() {
	local HOOK_NAME
	test ! -e "$APPLIED_HOOKS_STAT_FILE" && return 1
	until grep -qI "^${HOOK_NAME}\b" "$APPLIED_HOOKS_STAT_FILE"; do
		sleep 0.2
	done
}

# TODO: Create a stat holder file and a function to retrieve the status of running hook and/or wait for that hook to complete in a subprocess over another hook.
