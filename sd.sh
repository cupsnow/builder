#!/bin/bash

_pri_self="$(cd $(dirname ${BASH_SOURCE[0]}) && pwd -L)/$(basename ${BASH_SOURCE[0]})"

_pri_sgr_red="\033[31;1m"
_pri_sgr_cyan="\033[36;1m"
_pri_sgr_reset="\033[m"

log_ts () {
  date '+%0y/%0m/%0d %0H:%0M:%0S:%0N'
}

log_d () {
  "echo" -e "${_pri_sgr_reset}[$(log_ts)][debug] $*"
}

log_e () {
  "echo" -e "${_pri_sgr_red}[$(log_ts)][ERROR] $*${_pri_sgr_reset}"
}

# malfunction when use stdio redirect
cmd_run () {
  log_d "Execute: $*"
  "$@"
}

trap "housekeeping" SIGINT SIGTERM EXIT

housekeeping () {
  log_d "housekeeping"

  local rc=$?
  if [ "$_pri_tmpdir" ] && [ -e $_pri_tmpdir ]; then
    cmd_run rm -rf $_pri_tmpdir
  fi
  exit $?
}

# size of 1st partition in MB
_pri_sz1=250
_pri_offset1=2
_pri_uiquery=2

# enable to use temp directory
# _pri_tmpdir=`mktemp -d`

show_help() {
local prog="${1:-$(basename $_pri_self)}"
cat <<EOF
USAGE
  $prog [OPTIONS] [DEV]

DESCRIBE
    The 1st partition offset <$OFFSET1>MB

OPTIONS
  -h, --help      Show help
  -d, --dev=DEV   SD card device
  -q, --quiet     Less user interaction
  --sz1=VAL       Size of 1st partition in MB[<$_pri_sz1>]
  --offset1=VAL   Offset of 1st partition in MB[<$_pri_offset1>]

EXAMPLES
  $prog /dev/sdc
  $prog --sz1=100 /dev/sdc

EOF
}

commentary() {
read -p "$*"
cat <<EOF
$*
EOF
read
}

OPT_SAVED="$*"

OPT_PARSED=`getopt -l "help,dev::sz1::,nocommentary," "hd::s::n" $@`
r=$?
if [ ! "$r" = "0" ]; then
  show_help $0
  exit $r
fi

# re-assign positional parameter
eval set -- "$OPT_PARSED"
while true; do
  log_debug "parse[$#] $*"
  [ $# -lt 1 ] && break
  case "$1" in
  -h|--help)
    show_help $0
    exit 1
    ;;
  -d|--dev)
    DEV=$2
    shift
    ;;
  -s|--sz1)
    SZ1=$2
    shift
    ;;
  -n|--nocommentary)
    NOCOMMENTARY="y"
    shift
    ;;
#  --)
#    if [ -z "$SRC" ]; then
#      SRC=$2
#      shift
#    fi
#    if [ $# -lt 2 ]; then break; fi
#    if [ -z "$TGT" ]; then
#      TGT=$2
#      shift
#    fi
#    break
#    ;;
  esac
  shift
done

log_debug "DEV: $DEV"
log_debug "SZ1: $SZ1, SZ1 + 1: $(( $SZ1 + 1 ))"

# such as ${DEV}${MMC_P}1 for /dev/mmcblk1p1 or /dev/sdc1
[ -n "`expr $DEV : '\(/dev/mmcblk[0-9]*$\)'`" ] && MMC_P="p"

if [ -z "$DEV" ] || [ ! -e "$DEV" ]; then
  error_exit 1 "Miss device"
fi

if ! { udevadm info -q path $DEV | grep "/usb[0-9]*"; }; then
  error_exit 1 "Not usb disk"
fi

log_debug "sudo to access '$DEV'"
sudo -k \
  sfdisk -l $DEV

[ -n "$NOCOMMENTARY" ] || { \
  echo ""; \
  read -t 5 -p "Press enter in 5 seconds to partition the device ..." || \
    error_exit $? "Timeout"; }

# FS1_FAT=fat16
case $FS1_FAT in
6|0x6|fat16)
  FS1_FATID=0x6
  FS1_FATSZ=16
  ;;
*)
  FS1_FATID=0xc
  FS1_FATSZ=32
  ;;
esac

sudo sfdisk $DEV <<EOF
${OFFSET1}M,${SZ1}M,${FS1_FATID},*
$(( $SZ1 + 1 ))M,,,-
EOF

# for slow machine
sync
sleep 1

sudo mkfs.fat -F ${FS1_FATSZ} -n BOOT ${DEV}${MMC_P}1

sudo mkfs.ext4 -L rootfs ${DEV}${MMC_P}2

