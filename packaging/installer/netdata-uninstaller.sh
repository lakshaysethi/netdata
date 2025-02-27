#!/bin/sh
#
# This is the netdata uninstaller script
#
# Variables needed by script and taken from '.environment' file:
#  - NETDATA_PREFIX
#  - NETDATA_ADDED_TO_GROUPS
#
# Copyright: SPDX-License-Identifier: GPL-3.0-or-later
#
# Author: Paweł Krupa <paulfantom@gmail.com>
# Author: Pavlos Emm. Katsoulakis <paul@netdata.cloud>

usage="$(basename "$0") [-h] [-f ] -- program to calculate the answer to life, the universe and everything

where:
    -e, --env    path to environment file (defaults to '/etc/netdata/.environment'
    -f, --force  force uninstallation and do not ask any questions
    -h           show this help text
    -y, --yes    flag needs to be set to proceed with uninstallation"

FILE_REMOVAL_STATUS=0
ENVIRONMENT_FILE="/etc/netdata/.environment"
# shellcheck disable=SC2034
INTERACTIVITY="-i"
YES=0
while :; do
  case "$1" in
    -h | --help)
      echo "$usage" >&2
      exit 1
      ;;
    -f | --force)
      INTERACTIVITY="-f"
      shift
      ;;
    -y | --yes)
      YES=1
      FLAG=-y
      shift
      ;;
    -e | --env)
      ENVIRONMENT_FILE="$2"
      shift 2
      ;;
    -*)
      echo "$usage" >&2
      exit 1
      ;;
    *) break ;;
  esac
done

if [ "$YES" != "1" ]; then
  echo >&2 "This script will REMOVE netdata from your system."
  echo >&2 "Run it again with --yes to do it."
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  echo >&2 "This script SHOULD be run as root or otherwise it won't delete all installed components."
  key="n"
  read -r 1 -p "Do you want to continue as non-root user [y/n] ? " key
  if [ "$key" != "y" ] && [ "$key" != "Y" ]; then
    exit 1
  fi
fi

user_input() {
  if [ "${INTERACTIVITY}" = "-i" ]; then
    TEXT="$1 [y/n]"

    while true; do
      echo "$TEXT"
      read -r yn

      case "$yn" in
         [Yy]*) return 0;;
         [Nn]*) return 1;;
         *) echo "Please answer yes or no.";;
       esac
     done
  fi
}

if [ -x "$(command -v apt-get)" ]; then
  if dpkg -s netdata > /dev/null; then
    echo "Found netdata native installation"
    if user_input "Do you want to remove netdata? "; then
      apt-get remove netdata ${FLAG}
    fi
    if dpkg -s netdata-repo-edge > /dev/null; then
      if user_input "Do you want to remove netdata-repo-edge? "; then
        apt-get remove netdata-repo-edge ${FLAG}
      fi
    fi
    if dpkg -s netdata-repo > /dev/null; then
      if user_input "Do you want to remove netdata-repo? "; then
        apt-get remove netdata-repo ${FLAG}
      fi
    fi
    exit 0
  fi
elif [ -x "$(command -v dnf)" ]; then
  if rpm -q netdata > /dev/null; then
    echo "Found netdata native installation."
    if user_input "Do you want to remove netdata? "; then
      dnf remove netdata ${FLAG}
    fi
    if rpm -q netdata-repo-edge > /dev/null; then
      if user_input "Do you want to remove netdata-repo-edge? "; then
        dnf remove netdata-repo-edge ${FLAG}
      fi
    fi
    if rpm -q netdata-repo > /dev/null; then
      if user_input "Do you want to remove netdata-repo? "; then
        dnf remove netdata-repo ${FLAG}
      fi
    fi
    exit 0
  fi
elif [ -x "$(command -v yum)" ]; then
  if rpm -q netdata > /dev/null; then
    echo "Found netdata native installation."
    if user_input "Do you want to remove netdata? "; then
      yum remove netdata ${FLAG}
    fi
    if rpm -q netdata-repo-edge > /dev/null; then
      if user_input "Do you want to remove netdata-repo-edge? "; then
        yum remove netdata-repo-edge ${FLAG}
      fi
    fi
    if rpm -q netdata-repo > /dev/null; then
      if user_input "Do you want to remove netdata-repo? "; then
        yum remove netdata-repo ${FLAG}
      fi
    fi
    exit 0
  fi
