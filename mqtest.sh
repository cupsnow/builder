#!/bin/bash

log_d () {
  echo "[debug]$*"
}

cmd_run () {
  log_d "Execute $*"
  "$@"
}

CRTDNS=`hostname`
SYSROOT=build/sysroot-ub20
CRTPREFIX=${SYSROOT}/etc/mqcrt/
MQCFG=${SYSROOT}/etc/mosquitto.conf
MQTOPIC="othsa_test1"

subj_c="TW"
subj_st="Taiwan"
subj_l="Taipei"
subj_o="jl.org"
subj_ou="sw"
subj_cn="jl"

gen_subj () {
  local subj_cn="$1"
  local subj=
  subj="${subj}${subj_c:+/C=$subj_c}"
  subj="${subj}${subj_st:+/ST=$subj_st}"
  subj="${subj}${subj_l:+/L=$subj_l}"
  subj="${subj}${subj_o:+/O=$subj_o}"
  subj="${subj}${subj_ou:+/OU=$subj_ou}"
  subj="${subj}${subj_cn:+/CN=$subj_cn}"
  echo "${subj}"
}

gen_san () {
  # -addext "subjectAltName=DNS.1:foo.co.uk,DNS.2:foo.co.uk"
  local addext_san=
  local n=1
  for i in "$@"; do
    addext_san="${addext_san:+${addext_san},}DNS.${n}:${i}"
    n=$(( $n + 1 ))
  done
  echo "${addext_san:+subjectAltName=${addext_san}}"
}

gen_crt () {
  # keyenc=-des3
  local dns=${1:-${CRTDNS}}
  local crtprefix=${2:-${CRTPREFIX}}
  local defmd=-sha512
  local keybits=4096

  [ -d "$(dirname ${crtprefix}xxx)" ] || cmd_run mkdir -p "$(dirname ${crtprefix}xxx)"
  
  log_d "Generate a certificate authority certificate and key"
  cmd_run openssl req -newkey rsa:${keybits} -x509 -nodes ${defmd} -days 730 \
      -extensions v3_ca -keyout ${crtprefix}ca.key -out ${crtprefix}ca.crt \
      -subj "$(gen_subj othsa-ca)"
  
  log_d "Generate a server key"
  cmd_run openssl genrsa ${keyenc} -out ${crtprefix}server.key ${keybits}
  
  log_d "Generate a certificate signing request to send to the CA"
  cmd_run openssl req -new ${defmd} -out ${crtprefix}server.csr \
      -key ${crtprefix}server.key -subj "$(gen_subj "${dns}")" \
      -addext "$(gen_san "${dns}")"
  
  log_d "Send the CSR to the CA, or sign it with your CA key"
  cmd_run openssl x509 -req -in ${crtprefix}server.csr -CA ${crtprefix}ca.crt \
      -CAkey ${crtprefix}ca.key -CAcreateserial -out ${crtprefix}server.crt \
      -days 730
  
  log_d "Generate a client key"
  cmd_run openssl genrsa ${keyenc} -out ${crtprefix}client.key ${keybits}
  
  log_d "Generate a certificate signing request to send to the CA"
  cmd_run openssl req -new ${defmd} -out ${crtprefix}client.csr \
      -key ${crtprefix}client.key -subj "$(gen_subj othsa-client)"
  
  log_d "Send the CSR to the CA, or sign it with your CA key"
  cmd_run openssl x509 -req -in ${crtprefix}client.csr -CA ${crtprefix}ca.crt \
      -CAkey ${crtprefix}ca.key -CAcreateserial -out ${crtprefix}client.crt \
      -days 730
}

gen_mqcfg () {
  [ -d "$(dirname ${MQCFG})" ] || cmd_run mkdir -p "$(dirname ${MQCFG})"

  cat <<-EOMQCFG | tee ${MQCFG}
listener 8767
cafile ${CRTPREFIX}ca.crt
certfile ${CRTPREFIX}server.crt
keyfile ${CRTPREFIX}server.key
allow_anonymous true

EOMQCFG

}

