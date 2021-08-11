######
######	libgearlock
######	Minimal gearlock environment
######

############# 
############# From gearlock/bin/fetch
############# 
	set -a;
	SYSTEM_DIR="$SYSTEM_MOUNT_DIR"
	RECOVERY="yes"
	GHOME="$SYSTEM_DIR/ghome" && {
		sudo mkdir -p "$GHOME"
		sudo chmod 755 "$GHOME"
	}
	DEPDIR="$GHOME/dependencies"
	STATDIR="$GHOME/status"
	# GRLOAD="$GRROOT/gearload"
	UNINSDIR="$GHOME/unins"
	GAPPID="com.supremegamers.gearlock"
	GBDIR="$GHOME/gearboot"
	OVERLAYDIR="$GBDIR/overlay"
	EXTDIR="$GHOME/extensions"
	HOOKDIR="$GHOME/hook"
	WORKDIR="$GHOME/workdir"
	GCOMM="gearlock"
	YEAR="$(date '+%Y')"
	DATE="$(date '+%dd-%mmo-%Yy_%Ss-%Mm-%Hh')"
	KMODDIR="$SYSTEM_DIR/lib/modules"
	
	HOST_ARCH="$(
		if test -e "$SYSTEM_DIR/lib64"; then
			echo "x86_64"
		elif test -e "$SYSTEM_DIR/lib"; then
			echo "x86"
		fi
    )"
	CPU_ARCH="$HOST_ARCH"
    
	if test -e "$SYSTEM_DIR/build.prop"; then
		SDK="$(sudo sed -n "s/^ro.build.version.sdk=//p" "$SYSTEM_DIR/build.prop" 2>/dev/null | head -n1)"
	
		case "$SDK" in
			22) v="5.1" ;;
			23) v="6.0" ;;
			24) v="7.0" ;;
			25) v="7.1" ;;
			26) v="8.0" ;;
			27) v="8.1" ;;
			28) v="9.0" ;;
			29) v="10.0" ;;
			30) v="11.0" ;;
		esac
		ANDROID_VER="$v"
		unset v
	else
		SDK="26"
		echo "[!!!] Warning: could not detect SDK, maybe system is missing, assuming SDK as $SDK"
		ANDROID_VER="8.0" # FIXME: Needs betterment
	fi
	set +a;
##########################
##########################
##########################
##########################
