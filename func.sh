#!/bin/bash

log_d () {
  echo "[debug]$*"
}

log_e () {
  echo "[ERROR]$*"
}

cmd_run () {
  log_d "Execute $*"
  "$@"
}

svc_json_help () {
  cat <<-EOHELP
USAGE
  ${1:-$(basename $0)} [OPTIONS] <json file> <components>

OPTIONS
  -h, --help  Show this help

EXAMPLE
  ex1:
    ${1:-$(basename $0)} cfg.json '["dev_cfg"]["dev_name"]'

EOHELP
}

svc_json () {
  local opt=$(getopt -l "help" -- "h" "$@") || exit 1
  
  eval set -- "${opt}"
  while true; do
#   log_d "\$1: $1, \$2: $2"
    case "$1" in
    -h|--help)
      svc_json_help svc_json
      exit 1
      ;;
    --)
      shift
      break
      ;;
    esac
  done
  
# log_d "non-option: $@"
  
  if [ -z "$2" ]; then 
    log_e "Invalid argument"
    svc_json_help svc_json
    exit 1 
  fi
  
  local file=$1
  local comp=$2

  python - <<-EOPY
import json
with open("$file") as f:
  jobj = json.load(f)
print(jobj${comp})
EOPY
}

svc_test () {
  log_d "svc_test(\$#=$#, \$@=$@)"
  local opt=$(getopt -l "help" -- "h" "$@") || exit 1
  
  eval set -- "${opt}"
  while true; do
    log_d "\$1: $1, \$2: $2"
    case "$1" in
    -h|--help)
cat <<-EOHELP
USAGE
  svc_test [OPTIONS] [non-options]

OPTIONS
  -h, --help  Show this help

EXAMPLE
  ex1:
    svc_test cfg.json '["dev_cfg"]["dev_name"]'

EOHELP
      exit 1
      ;;
    --)
      shift
      break
      ;;
    esac
  done

  log_d "non-option: $@"
}

[[ "$1" =~ svc_.* ]] && "$@"