elif [ -x "$(command -v zypper)" ]; then
  if [ "${FLAG}" = "-y" ]; then
    FLAG=-n
  fi
  if zypper search -i netdata > /dev/null; then
    echo "Found netdata native installation."
    if user_input "Do you want to remove netdata? "; then
      zypper ${FLAG} remove netdata
    fi
    if zypper search -i netdata-repo-edge > /dev/null; then
      if user_input "Do you want to remove netdata-repo-edge? "; then
        zypper ${FLAG} remove netdata-repo-edge
      fi
    fi
    if zypper search -i netdata-repo > /dev/null; then
      if user_input "Do you want to remove netdata-repo? "; then
        zypper ${FLAG} remove netdata-repo
      fi
    fi
    exit 0
  fi
fi

# -----------------------------------------------------------------------------
# portable service command

service_cmd="$(command -v service 2> /dev/null)"
rcservice_cmd="$(command -v rc-service 2> /dev/null)"
systemctl_cmd="$(command -v systemctl 2> /dev/null)"
service() {

  cmd="${1}"
  action="${2}"

  if [ -n "${systemctl_cmd}" ]; then
    run "${systemctl_cmd}" "${action}" "${cmd}"
    return $?
  elif [ -n "${service_cmd}" ]; then
    run "${service_cmd}" "${cmd}" "${action}"
    return $?
  elif [ -n "${rcservice_cmd}" ]; then
    run "${rcservice_cmd}" "${cmd}" "${action}"
    return $?
  fi
  return 1
}

# -----------------------------------------------------------------------------

setup_terminal() {
  TPUT_RESET=""
  TPUT_YELLOW=""
  TPUT_WHITE=""
  TPUT_BGRED=""
  TPUT_BGGREEN=""
  TPUT_BOLD=""
  TPUT_DIM=""

  # Is stderr on the terminal? If not, then fail
  test -t 2 || return 1

  if command -v tput 1> /dev/null 2>&1; then
    if [ $(($(tput colors 2> /dev/null))) -ge 8 ]; then
      # Enable colors
      TPUT_RESET="$(tput sgr 0)"
      TPUT_YELLOW="$(tput setaf 3)"
      TPUT_WHITE="$(tput setaf 7)"
      TPUT_BGRED="$(tput setab 1)"
      TPUT_BGGREEN="$(tput setab 2)"
      TPUT_BOLD="$(tput bold)"
      TPUT_DIM="$(tput dim)"
    fi
  fi

  return 0
}
setup_terminal || echo > /dev/null

run_ok() {
  printf >&2 "%s OK %s\n\n" "${TPUT_BGGREEN}${TPUT_WHITE}${TPUT_BOLD}" "${TPUT_RESET}"
}

run_failed() {
  printf >&2 "%s FAILED %s\n\n" "${TPUT_BGRED}${TPUT_WHITE}${TPUT_BOLD}" "${TPUT_RESET}"
}

ESCAPED_PRINT_METHOD=
if printf "%s " test > /dev/null 2>&1; then
  ESCAPED_PRINT_METHOD="printfq"
fi
escaped_print() {
  if [ "${ESCAPED_PRINT_METHOD}" = "printfq" ]; then
    printf "%s " "${@}"
  else
    printf "%s" "${*}"
  fi
  return 0
}

run_logfile="/dev/null"
run() {
  user="${USER--}"
  dir="${PWD}"

  if [ "$(id -u)" = "0" ]; then
    info="[root ${dir}]# "
    info_console="[${TPUT_DIM}${dir}${TPUT_RESET}]# "
  else
    info="[${user} ${dir}]$ "
    info_console="[${TPUT_DIM}${dir}${TPUT_RESET}]$ "
  fi

  {
    printf "%s" "${info}"
    escaped_print "${@}"
    printf "%s" " ... "
  } >> "${run_logfile}"

  printf "%s" "${info_console}${TPUT_BOLD}${TPUT_YELLOW}" >&2
  escaped_print >&2 "${@}"
  printf "%s\n" "${TPUT_RESET}" >&2

  "${@}"

  ret=$?
  if [ ${ret} -ne 0 ]; then
    run_failed
    printf >> "${run_logfile}" "FAILED with exit code %s\n" "${ret}"
  else
    run_ok
    printf >> "${run_logfile}" "OK\n"
  fi

  return ${ret}
}

portable_del_group() {
  groupname="${1}"

  # Check if group exist
  echo >&2 "Removing ${groupname} user group ..."

  # Linux
  if command -v groupdel 1> /dev/null 2>&1; then
    if grep -q "${groupname}" /etc/group; then
      run groupdel "${groupname}" && return 0
    else
      echo >&2 "Group ${groupname} already removed in a previous step."
      return 0
    fi
  fi

  # mac OS
  if command -v dseditgroup 1> /dev/null 2>&1; then
    if dseditgroup -o read netdata 1> /dev/null 2>&1; then
      run dseditgroup -o delete "${groupname}" && return 0
    else
      echo >&2 "Could not find group ${groupname}, nothing to do"
      return 0
    fi
  fi

  echo >&2 "Group ${groupname} was not automatically removed, you might have to remove it manually"
  return 1
}

