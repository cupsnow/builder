#/bin/bash

log_d () {
  echo "DEBUG $*"
}

show_help () {
  cat <<EOF
USAGE
  $0 <name> <input | STDIN>
  
EOF
}

if [ -z "$1" ]; then
  show_help
  exit 1
fi

name=$1
input=$2

echo "#include <stdlib.h>"
echo "#include <stdint.h>"
echo "static const uint8_t _${name}[] = {"
xxd -i < ${input:-/dev/stdin}
echo ", 0"
echo "};"
echo "const uint8_t *${name} = _${name};"
if [ -n "$input" ]; then
  name_sz=$(( `stat -c "%s" $input` + 1 ))
  echo "const size_t ${name}_size = ${name_sz};"
else
  echo "const size_t ${name}_size = sizeof(_${name});"
fi

