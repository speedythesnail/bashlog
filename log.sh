#!/bin/bash

set -uo pipefail

function _log_exception() {
	(
		BASHLOG_FILE=0
		BASHLOG_JSON=0
		BASHLOG_SYSLOG=0

		log 'error' "Logging Exception: ${*}"
	)
}

function log() {
	local __log_sh_script_name__=$(basename "$0")
	local date_format="${BASHLOG_DATE_FORMAT:-+%F %T}"
	local date="$(date "${date_format}")"
	local date_s="$(date "+%s")"

	local file="${BASHLOG_FILE:-0}"
	local file_path="${BASHLOG_FILE_PATH:-/tmp/${__log_sh_script_name__}.log}"

	local json="${BASHLOG_JSON:-0}"
	local json_path="${BASHLOG_JSON_PATH:-/tmp/${__log_sh_script_name__}.log.json}"

	local syslog="${BASHLOG_SYSLOG:-0}"
	local tag="${BASHLOG_SYSLOG_TAG:-${__log_sh_script_name__}}"
	local facility="${BASHLOG_SYSLOG_FACILITY:-local0}"
	local pid="$$"

	local level="$1"
	local upper="${level^^}" # Bash natively can set variable to uppercase instead of calling other methods
	local debug_level="${DEBUG:-0}"

	shift 1

	local line="${*}"

	# RFC 5424
	#
	# Numerical         Severity
	#   Code
	#
	#    0       Emergency: system is unusable
	#    1       Alert: action must be taken immediately
	#    2       Critical: critical conditions
	#    3       Error: error conditions
	#    4       Warning: warning conditions
	#    5       Notice: normal but significant condition
	#    6       Informational: informational messages
	#    7       Debug: debug-level messages

	local -A severities
	severities['DEBUG']=7
	severities['INFO']=6
	severities['NOTICE']=5 # Unused
	severities['WARN']=4
	severities['ERROR']=3
	severities['CRIT']=2  # Unused
	severities['ALERT']=1 # Unused
	severities['EMERG']=0 # Unused

	local severity="${severities[${upper}]:-3}"

	if [ "${debug_level}" -gt 0 ] || [ "${severity}" -lt 7 ]; then

		if [ "${syslog}" -eq 1 ]; then
			local syslog_line="${upper}: ${line}"

			logger \
				--id="${pid}" \
				-t "${tag}" \
				-p "${facility}.${severity}" \
				"${syslog_line}" ||
				_log_exception "logger --id=\"${pid}\" -t \"${tag}\" -p \"${facility}.${severity}\" \"${syslog_line}\""
		fi

		if [ "${file}" -eq 1 ]; then
			local file_line="${date} [${upper}] ${line}"
			echo -e "${file_line}" >>"${file_path}" ||
				_log_exception "echo -e \"${file_line}\" >> \"${file_path}\""
		fi

		if [ "${json}" -eq 1 ]; then
			# don't use printf anymore to speed up just a little
			local json_line="{\"timestamp\":\"${date_s}\",\"level\":\"${level}\",\"message\":\"${line}\"}"
			echo -e "${json_line}" >>"${json_path}" ||
				_log_exception "echo -e \"${json_line}\" >> \"${json_path}\""
		fi

	fi

	local -A colours
	colours['DEBUG']='\033[34m'  # Blue
	colours['INFO']='\033[32m'   # Green
	colours['NOTICE']=''         # Unused
	colours['WARN']='\033[33m'   # Yellow
	colours['ERROR']='\033[31m'  # Red
	colours['CRIT']=''           # Unused
	colours['ALERT']=''          # Unused
	colours['EMERG']=''          # Unused
	colours['DEFAULT']='\033[0m' # Default

	local norm="${colours['DEFAULT']}"
	local colour="${colours[${upper}]:-\033[31m}"

	local std_line="${colour}${date} [${upper}] ${line}${norm}"

	# Standard Output (Pretty)
	case "${level}" in
		'info' | 'warn')
			echo -e "${std_line}"
			;;
		'debug')
			if [ "${debug_level}" -gt 0 ]; then
				echo -e "${std_line}"
			fi
			;;
		'error')
			echo -e "${std_line}" >&2
			if [ "${debug_level}" -gt 0 ]; then
				echo -e "Here's a shell to debug with. 'exit 0' to continue. Other exit codes will abort - parent shell will terminate."
				bash || exit "${?}"
			fi
			;;
		*)
			log 'error' "Undefined log level trying to log: ${*}"
			;;
	esac
}

# shellcheck disable=SC2034
declare prev_cmd="null"
declare this_cmd="null"
trap 'prev_cmd=$this_cmd; this_cmd=$BASH_COMMAND' DEBUG &&
	log debug 'DEBUG trap set' ||
	log error 'DEBUG trap failed to set'

# This is an option if you want to log every single command executed,
# but it will significantly impact script performance and unit tests will fail

#trap 'prev_cmd=$this_cmd; this_cmd=$BASH_COMMAND; log debug $this_cmd' DEBUG \
#  && log debug 'DEBUG trap set' \
#  || log error 'DEBUG trap failed to set';