issystemd() {
  pids=''
  p=''
  myns=''
  ns=''
  systemctl=''

  # if the directory /lib/systemd/system OR /usr/lib/systemd/system (SLES 12.x) does not exit, it is not systemd
  if [ ! -d /lib/systemd/system ] && [ ! -d /usr/lib/systemd/system ]; then
    return 1
  fi

  # if there is no systemctl command, it is not systemd
  systemctl=$(command -v systemctl 2> /dev/null)
  if [ -z "${systemctl}" ] || [ ! -x "${systemctl}" ]; then
    return 1
  fi

  # if pid 1 is systemd, it is systemd
  [ "$(basename "$(readlink /proc/1/exe)" 2> /dev/null)" = "systemd" ] && return 0

  # if systemd is not running, it is not systemd
  pids=$(safe_pidof systemd 2> /dev/null)
  [ -z "${pids}" ] && return 1

  # check if the running systemd processes are not in our namespace
  myns="$(readlink /proc/self/ns/pid 2> /dev/null)"
  for p in ${pids}; do
    ns="$(readlink "/proc/${p}/ns/pid" 2> /dev/null)"

    # if pid of systemd is in our namespace, it is systemd
    [ -n "${myns}" ] && [ "${myns}" = "${ns}" ] && return 0
  done

  # else, it is not systemd
  return 1
}

portable_del_user() {
  username="${1}"
  echo >&2 "Deleting ${username} user account ..."

  # Linux
  if command -v userdel 1> /dev/null 2>&1; then
    run userdel -f "${username}" && return 0
  fi

  # mac OS
  if command -v sysadminctl 1> /dev/null 2>&1; then
    run sysadminctl -deleteUser "${username}" && return 0
  fi

  echo >&2 "User ${username} could not be deleted from system, you might have to remove it manually"
  return 1
}

portable_del_user_from_group() {
  groupname="${1}"
  username="${2}"

  # username is not in group
  echo >&2 "Deleting ${username} user from ${groupname} group ..."

  # Linux
  if command -v gpasswd 1> /dev/null 2>&1; then
    run gpasswd -d "netdata" "${group}" && return 0
  fi

  # FreeBSD
  if command -v pw 1> /dev/null 2>&1; then
    run pw groupmod "${groupname}" -d "${username}" && return 0
  fi

  # BusyBox
  if command -v delgroup 1> /dev/null 2>&1; then
    run delgroup "${username}" "${groupname}" && return 0
  fi

  # mac OS
  if command -v dseditgroup 1> /dev/null 2>&1; then
    run dseditgroup -o delete -u "${username}" "${groupname}" && return 0
  fi

  echo >&2 "Failed to delete user ${username} from group ${groupname} !"
  return 1
}

quit_msg() {
  echo
  if [ "$FILE_REMOVAL_STATUS" -eq 0 ]; then
    echo >&2 "Something went wrong :("
  else
    echo >&2 "Netdata files were successfully removed from your system"
  fi
}

rm_file() {
  FILE="$1"
  if [ -f "${FILE}" ]; then
    if user_input "Do you want to delete this file '$FILE' ? "; then
	  run rm -v "${FILE}"
    fi
  fi
}

rm_dir() {
  DIR="$1"
  if [ -n "$DIR" ] && [ -d "$DIR" ]; then
    if user_input "Do you want to delete this directory '$DIR' ? "; then
      run rm -v -f -R "${DIR}"
    fi
  fi
}

safe_pidof() {
  pidof_cmd="$(command -v pidof 2> /dev/null)"
  if [ -n "${pidof_cmd}" ]; then
    ${pidof_cmd} "${@}"
    return $?
  else
    ps -acxo pid,comm |
      sed "s/^ *//g" |
      grep netdata |
      cut -d ' ' -f 1
    return $?
  fi
}

pidisnetdata() {
  if [ -d /proc/self ]; then
    if [ -z "$1" ] || [ ! -f "/proc/$1/stat" ]; then
      return 1
    fi
    [ "$(cut -d '(' -f 2 "/proc/$1/stat" | cut -d ')' -f 1)" = "netdata" ] && return 0
    return 1
  fi
  return 0
}