svc_help () {
  cat <<-EOHELP
USAGE
  ${1:-$(basename $0)} [OPTIONS]

OPTIONS
  --help
  --gencrt[=CRTDNS]  Generate certificate with server DNS CRTDNS 
      [default: ${CRTDNS}]
  --mqcfg[=MQCFG]    Generate mosquitto config MQCFG [default: ${MQCFG}]
  --broker[=MQCFG]   Run mosquitto with config MQCFG [default: ${MQCFG}]
  --sub[=MQTOPIC]    MQTT subscribe topic MQTOPIC [default: "${MQTOPIC}"]
  --pub[=MQMSG]      MQTT publish message MQMSG

MQTT OPTIONS
  -t,--topic=MQTOPIC  MQTT topic [default: "${MQTOPIC}"]
  -m,--message=MQMSG  MQTT message

ENVIRONMENT ARGUMENTS
CRTDNS     Server certificate file DNS [default: ${CRTDNS}]
SYSROOT    Path to executable prefix [default: ${SYSROOT}]
CRTPREFIX  Certificate files prefix [default: ${CRTPREFIX}]
MQCFG      Filename to mosquitto config [default: ${MQCFG}]
MQTOPIC    MQTT topic [default: ${MQTOPIC}]
MQMSG      MQTT message [default: ${MQMSG}]

EOHELP

}

svc_broker () {
  LD_LIBRARY_PATH=${SYSROOT}/lib cmd_run ${SYSROOT}/sbin/mosquitto \
      -c ${MQCFG} -v "$@"
}

svc_sub () {
  LD_LIBRARY_PATH=${SYSROOT}/lib cmd_run ${SYSROOT}/bin/mosquitto_sub \
      -h ${CRTDNS} -p 8767 --cafile ${CRTPREFIX}ca.crt \
      --cert ${CRTPREFIX}client.crt --key ${CRTPREFIX}client.key \
      -F "%I qos%q\ntopic: %t\nmessage: %p\n" \
      -i "mqtest_sub" -d -q 1 -t "#" "$@"
}

svc_pub () {
  LD_LIBRARY_PATH=${SYSROOT}/lib cmd_run ${SYSROOT}/bin/mosquitto_pub \
      -h ${CRTDNS} -p 8767 --cafile ${CRTPREFIX}ca.crt \
      --cert ${CRTPREFIX}client.crt --key ${CRTPREFIX}client.key \
      -i "mqtest_pub" -d -q 1 -t "$MQTOPIC" -m "$MQMSG" "$@"
}

_pri_opt_bak="$@"
_pri_opt=$(getopt -l "help,gencrt::,mqcfg::,broker::,sub::,pub::,topic:,message:" -- "ht:m:" "$@") || exit 1

eval set -- "$_pri_opt"

_pri_svc=
_pri_gencrt=
_pri_mqcfg=

while true; do
  log_d "$@"
  case $1 in
  -h|--help)
    _pri_svc=help
    shift
    ;;
  --gencrt)
    [ -z "$2" ] || CRTDNS=$2
    _pri_gencrt=1
    shift 2
    ;;
  --mqcfg)
    [ -z "$2" ] || MQCFG=$2
    _pri_mqcfg=1
    shift 2
    ;;
  --broker)
    [ -z "$2" ] || MQCFG=$2
    [ "${_pri_svc}" = "help" ] || _pri_svc=broker
    shift 2
    ;;
  --sub)
    [ -z "$2" ] || MQTOPIC=$2
    [ "${_pri_svc}" = "help" ] || _pri_svc=sub
    shift 2
    ;;
  --pub)
    [ -z "$2" ] || MQMSG=$2
    [ "${_pri_svc}" = "help" ] || _pri_svc=pub
    shift 2
    ;;
  -t|--topic)
    MQTOPIC=$2
    shift 2
    ;;
  -m|--message)
    MQMSG=$2
    shift 2
    ;;
  --)
    shift
    break
    ;;
  *)
    echo "Invalid argument $1"
    exit 1
    ;;
  esac
done

if [ -z "$(echo ${_pri_svc} ${_pri_gencrt} ${_pri_mqcfg})" ] || [ "${_pri_svc}" = "help" ]; then
  svc_help
  exit 1
fi
 
[ -z "${_pri_gencrt}" ] || gen_crt
[ -z "${_pri_mqcfg}" ] || gen_mqcfg
[ -z "${_pri_svc}" ] || eval "svc_${_pri_svc} $@"
