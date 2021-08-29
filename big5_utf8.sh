#/bin/bash

log_d () {
  echo "DEBUG $*"
}

args_join () {
  local out=
  for i in $1; do
    [ -n "$out" ] && out="${out}${2}${3}${i}${4}" || out="${3}${i}${4}"
  done
  "echo" -n $out
}

MATCH_PATTERN="*.h *.c *.cfg *.cmd"

show_help () {
  cat <<EOF
USAGE
  $0 [path...]

EOF
}

match_file () {
  local i=
  for i in $MATCH_PATTERN; do
    [[ "`basename $1`" == $i ]] && return 0
  done
  log_d "ignore $1"
  return 1
}

conv_file () {
  local FNREL=`realpath .`
  local FN=`realpath --relative-base=$FNREL $@`
  local FNDEST=build/iconv/`dirname $FN`/`basename $FN`
  [ ! -d `dirname $FNDEST` ] && mkdir -p `dirname $FNDEST`  
  log_d "iconv $FN -o $FNDEST"
  iconv -f BIG-5 -t UTF-8 $FN -o $FNDEST || (iconv -f UTF-8 $FN -o $FNDEST && echo "Assumed UTF-8")
}

[ "$#" -eq 0 ] && { show_help; exit; }

FIND_PATTERN=`args_join "$MATCH_PATTERN" " -o " "-iname "`
log_d "FIND_PATTERN: $FIND_PATTERN"

for i in "$@"; do
  [ -f $i ] && match_file $i && { conv_file $i; continue; }
  if [ -d $i ]; then
    for j in `find $i $FIND_PATTERN`; do
      conv_file $j
    done
    continue
  fi
done

# test
# ./builder/charset_conv.sh Makefile ../wsm0915/Makefile base/mmw_mss_16xx/Security.c base/mmw_mss_16xx/platform ../bbq3-mkr4000/mkr4000/sercom.c  ./app_attr.h




