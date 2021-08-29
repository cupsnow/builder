#!/bin/bash
SELF=${BASH_SOURCE[0]}
SELFDIR=`dirname $SELF`
# SELFDIR=`realpath -L -s $SELFDIR`
SELFDIR=`cd $SELFDIR && pwd -L`

# size of 1st partition in MB
SZ1=70
OFFSET1=1

log_ts () {
  "echo" -n "`date '+%0y/%0m/%0d %0H:%0M:%0S:%0N'`"
}

log_error () {
  "echo" -e "\033[31;1m`log_ts` ERROR $*\033[0m"
}


log_debug () {
  "echo" -e "\033[36;1m`log_ts` DEBUG $*\033[0m"
}

# usage: error_exit ERRNO ERRMSG
# print ERRMSG then exit when ERRNO != 0
error_exit () {
  [ "$1" = "0" ] && return 0
  log_error "$*"
  exit
}

trap "housekeeping" SIGINT SIGTERM EXIT

# enable to use temp directory
# tmpdir=`mktemp -d`

# housekeeping before exit
housekeeping () {
  # housekeeping whatever temp directory
  [ "$tmpdir" ] && [ -e $tmpdir ] && (log_debug "remove $tmpdir"; rm -rf $tmpdir)
  
  # housekeeping more

  # done  
  exit 255
}

show_help() {
cat <<EOF
SYNOPSIS
  $1 [OPTIONS]

    The 1st partition offset <$OFFSET1>MB

OPTIONS
  -h, --help   Show help
  -d, --dev=DEV
               SD card device[<>]
  -s, --sz1=SZ1
               Size of 1st partition in MB[<$SZ1>]

EXAMPLES
  $1 -d/dev/sdc -s77

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

log_debug "sudo to access '$DEV'"
sudo -k \
  sfdisk -l $DEV

[ -n "$NOCOMMENTARY" ] || { \
  echo ""; \
  read -t 5 -p "Keep going to re-partition the device ..." || \
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

