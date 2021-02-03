######
######	libgearlock
######	Minimal gearlock environment
######

set -a
############# 
############# From gearlock/bin/fetch
############# 
SYSTEM_DIR="$SYSTEM_MOUNT_DIR"

	RECOVERY="yes"
	GHOME="$SYSTEM_DIR/ghome" && {
		mkdir -p "$GHOME"
		chmod 755 "$GHOME"
	}
	DEPDIR="$GHOME/dependencies"
	STATDIR="$GHOME/status"
	GRLOAD="$GRROOT/gearload"
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
		SDK="$(sed -n "s/^ro.build.version.sdk=//p" "$SYSTEM_DIR/build.prop" 2>/dev/null | head -n 1)"
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

##########################
##########################
##########################
##########################



############# 
############# From gearlock/bin/fetch.in
############# 
# Cli color vars
RC='\033[0m' RED='\033[0;31m' BRED='\033[1;31m' GRAY='\033[1;30m' BLUE='\033[0;34m' BBLUE='\033[1;34m' CYAN='\033[0;34m' BCYAN='\033[1;34m' WHITE='\033[1;37m' GREEN='\033[0;32m' BGREEN='\033[1;32m' YELLOW='\033[1;33m' PURPLE='\033[0;35m' BPURPLE='\033[1;35m' ORANGE='\033[0;33m'
if [ "$TERMINAL_EMULATOR" == "no" ]; then
	UBLACK='' URED='' UGREEN='' UYELLOW='' UBLUE='' UPURPLE='' UCYAN='' UWHITE=''
else
	UBLACK='\033[4;30m' URED='\033[4;31m' UGREEN='\033[4;32m' UYELLOW='\033[4;33m' UBLUE='\033[4;34m' UPURPLE='\033[4;35m' UCYAN='\033[4;36m' UWHITE='\033[4;37m'
fi

# ANSI color vars
MRC='\Zn' MU='\Zu' MBOLD='\Zb' MBLACK='\Z0' MRED='\Z1' MGREEN='\Z2' MYELLOW='\Z3' MBLUE='\Z4' MPINK='\Z5' MCYAN='\Z6' MWHITE='\Z7' ## MetroUi color vars

# UI functions
function geco() {
	echo -e "$@"
}

function pause() {
	test -e "${np:="$GTMP/.nopause"}" && rm -f "$np" && return
	read -rp "$(geco "\n++ ${@}${_press_enter_} ...")" readEnterKey
}

function get_base_dir() {
	BD="$(dirname "$(readlink -f "$0")")"
}

function get_net_stat() {
	geco "\n~ ${_chcking_net_connection_}\n"
	if curl --output /dev/null --silent --fail -r 0-0 "https://www.google.com"; then
		NET_CONN=yes && return 0
	else
		NET_CONN=no && geco "\n~ ${_net_connection_unavailable_} ..." && return 1
	fi
}

function check_compat() {
	MINV="$1" MAXV="$GEARLOCK_VER"
	shift
	if (( $(echo "$MINV $MAXV" | awk '{print ($1 == $2)}') )) \
	|| (( $(echo "$MINV $MAXV" | awk '{print ($1 < $2)}') )); then
		COMPAT="yes"
		return 0
	else
		COMPAT="no"
		return 1
	fi
}

# Metro IT specific
function calcTextDialogSize() {
	MIN_HEIGHT=10
	MIN_WIDTH=40
	MAX_HEIGHT=$(( $(tput lines) / 2 ))
	MAX_WIDTH=$(( $(tput cols) * 3 / 4 ))
	
	: "${TEST_STRING:="$1"}"
	CHARS=${#TEST_STRING}
	
	RECMD_HEIGHT=$((CHARS / MIN_WIDTH))
	RECMD_WIDTH=$((CHARS / MIN_HEIGHT))
	if [ "$RECMD_HEIGHT" -gt "$MAX_HEIGHT" ]; then
		RECMD_HEIGHT=$MAX_HEIGHT
	elif [ "$RECMD_HEIGHT" -lt "$MIN_HEIGHT" ]; then
		RECMD_HEIGHT=$MIN_HEIGHT
	fi
	if [ "$RECMD_WIDTH" -gt "$MAX_WIDTH" ]; then
		RECMD_WIDTH=$MAX_WIDTH
	elif [ "$RECMD_WIDTH" -lt "$MIN_WIDTH" ]; then
		RECMD_WIDTH=$MIN_WIDTH
	fi
}

function msgbox() {
	test -n "$4" && test -n "$5" && RECMD_HEIGHT="$4" && RECMD_WIDTH="$5" || calcTextDialogSize "$1"
	dialog --clear --colors --backtitle "$1" --title "$2" --msgbox "$3" $RECMD_HEIGHT $RECMD_WIDTH
	return
}

function displayFile() {
	test -n "$4" && test -n "$5" && RECMD_HEIGHT="$4" && RECMD_WIDTH="$5" || calcTextDialogSize "$(< "$3")"
	dialog --clear --colors --backtitle "$1" --title "$2" --textbox "$3" $RECMD_HEIGHT $RECMD_WIDTH
	return
}

function yesno() {
	test -n "$4" && test -n "$5" && RECMD_HEIGHT="$4" && RECMD_WIDTH="$5" || calcTextDialogSize "$3"
	dialog --clear --colors --backtitle "$1" --title "$2" --yesno "$3" $RECMD_HEIGHT $RECMD_WIDTH
	return
}

# GXPM specific
function chk_ghome() {
	test -z "$GHOME" || test ! -e "$GHOME" && {
		clear && pause "- ghome is missing" && exit 1
	}
}

function gxpmJob() {
	local SP_DELAY="${4:-.2}" \
		SP_STRING="${3:-"-----$(test ${#RANDOM} -lt 5 && echo + || echo = )"}" \
		SP_COLOR=0 \
		msg="${1:-"Doing something special"}"
	JOBS+="$2 "
	tput civis && printf "\033[1;34m"
	while test -d /proc/${5:-"$!"}; do
		echo -n "${msg}"
		printf "\e[38;5;$((RANDOM%257))m %${SP_WIDTH}s\r" "$SP_STRING"
		sleep $SP_DELAY
		SP_STRING=${SP_STRING#"${SP_STRING%?}"}${SP_STRING%?}
	done
	printf '\033[s\033[u%*s\033[u\033[0m' $((${#msg}+6)) " "
	echo -ne "xyzzyxyzzy\r$(tput el)"
	tput cnorm
	return 0
}

##########################
##########################
##########################
##########################



