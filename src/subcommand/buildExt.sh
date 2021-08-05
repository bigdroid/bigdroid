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

function ensure::isocommon() {
	if test ! -e "$_bigdroid_isocommon_dir/.git"; then {
		wipedir "$_bigdroid_isocommon_dir";
		log::info "Fetching isocommon repository";
		log::cmd git clone https://github.com/supremegamers/awin-installer-dev "$_bigdroid_isocommon_dir";
	} fi
}

#######################
#######################
##                   ##
##      PUBLIC       ##
##                   ##
#######################
#######################

set -a;
function gclone(){
	echo -e "============= ${GREEN}Progress${RC} = ${ORANGE}Speed${RC} ========================================"
	rsync -ah --info=progress2 "$@"
}

function wipedir() {
	local dir2wipe
	for dir2wipe in "$@"; do
		if [ -e "$dir2wipe" ]; then
			sudo find "$dir2wipe" -mindepth 1 -maxdepth 1 -exec rm -r '{}' \;
		fi
	done
}


function mount::umountTree() {
	local _tree="$1";
	local _mountpoint;
	local _mountdump;
	_mountdump="$(mount | grep "$_tree" || true)";
	if test -n "$_mountdump"; then {
		while read -r _mountpoint; do
			log::cmd sudo umount -fd "$_mountpoint";
		done < <(mount | grep "$_tree" | awk '{print $3}' | tac)
	} fi
}

function mount::overlayFor() {
	local _for="$1";
	local _overlay_dir_node="$_overlay_dir/${_for##*/}";

	log::cmd wipedir "$_overlay_dir_node";
	mkdir -p "$_overlay_dir_node" "$_overlay_dir_node/lower" "$_overlay_dir_node/worker";
	log::cmd sudo mount -t overlay overlay \
		-olowerdir="$_for",upperdir="$_overlay_dir_node/lower",workdir="$_overlay_dir_node/worker" "$_for";
}
set +a;