stop_netdata_on_pid() {
  pid="${1}"
  ret=0
  count=0

  pidisnetdata "${pid}" || return 0

  printf >&2 "Stopping netdata on pid %s ..." "${pid}"
  while [ -n "$pid" ] && [ ${ret} -eq 0 ]; do
    if [ ${count} -gt 24 ]; then
      echo >&2 "Cannot stop the running netdata on pid ${pid}."
      return 1
    fi

    count=$((count + 1))

    pidisnetdata "${pid}" || ret=1
    if [ ${ret} -eq 1 ]; then
      break
    fi

    if [ ${count} -lt 12 ]; then
      run kill "${pid}" 2> /dev/null
      ret=$?
    else
      run kill -9 "${pid}" 2> /dev/null
      ret=$?
    fi

    test ${ret} -eq 0 && printf >&2 "." && sleep 5

  done

  echo >&2
  if [ ${ret} -eq 0 ]; then
    echo >&2 "SORRY! CANNOT STOP netdata ON PID ${pid} !"
    return 1
  fi

  echo >&2 "netdata on pid ${pid} stopped."
  return 0
}

netdata_pids() {
  p=''
  ns=''

  myns="$(readlink /proc/self/ns/pid 2> /dev/null)"

  for p in \
    $(cat /var/run/netdata.pid 2> /dev/null) \
    $(cat /var/run/netdata/netdata.pid 2> /dev/null) \
    $(safe_pidof netdata 2> /dev/null); do
    ns="$(readlink "/proc/${p}/ns/pid" 2> /dev/null)"

    if [ -z "${myns}" ] || [ -z "${ns}" ] || [ "${myns}" = "${ns}" ]; then
      pidisnetdata "${p}" && echo "${p}"
    fi
  done
}

stop_all_netdata() {
  p=''

  if [ "$(id -u)" -eq 0 ]; then
    uname="$(uname 2> /dev/null)"

    # Any of these may fail, but we need to not bail if they do.
    if issystemd; then
      if systemctl stop netdata; then
        sleep 5
      fi
    elif [ "${uname}" = "Darwin" ]; then
      if launchctl stop netdata; then
        sleep 5
      fi
    elif [ "${uname}" = "FreeBSD" ]; then
      if /etc/rc.d/netdata stop; then
        sleep 5
      fi
    else
      if service netdata stop; then
        sleep 5
      fi
    fi
  fi

  if [ -n "$(netdata_pids)" ] && [ -n "$(command -v netdatacli)" ]; then
    netdatacli shutdown-agent
    sleep 20
  fi

  for p in $(netdata_pids); do
    # shellcheck disable=SC2086
    stop_netdata_on_pid ${p}
  done
}

trap quit_msg EXIT

# shellcheck source=/dev/null
# shellcheck disable=SC1090
. "${ENVIRONMENT_FILE}" || exit 1

#### STOP NETDATA
echo >&2 "Stopping a possibly running netdata..."
stop_all_netdata

#### REMOVE NETDATA FILES
rm_file /etc/logrotate.d/netdata
rm_file /etc/systemd/system/netdata.service
rm_file /lib/systemd/system/netdata.service
rm_file /usr/lib/systemd/system/netdata.service
rm_file /etc/systemd/system/netdata-updater.service
rm_file /lib/systemd/system/netdata-updater.service
rm_file /usr/lib/systemd/system/netdata-updater.service
rm_file /etc/systemd/system/netdata-updater.timer
rm_file /lib/systemd/system/netdata-updater.timer
rm_file /usr/lib/systemd/system/netdata-updater.timer
rm_file /etc/init.d/netdata
rm_file /etc/periodic/daily/netdata-updater
rm_file /etc/cron.daily/netdata-updater
rm_file /etc/cron.d/netdata-updater


if [ -n "${NETDATA_PREFIX}" ] && [ -d "${NETDATA_PREFIX}" ]; then
  rm_dir "${NETDATA_PREFIX}"
else
  rm_file "/usr/sbin/netdata"
  rm_file "/usr/sbin/netdatacli"
  rm_file "/tmp/netdata-ipc"
  rm_file "/usr/sbin/netdata-claim.sh"
  rm_dir "/usr/share/netdata"
  rm_dir "/usr/libexec/netdata"
  rm_dir "/var/lib/netdata"
  rm_dir "/var/cache/netdata"
  rm_dir "/var/log/netdata"
  rm_dir "/etc/netdata"
fi

FILE_REMOVAL_STATUS=1

#### REMOVE NETDATA USER FROM ADDED GROUPS
if [ -n "$NETDATA_ADDED_TO_GROUPS" ]; then
  if user_input "Do you want to delete 'netdata' from following groups: '$NETDATA_ADDED_TO_GROUPS' ? "; then
    for group in $NETDATA_ADDED_TO_GROUPS; do
      portable_del_user_from_group "${group}" "netdata"
    done
  fi
fi

#### REMOVE USER
if user_input "Do you want to delete 'netdata' system user ? "; then
  portable_del_user "netdata" || :
fi

### REMOVE GROUP
if user_input "Do you want to delete 'netdata' system group ? "; then
  portable_del_group "netdata" || :
fi
