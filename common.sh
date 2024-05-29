#!/usr/bin/env bash
# -*- tab-width: 4; encoding: utf-8 -*-

###################
## DEBUG OPTIONS ##
###################
#set -o errexit         # Exit on most errors (see the manual)
#set -e                 # Exit on most errors (see the manual)
#set -o errtrace        # Make sure any error trap is inherited
#set -o nounset         # Disallow expansion of unset variables
#set -u                 # Disallow expansion of unset variables
#set -o pipefail        # Use last non-zero exit code in a pipeline
#set -o xtrace          # Print command traces before executing command (debug)
#set -x                 # Print command traces before executing command (debug)
#set -v                 # Display shell input lines as they are read.
#set -eux

function __init__() {
    #if [[ "$LOG_ENABLED" = "y" ]] || [[ "$LOG_ENABLED" = "yes" ]]; then
    #  mkdir -p "$LOG_DIR" &>/dev/null
    #  [[ -f "${LOG_FILE}" ]] && rm -f "${LOG_FILE}"  # Si existe un fichero de log previo, lo borra
    #fi
    if is_enabled $LOG_ENABLED; then
      mkdir -p "$LOG_DIR" &>/dev/null
      [[ -f "${LOG_FILE}" ]] && rm -f "${LOG_FILE}"  # Si existe un fichero de log previo, lo borra
    fi

    #[[ file_exists $LOCKFILE ]] && rm -f $LOCKFILE
    #touch LOCK_FILE
    #[[ -f $PKG_FAIL ]] && rm -f $PKG_FAIL # Si existe un fichero de paquetes de instalación con error previo, lo borra
}
function __debug__() {
  # Will exit script if we would use an uninitialised variable:
  set -o nounset
  # Will exit script when a simple command (not a control structure) fails:
  set -o errexit
}

# By Martin Burger
# Should be called at the beginning of every shell script.
#
# Exits your script if you try to use an uninitialised variable and exits your
# script as soon as any statement fails to prevent errors snowballing into
# serious issues.
#
# Example:
# init
#
# See: http://www.davidpashley.com/articles/writing-robust-shell-scripts/
#
function init_ { #private: Should be called at the beginning of every shell script.
  # Will exit script if we would use an uninitialised variable:
  set -o nounset
  # Will exit script when a simple command (not a control structure) fails:
  set -o errexit
}


function _quick_help() {
  echo "Private functions of script:"
  echo ""
  LANG=es_ES.UTF_8
  #grep -E '^_.+ #public' "$0" \
  grep -E '^function _.+ #private' "$0" \
  | sed -e 's|function ||g' \
  | sed -e 's|() { #private: |☠|g' \
  | column -s"☠" -t \
  | sort
  echo ""
  echo "Public functions of script:"
  echo ""
  LANG=es_ES.UTF_8
  #grep -E '^_.+ #public' "$0" \
  grep -E '^function .+ #public' "$0" \
  | sed -e 's|function ||g' \
  | sed -e 's|() { #public: |☠|g' \
  | column -s"☠" -t \
  | sort
}

########################
## VARIABLE FUNCTIONS ##
########################

## Check if a variable is defined, not empty, has value
function is_defined() {
    local var=$1
    [[ -n $var ]]
}
## Check if a variable is not defined, empty, has no value
function is_not_defined() {
    local var=$1
    [[ -z $var ]]
}

## Check if a variable is empty, not defined, has no value
function is_empty() {
    local var=$1
    is_not_defined $var
}
## Check if a variable is not empty, is defined, has value
function is_not_empty() {
    local var=$1
    is_defined $var
}

## Tests if a variable has value, is not empty, defined
function has_value() {
    local var=$1
    is_defined $var
}

## Check if a variable has no value, empty, is not defined
function has_no_value() {
    local var=$1
    is_not_defined $var
}

## Check if a variable value is "y" or "yes"
function is_enabled() {
    local var="$1"
    if is_defined $var; then
      [[ $var = "y" ]] || [[ $var = "yes" ]]
    fi
}

## Check if a function is defined
function function_defined() {
    local func_name=$1
    [[ $(type -t $func_name) == function ]]
}

## Check if a function is not defined
function function_not_defined() {
    local func_name=$1
    [[ $(type -t $func_name) != function ]]
}

##########################
## EXIT/ERROR FUNCTIONS ##
##########################

# By Martin Burger
# Writes the given messages in red letters to standard error and exits with # error code 1.
# Example:
# cmn_die "An error occurred."
function cmn_die() { #private: Writes the given messages in red letters to standard error and exits with # error code 1.
  local red=$(tput setaf 1)
  local reset=$(tput sgr0)
  echo >&2 -e "${red}$@${reset}"
  exit 1
}

function die() {
    echo -e "${MSG_ERR} ${1} ${RESET}" >&2
    log_error "${1}"
    exit 1
}

## Prints an error message to stderr and exits
## with the error code given as parameter. The message
## is also logged.
## @param errcode Error code.
## @param errmsg Error message.
function _die() {
    local -r err_code="$1"
    local -r err_msg="$2"
    local -r err_caller="${3:-$(caller 0)}"

    msg_failed "ERROR: $err_msg"
    msg_failed "ERROR: At line $err_caller"
    msg_failed "ERROR: Error code = $err_code"
    exit "$err_code"
} >&2 # function writes to stderr

## Displays an error message and exits if the previous
## command has failed (if its error code is not '0').
## @param errcode Error code.
## @param errmsg Error message.
function die_if_false() {
    local -r err_code=$1
    local -r err_msg=$2
    local -r err_caller=$(caller 0)

    if [[ "$err_code" != "0" ]]; then
        die "$err_code" "$err_msg" "$err_caller"
    fi
} >&2 # function writes to stderr

## Displays an error message and exits if the previous
## command has succeeded (if its error code is '0').
## @param errcode Error code.
## @param errmsg Error message.
function die_if_true() {
    local -r err_code=$1
    local -r err_msg=$2
    local -r err_caller=$(caller 0)

    if [[ "$err_code" == "0" ]]; then
        die "$err_code" "$err_msg" "$err_caller"
    fi
} >&2 # function writes to stderr

###################
## LOG FUNCTIONS ##
###################

## Private function for logging
## Writes message to log file / syslog.
function __log__() { #private: Writes message to log file / syslog
    check_args_len 2 ${#}

    if is_enabled $LOG_ENABLED || is_enabled $SYSLOG_ENABLED; then
        local log_level="$1"
        local log_msg="$2"
        local log_date=$(date +"$LOG_DATEFORMAT")

        if is_enabled $LOG_ENABLED; then
            # tee siempre va a mostrar la salida en pantalla y meterla en el fichero
            #echo -e "$log_date $log_level- $log_msg" | tee -a "$LOG_FILE"
            echo -e "$log_date $log_level - $log_msg" >> "$LOG_FILE"
        fi

        if is_enabled $SYSLOG_ENABLED; then
          # we only syslog debug, warning, error and fatal levels
          case $log_level in
              debug | warning | error | fatal )
                  # Syslog already prepends a date/time stamp so only the message is logged.
                  logger -t "$SYSLOG_TAG" "$log_level - $log_msg"
                  ;;
              * )
                  ;;
          esac
        fi
    fi
}


## Public functions for logging
function log_debug() {
    __log__ debug "${*}"
}
function log_info() {
    __log__ info "${*}"
}
function log_success() {
    __log__ info "${*}"
}
function log_warning() {
    __log__ warning "${*}"
}
function log_failed() {
    __log__ warning "${*}"
}
function log_error() {
    __log__ error "${*}"
}
function log_error() {
    __log__ fatal "${*}"
}


#################################################
## MESSAGE FUNCTIONS (I/O INTERFACE FUNCTIONS) ##
#################################################

#function msg_error__() { echo -e " ${BRED}✖ $@${RESET}" 1>&2; exit 1; }

# Private function for displaying messages
function __msg__() {

    function set_cursor_position() {
        RES_COL="$(($(tput cols)-13))"
        tput cuf $RES_COL
        tput cuu1
    }

    local msg_type="$1"
    local msg_text="$2"
    local msg_color=""
    local msg_startstatus=""
    local msg_endstatus=""
    local logfun

#     if [[ $# = 2 ]]; then
#       msg_type="$2"
#     fi

#     if [[ $# = 3 ]]; then
#       _msgcolor="$3"
#     fi

    case $msg_type in
        debug )
            msg_start="${MSG_WARNING}"
            msg_end="   DEBUG   "
            msg_color="$BOLD$YELLOW"
            ;;
        error )
            msg_start="${MSG_ERROR}"
            msg_end="   ERROR   "
            msg_color="$BOLD$RED"
            ;;
        failed )
            #msg_text=$msg_text + ">&2"
            msg_start="${MSG_ERROR}"
            msg_end="   FAILED  "
            msg_color="$BOLD$RED"
            ;;
        info )
            msg_start="${MSG_INFO}"
            msg_end="    INFO   "
            msg_color="$BOLD$BLUE"
            ;;
        success )
            msg_start="${MSG_SUCCESS}"
            msg_end="  SUCCESS  "
            msg_color="$BOLD$GREEN"
            ;;
        warning )
            msg_start="${MSG_WARNING}"
            msg_end="  WARNING  "
            msg_color="$BOLD$YELLOW"
            ;;
        question )
            msg_start="${MSG_QUESTION}"
            msg_end=""
            msg_type=""
            ;;
        *)
            if ! has_value $msg_color; then
                msg_color="$DEFAULT"
            fi
            msg_start="${msg_color}"
            msg_end=""
            msg_type=""
    esac

    if has_value "$msg_text"; then
        if [[ $msg_type == "error" ]]; then
            #die, necho, log_error
            echo -e "$msg_start $msg_text$RESET" 1>&2
            exit 1
        else
            necho "$msg_start $msg_text$RESET"
        fi
        if has_value "$msg_type"; then
          # Repeat char from msg to status position
          RES_COL="$(($(tput cols)-22))"
          local msg_length=$(echo ${#msg_text})
          local numchars=$(($RES_COL - $msg_length))
          tput cuf $(($msg_length + 8))
          tput cuu1
          printf "$msg_color%${numchars}s" | tr " " "." && echo ""
          # End repeat code

          # Display status at end of line
          #__print_status "$type"
          set_cursor_position
          echo -n "["
          echo -n "$msg_color$msg_end"
          echo -n "]${RESET}"
        fi
    fi
}


# print_header()  { echo -e "\n${BCyan}[▪] $@${Reset}\n"; }
# #msg_error() { echo -e " ${BRed}✖ $@${Reset}" 1>&2; }
# msg_error() { echo -e " ${BRed}✖ $@${Reset}" 1>&2; exit 1; }
# msg_info()    { echo -e " ${BWhite}➜ $@${Reset}"; }
# msg_success() { echo -e " ${BGreen}✔ $@${Reset}"; }
# msg_warning()    { echo -e " ${BYellow}! $@${Reset}"; }
# msg_danger() { echo -e " ${BRed}✖ $@${Reset}" 1>&2; }

## Public functions for displaying messages
function msg_error() {
    __msg__ error "${1}"
    log_error "${1}"
}
function msg_warning() {
    __msg__ warning "${1}"
    log_warning "${1}"
}
function msg_info() {
    __msg__ info "${1}"
    log_info "${1}"
}
function msg_debug() {
    __msg__ debug "${1}"
    log_debug "${1}"
}
function msg_failed() {
    __msg__ failed "${1}"
    log_failed "${1}"
}
function msg_success() {
    __msg__ success "${1}"
    log_success "${1}"
}
function msg_question() {
    __msg__ question "${1}"
}
function msg() {
    [[ $# = 1 ]] && msg_info "${1}" # if only 1 argument show message
    #[[ $# = 2 ]] && msg_info "${1}" "${2}" # if 2 arguments show message with color
}

## Private function to print headers, titles, etc.
function __print__() {
    check_args_len 2 ${#}
    #local type=$(echo -e $%1 | tr '[:upper:]' '[:lower:]')
    local type="$1"
    local text="$2"
    # Terminal number of columns (width)
    local num_cols=$(tput cols)

    case $type in
        title)
            local text=$(str_to_upper "$text")
            local tlen=${#text} # the number of characthers of text
            local ncol=$(tput cols)
            local head=$(( ( tlen + ncol - 1 ) / 2 ))
            local tail=$(( ( ncol - tlen ) / 2 ))
            printf "\n${BBLUE}%$(tput cols)s\n${RESET}"|tr ' ' '#' >&2
            echo -n $BBLUE
            printf "#%*s" ${head} "${text}" >&2
            printf "%*s\n" ${tail} "#" >&2
            echo -n $RESET
            printf "${BBLUE}%$(tput cols)s\n${RESET}"|tr ' ' '#' >&2
            echo ""
            ;;
        titleold)
            text=$(str_to_upper "$text")
            #printf "\n${BOLD}${BLUE}%$(tput cols)s\n${RESET}"|tr ' ' '-' >&2
            printf "\n${BBLUE}%$(tput cols)s\n${RESET}"|tr ' ' '#' >&2
            printf "${MSG_TITLE}${text}${RESET}" >&2
            # We position cursor at end line char and print a # for middle line
            tput cuf $(($(tput cols)-1))
            printf "${BBLUE}#"
            #printf "${BOLD}${BLUE}%$(tput cols)s\n${RESET}"|tr ' ' '-' >&2
            printf "${BBLUE}%$(tput cols)s\n${RESET}"|tr ' ' '#' >&2
            printf "\n" >&2
            ;;
        subtitle)
            local tlen=${#text} # the number of characthers of text
            local ncol=$(tput cols)
            local head=$(( ( tlen + ncol - 1 ) / 2 ))
            local tail=$(( ( ncol - tlen ) / 2 ))
            #local tail=$(( $tail + 1 ))
            printf "\n${BBLUE}%$(tput cols)s\n${RESET}"|tr ' ' '-' >&2
            echo -n $BBLUE
            printf "|%*s" ${head} "${text}" >&2
            printf "%*s\n" ${tail} "|" >&2
            echo -n $RESET
            printf "${BBLUE}%$(tput cols)s\n${RESET}"|tr ' ' '-' >&2
            echo ""
            ;;
        header)
            text=$(str_to_upper "$text")
            echo ""
            echo -e "${BBLUE} [ ${UNDERLINE}${BBLUE}${text}${RESET}${BBLUE} ]${RESET}\n" >&2
            echo ""
            ;;
        section)
            echo ""
            echo -e "${BBLUE} [ ▪ ] ${text}${RESET}" >&2
            echo ""
            ;;
        line)
            echo ""
            printf "${BBLUE}%$(tput cols)s\n" | tr ' ' "${text}" >&2
            echo ""
            ;;
        blank)
            echo ""
            ;;
        done)
            local tlen=${#text} # the number of characthers of text
            local ncol=$(tput cols)
            local head=$(( ( tlen + ncol - 1 ) / 2 ))
            local tail=$(( ( ncol - tlen ) / 2 ))
            echo ""
            printf "\n${BGREEN}%$(tput cols)s\n${RESET}"|tr ' ' '#' >&2
            echo -n $BGREEN
            printf "#%*s" ${head} "${text}" >&2
            printf "%*s\n" ${tail} "#" >&2
            echo -n $RESET
            printf "${BGREEN}%$(tput cols)s\n${RESET}"|tr ' ' '#' >&2
            echo ""
            ;;
    esac
}

## Public functions to print titles, headers, lines, etc.
## Prints a title
function print_title() {
    check_args_len 1 ${#}
    __print__ "title" "$1"
}
function print_subtitle() {
    check_args_len 1 ${#}
    __print__ "subtitle" "$1"
}
## Prints a header
function print_header() {
    check_args_len 1 ${#}
    __print__ header "$1"
}
function print_section() {
    check_args_len 1 ${#}
    __print__ section "$1"
}
## Prints a line
function print_line() {
    local linechar="-" #default
    if [[ ${#} -eq 1 ]]; then
        linechar="$1"
    fi
    __print__ line "$linechar"
}
function blank_line() {
    __print__ blank "blank"
}
function print_done() {
    __print__ done "D O N E"
}
# Custom ECHO - INLINE, NO NEW LINE AFTER
function iecho() {
    echo -ne "$1"
    log_info "$1"
    tput sgr0
}
# Custom ECHO - NEW LINE AFTER
function necho() {
    echo -e "$1"
    log_info "$1"
    tput sgr0
}

### PRINTING TO THE SCREEN by Martin Burger ###

# Writes the given messages in green letters to standard output.
# Example:
# echo_info "Task completed."
function echo_info() { #public: Writes the given messages in green letters to standard output.
  local green=$(tput setaf 2)
  local reset=$(tput sgr0)
  echo -e "${green}$@${reset}"
}

# Writes the given messages in yellow letters to standard output.
# Example:
# echo_important "Please complete the following task manually."
function echo_important() { #public: Writes the given messages in yellow letters to standard output.
  local yellow=$(tput setaf 3)
  local reset=$(tput sgr0)
  echo -e "${yellow}$@${reset}"
}

# Writes the given messages in red letters to standard output.
# Example:
# echo_warn "There was a failure."
function echo_warn() { #public: Writes the given messages in red letters to standard output.
  local red=$(tput setaf 1)
  local reset=$(tput sgr0)
  echo -e "${red}$@${reset}"
}

# # OLD VERSIONS
# function cecho() {
# 	echo -e "$1"
# 	echo -e "$1" >> $LOG_FILE
# 	tput sgr0
# }
#
# function ncecho() {
# 	# -n Do not append a new line.
# 	echo -ne "$1"
# 	echo -ne "$1" >> $LOG_FILE
# 	tput sgr0
# }

## Input functions
function presskey() {
    echo -ne "\n ${PAUSE}"
    read -sn 1
    echo ""
}

function read_text() {
    printf "\n%s" " $1: "
    read -r OPTION
}

function read_pwd() {
    local _prompt="Password: "
	read -s -p " ${_prompt}" OPTION
}

function read_option() {
	printf "\n%s" "${MSG_QUESTION} ${1}? [y/N]${RESET} "
	read -r OPTION
	OPTION=$(echo "$OPTION" | tr '[:upper:]' '[:lower:]')
}

function read_option_() {
	read -p "${MSG_QUESTION} $1 [s/N]: ${RESET}" OPTION
	OPTION=`echo " $OPTION"| tr '[:upper:]' '[:lower:]'`
}

function confirm() {
    #Comprobar si paso pregunta, sino por defecto: ¿Está seguro? [s/N]
    #read -r -p "${1:-Are you sure? [y/N]} " response
    read -r -p " ${MSG_QUESTION} ${1}? [y/N]${RESET} " response
    case "$response" in
        [yY][eE][sS]|[yY])
            true
            ;;
        *)
            false
            ;;
    esac
}

# $1 : message
# $2 : args
# Sample: if (confirm_gui "Delete $sel entry ?") then
#          	rm /boot/loader/entries/$sel.conf
#         fi
function confirm_gui(){
  whiptail --backtitle "$apptitle" --yesno "$1" "$2" 0 0
}

# Asks the user - using the given message - to either hit 'y/Y' to continue or 'n/N' to cancel the script.
#
# Example: cmn_ask_to_continue "Do you want to delete the given file?"
#
# On yes (y/Y), the function just returns; on no (n/N), it prints a confirmative
# message to the screen and exits with return code 1 by calling `cmn_die`.
#
function ask_to_continue() { #public: Asks the user - using the given message - to either hit 'y/Y' to continue or 'n/N' to cancel the script.
  local msg=${1}
  #local waitingforanswer=true
  #while ${waitingforanswer}; do
  while true; do
    read -p "${msg} (hit 'y/Y' to continue, 'n/N' to cancel) " -n 1 ynanswer
    case ${ynanswer} in
      [Yy] ) break;;
      #[Yy] ) waitingforanswer=false; break;;
      [Nn] ) echo ""; _die "Operation cancelled as requested!";;
      *    ) echo ""; echo "Please answer either yes (y/Y) or no (n/N).";;
    esac
  done
  echo ""
}

# By Martin Burger
# Asks the user for her password and stores the password in a read-only variable with the given name.
#
# The user is asked with the given message prompt. Note that the given prompt
# will be complemented with string ": ".
#
# This function does not echo nor completely hides the input but echos the
# asterisk symbol ('*') for each given character. Furthermore, it allows to
# delete any number of entered characters by hitting the backspace key. The
# input is concluded by hitting the enter key.
#
# Example:
# cmn_ask_for_password "THEPWD" "Please enter your password"
#
# See: http://stackoverflow.com/a/24600839/66981
#
function ask_for_password() { #public: Asks the user for her password and stores the password in a read-only variable with the given name.
  local VARIABLE_NAME=${1}
  local MESSAGE=${2}

  echo -n "${MESSAGE}: "
  stty -echo
  local CHARCOUNT=0
  local PROMPT=''
  local CHAR=''
  local PASSWORD=''
  while IFS= read -p "${PROMPT}" -r -s -n 1 CHAR
  do
    # Enter -> accept password
    if [[ ${CHAR} == $'\0' ]] ; then
      break
    fi
    # Backspace -> delete last char
    if [[ ${CHAR} == $'\177' ]] ; then
      if [ ${CHARCOUNT} -gt 0 ] ; then
        CHARCOUNT=$((CHARCOUNT-1))
        PROMPT=$'\b \b'
        PASSWORD="${PASSWORD%?}"
      else
        PROMPT=''
      fi
    # All other cases -> read last char
    else
      CHARCOUNT=$((CHARCOUNT+1))
      PROMPT='*'
      PASSWORD+="${CHAR}"
    fi
  done
  stty echo
  readonly ${VARIABLE_NAME}=${PASSWORD}
  echo
}

# By Martin Burger
# Asks the user for her password twice. If the two inputs match, the given
# password will be stored in a read-only variable with the given name;
# otherwise, it exits with return code 1 by calling `cmn_die`.
#
# The user is asked with the given message prompt. Note that the given prompt
# will be complemented with string ": " at the first time and with
# " (again): " at the second time.
#
# This function basically calls `cmn_ask_for_password` twice and compares the
# two given passwords. If they match, the password will be stored; otherwise,
# the functions exits by calling `cmn_die`.
#
# Example:
# cmn_ask_for_password_twice "THEPWD" "Please enter your password"
#
function ask_for_password_twice() { #public: Asks the user for her password twice.
  local VARIABLE_NAME=${1}
  local MESSAGE=${2}
  local VARIABLE_NAME_1="${VARIABLE_NAME}_1"
  local VARIABLE_NAME_2="${VARIABLE_NAME}_2"

  ask_for_password "${VARIABLE_NAME_1}" "${MESSAGE}"
  ask_for_password "${VARIABLE_NAME_2}" "${MESSAGE} (again)"

  if [ "${!VARIABLE_NAME_1}" != "${!VARIABLE_NAME_2}" ] ; then
    _die "Error: password mismatch"
  fi

  readonly ${VARIABLE_NAME}="${!VARIABLE_NAME_2}"
}

function ask_for_user_password() {
    blank_line
    read -p "Enter your username: " USR
    while
        read -p "Enter your password: "$'' -s PASSWD
        blank_line
        read -p "Re-enter your password: "$'' -s CONF_PASSWD
        [[ $PASSWD != $CONF_PASSWD ]]
    do msg_warning "Passwords don't match"; done

    blank_line
    msg_sucess "Passwords match"
    msg_info "User $USR has password $PASSWD"
}

###################
## I/O FUNCTIONS ##
###################

### AVAILABILITY OF COMMANDS AND FILES by Martin Burger ###

# Makes sure that the given command is available.
# Example:
# assert_command_is_available "ping"
#
# See: http://stackoverflow.com/a/677212/66981
#
function assert_command_is_available { #public: Makes sure that the given command is available.
  local cmd=${1}
  type ${cmd} >/dev/null 2>&1 || cmn_die "Cancelling because required command '${cmd}' is not available."
}

# Makes sure that the given regular file exists. Thus, is not a directory or # device file.
# Example:
# assert_file_exists "myfile.txt"
#
function assert_file_exists { #public: Makes sure that the given regular file exists. Thus, is not a directory or # device file.
  local file=${1}
  if [[ ! -f "${file}" ]]; then
    cmn_die "Cancelling because required file '${file}' does not exist."
  fi
}

# Makes sure that the given file does not exist.
# Example:
# assert_file_does_not_exist "file-to-be-written-in-a-moment"
function assert_file_does_not_exist { #public: Makes sure that the given file does not exist.
  local file=${1}
  if [[ -e "${file}" ]]; then
    cmn_die "Cancelling because file '${file}' exists."
  fi
}

# Replaces given string 'search' with 'replace' in given files.
#
# Important: The replacement is done in-place. Thus, it overwrites the given
# files, and no backup files are created.
#
# Note that this function is intended to be used to replace fixed strings; i.e.,
# it does not interpret regular expressions. It was written to replace simple
# placeholders in sample configuration files (you could say very poor man's
# templating engine).
#
# This functions expects given string 'search' to be found in all the files;
# thus, it expects to replace that string in all files. If a given file misses
# that string, a warning is issued by calling `cmn_echo_warn`. Furthermore,
# if a given file does not exist, a warning is issued as well.
#
# To replace the string, perl is used. Pattern metacharacters are quoted
# (disabled). The search is a global one; thus, all matches are replaced, and
# not just the first one.
#
# Example:
# replace_in_files placeholder replacement file1.txt file2.txt
#
function replace_in_files() { #public: Replaces given string 'search' with 'replace' in given files.
  local search=${1}
  local replace=${2}
  local files=${@:3}

  for file in ${files[@]}; do
    if [[ -e "${file}" ]]; then
      if ( grep --fixed-strings --quiet "${search}" "${file}" ); then
        perl -pi -e "s/\Q${search}/${replace}/g" "${file}"
      else
        cmn_echo_warn "Could not find search string '${search}' (thus, cannot replace with '${replace}') in file: ${file}"
      fi
    else
        cmn_echo_warn "File '${file}' does not exist (thus, cannot replace '${search}' with '${replace}')."
    fi
  done
}



function file_exists() {
    local file=$1

    [[ -f ${file} ]]
}
function folder_exists() {
    local folder=$1
    [[ -d ${folder} ]]
}
function device_exists() {
    local device=$1
    [[ -b ${device} ]]
}

function file_delete() {
    local file=$1

    [[ -f ${file} ]] && rm -f ${file} > /dev/null
}

# Check if a file does not exist
# usage: file_not_exists filename
function file_not_exists() {
    #check_args_len 1 ${#}
    #[[ ! -e ${1} ]] && _die "{MSG_ERROR} File '${1}' is required and it does not exist. Aborting..."
    [[ ! -e ${1} ]] && msg_error "File '${1}' is required and it does not exist. Aborting..."
}

# Check if a folder does not exist
# usage: folder_not_exists foldername
function folder_not_exists() {
    #check_args_len 1 ${#}
    #[[ ! -e ${1} ]] && _die "{MSG_ERROR} Folder '${1}' is required and it does not exist. Aborting..."
    [[ ! -d ${1} ]] && msg_error "Folder '${1}' is required and it does not exist. Aborting..."
}

# Check if a device does not exist
# usage: device_not_exists device
function device_not_exists() {
    #check_args_len 1 ${#}
    #[[ ! -b ${1} ]] && _die "{MSG_ERROR} Device '${1}' is required and it does not exist. Aborting..."
    [[ ! -b ${1} ]] && msg_error "Device '${1}' is required and it does not exist. Aborting..."
}

# Checks if folder exists, if not, it creates it
# usage: folder_create_if_needed folderpath
function folder_create_if_needed() {
    local folder=$1
    [[ -d $folder ]] || mkdir -p $folder
    readlink -m $folder # Nos da la ruta completa a la carpeta creada
}

# usage: get_files callback search (get_files 'cat' './runme.sh /home/folgui/.dialogrc')
function get_files() {
  check_args_len 2 ${#}

  local list

  for f in ${2}; do
    if [[ -f ${f} ]]; then
      list="${list} ${f}"
    fi
  done

  if [[ ${CONFIG_DEBUG} == true ]]; then
    print_ok "Search: \"${2}\""
    print_ok "Result: \"${list}\""
  fi

  eval "${1} ${list}"
}

# Appends one file (origin) to another (destination)
# usage: file_append filename1 filename2
function file_append() {
    local origin=$1
    local destination=$2
    if file_exists $origin && file_exists $destination; then
        necho "${MSG_INFO} cat ${origin} >> ${destination} "
        cat ${origin} >> ${destination} 2>&1
    fi
}

# Appends a line to a file
# usage: file_add_line line filepath
function file_add_line() {
    #add_line "export ANDROID_HOME=/opt/android-sdk" "/home/${username}/.bashrc"
	#local _has_line=$(grep -ci "${_add_line}" "${_filepath}" 2>&1)
    #local _has_line=`grep -ci "${_add_line}" "${_filepath}" 2>&1`
	#[[ $_has_line = 0 ]] && echo "${_add_line}" >> "${_filepath}"
	local line=$1
	local filepath=$2
    if file_exists $filepath; then
        necho "${MSG_INFO} echo $line >> $filepath "
        echo $line >> $filepath  2>&1
    fi
}

# bashlibs by kfirlavi
# Appends a line to a file
# usage: add_line_to_file line file
function add_line_to_file() {
    local file=$1; shift
    local line=$@

    echo $line >> $file
}
function line_in_file() {
    local file=$1; shift
    local line=$@

    line=$(echo $line | sed 's/\[/\\\[/g' | sed 's/\]/\\\]/g')
    grep -q "^$line$" $file
}
function add_line_to_file_if_not_exist() {
    local file=$1; shift
    local line=$@

    line_in_file $file $line || add_line_to_file $file $line
}

# bashlibs by kfirlavi
# Delete a line from file
# usage: delete_line_from_file line file
function delete_line_from_file() {
    local file=$1; shift
    local line=$@

    sed -i "\|^$line|d" $file
}
function delete_line_from_file_using_pattern() {
    local file=$1; shift
    local pattern=$@

    sed -i "\|$pattern|d" $file
}

# Replaces a line in a file
# usage: file_replace_line search replace filepath
# Sample: file_replace_line '"blocklist-enabled": false' '"blocklist-enabled": true' /home/${username}/.config/transmission/settings.json
function file_replace_line() {
    local search=${1}
    local replace=${2}
    local filepath=${3}
    local filebase=$(basename "${3}")

	sed -e "s/${search}/${replace}/" "${filepath}" > /tmp/"${filebase}" 2>"$LOG_FILE"
	if [[ ${?} -eq 0 ]]; then
	  mv /tmp/"${filebase}" "${filepath}"
	  necho "success!"
	else
	  necho "failed: ${search} - ${filepath}"
	fi
}

# Replaces a string in a file
# usage: file_replace_str search replace filepath
# Sample: file_replace_str 'hello' 'goodbye' '/home/${username}/.config/transmission/settings.json'
function file_replace_str() {
	local search=${1}
	local replace=${2}
	local filepath=${3}
	local filebase=$(basename "${3}")

    sed -i "s/${search}/${replace}/" "${filepath}" 2>"$LOG_FILE"
	if [[ ${?} -eq 0 ]]; then
	  necho "success!"
	else
	  necho "failed: ${search} - ${filepath}"
	fi
}

## Replaces some text in a file.
## @param origin Content to be matched.
## @param destination New content that replaces the matched content.
## @param file File to operate on.
## @retval 0 if the original content has been replaced.
## @retval 1 if an error occurred.
function str_replace_in_file() {
    [[ $# -lt 3 ]] && return 1

    local orig="$1"
    local dest="$2"

    for FILE in "${@:3:$#}"; do
        file_exists "$FILE" || return 1

        printf ',s/%s/%s/g\nw\nQ' "${orig}" "${dest}" | ed -s "$FILE" > /dev/null 2>&1 || return "$?"
    done

    return 0
}


# Deletes a string in a file
# usage: file_delete_str string filepath
function file_delete_str() {
    local delete=$1
    local filepath=$2
    sed -i '/${delete}/d' ${filepath}
}

# Edit a file with default EDITOR
# usage: file_edit filepath
function file_edit() {
    local filepath=${1}
    local editor=$EDITOR
    [[ $editor = "" ]] && editor="nano"
    [[ ! -f "/usr/bin/$editor" ]] && editor="nano"
    echo "$editor $filepath"
    $editor "$filepath"
}

# Copy a file (backup) (alias cpy)
# usage: file_copy origin destination
function file_copy {
    local origin=$1
    local destination=$2
    necho "${MSG_INFO} cp ${origin} ${destination} "
    #cp ${origin} ${destination} >> "$LOG_FILE" 2>&1
    cp ${origin} ${destination} 2>&1
}

# Comprobar si un fichero contiene una cadena
function file_contains_str() {
    local str=$1
    local filepath=$2

    [[ -n $(grep "${str}" "${filepath}") ]]
}
function file_contains_string() {
    local str=$1
    local filepath=$2
    #grep -q "${str}" "${file}"; [ $? -eq 0 ] && echo "yes" || echo "no"
    grep -q "${str}" "${file}"; [ $? -eq 0 ] && return 1 || return 0
}

# Comprobar si un fichero contiene una línea de texto completa
function file_contains_line() {
    local line=$1
    local filepath=$1

    [[ -n $(grep -Fxq "${line}" "${filepath}") ]]
}


# By Martin Burger
# Replaces given string 'search' with 'replace' in given files.
#
# Important: The replacement is done in-place. Thus, it overwrites the given
# files, and no backup files are created.
#
# Note that this function is intended to be used to replace fixed strings; i.e.,
# it does not interpret regular expressions. It was written to replace simple
# placeholders in sample configuration files (you could say very poor man's
# templating engine).
#
# This functions expects given string 'search' to be found in all the files;
# thus, it expects to replace that string in all files. If a given file misses
# that string, a warning is issued by calling `cmn_echo_warn`. Furthermore,
# if a given file does not exist, a warning is issued as well.
#
# To replace the string, perl is used. Pattern metacharacters are quoted
# (disabled). The search is a global one; thus, all matches are replaced, and
# not just the first one.
#
# Example:
# cmn_replace_in_files placeholder replacement file1.txt file2.txt
#
function replace_in_files() { #public: Replaces given string 'search' with 'replace' in given files.
  local search=${1}
  local replace=${2}
  local files=${@:3}

  for file in ${files[@]}; do
    if [[ -e "${file}" ]]; then
      if ( grep --fixed-strings --quiet "${search}" "${file}" ); then
        perl -pi -e "s/\Q${search}/${replace}/g" "${file}"
      else
        msg_warning "Could not find search string '${search}' (thus, cannot replace with '${replace}') in file: ${file}"
      fi
    else
        msg_warning "File '${file}' does not exist (thus, cannot replace '${search}' with '${replace}')."
    fi
  done

}

######################
## STRING FUNCTIONS ##
######################

## https://stackoverflow.com/questions/229551/how-to-check-if-a-string-contains-a-substring-in-bash
function has_substring() {
    [[ -z "${2##*$1*}" ]]
}

function contains_element() {
	#check if an element exist in a string
	for e in "${@:2}"; do [[ "$e" == "$1" ]] && break; done;
}

# Replaces some text in a string
## @param origin Content to be matched.
## @param destination New content that replaces the matched content.
## @param file File to operate on.
## @retval 0 if the original content has been replaced.
## @retval 1 if an error occurred.
# usage: str_replace find replace string
# Sample: str_replace 'hello' 'goodbye' 'hello, good moning; hello everybody'
function str_replace() {
    # Replace string with another string with bash string manipulation operators only bash version 4.x+
    # Sample:
    # message="I love Linux. Linux is awesome but FreeBSD is better too. Try it out."
    # updated="${message//Linux/Unix}"
    local find=${1}
    local replace=${2}
    local data=${3}
    echo "${data//$find/$replace}"
}

function len() { #public: Returns length of string
    echo "La longitud de la cadena es de $(len $cadena) caracteres"
    echo ${#1}
}

## Converts string to lowercase
## usage: to_lower string
function str_to_lower() { #public: Converts string to lowercase
    local str=$1
    echo "$str" | tr '[:upper:]' '[:lower:]'
}
function tolower() { #public: Converts string to lowercase
    #echo "La cadena en minúsculas es: $(tolower $cadena)"
    echo ${1,,}
}

## Converts string to uppercase
## usage: to_upper string
function str_to_upper() { #public: Converts string to uppercase
    local str=$1
    echo "$str" | tr '[:lower:]' '[:upper:]'
}
function toupper() { #public: Converts string to uppercase
    echo "La cadena en mayúsculas es: $(toupper $cadena)"
    echo ${1^^}
}

## Removes whitespaces from begin and end of string
## usage: trim string
function str_trim() {
    local str=$1
    echo "$str" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

## Converts a text file with 1 columns to a row
## usage: column_to_row packages.x86_64
function column_to_row() {
    [[ $# -lt 1 ]] && return 1
    local file=$1

    cat $file | xargs -n 100 > $file_row
}

#######################
## COMMAND FUNCTIONS ##
#######################

# Check if the given command is available: is_available "ping"
function is_available() {
    local cmd=$1
    #type ${cmd} >/dev/null 2>&1 || msg_warning "Command '${cmd}' is recommended and it is not available."
    type ${cmd} >/dev/null 2>&1 || return 1
}

## Executes a command and displays its status ('OK' or 'FAILED'): cmd "cat $LOG_FILE"
function cmd() {
    local command="$@"
    msg "Executing: $command"

    $(eval "$command" 2>&1)
    #local result=$(eval "$command" 2>&1)
    local error="$?"

    msg="Command: ${command:0:29}"

    tput cuu1

    if [ "$error" == "0" ]; then
        msg_success "$msg"
        if is_enabled DEBUG; then
            msg_debug "$result"
        fi
    else
        msg_failed "$msg"
        #log "$result"
    fi

    return "$error"
}

function run_command() {
    #pacman -S --noconfirm --needed ${PKG} >>"$LOG" 2>&1 &
    local cmd="$@"
    ${cmd} 2>&1 &
    local error="$?"
    pid=$!;progress $pid

    if [ "$error" == "0" ]; then
        echo "SUCCESS"
        #msg_success "$msg"
    else
        echo "FAILED"
        #msg_failed "$msg"
        #log_error "$result"
    fi

    #LOG_FILE="./script.log"
    if [[ $LOG_ENABLED == "yes" ]]; then
        echo "$cmd" >> "$LOG_FILE"
    fi
}

function run_command_() {
    #pacman -S --noconfirm --needed ${PKG} >>"$LOG" 2>&1 &
    local command="$@"
    local msg="Command: ${command}"
    echo -e " ${BWHITE}$msg${RESET}"
    ${command} 2>&1
}

####################
## MISC FUNCTIONS ##
####################

# Developer: Maik Ellerbrock <opensource@frapsoft.com>
# GitHub:  https://github.com/ellerbrock
# usage: check_args_len REQUIRED parameter
# example: check_args_len 2 ${#} - check inside a function if at least 2 parameter are given
function check_args_len() {
  if [[ ${#} -lt 2 ]]; then
    msg_error "missing parameter: usage ${0}"
    exit 1
  fi

  if [[ ${2} -lt ${1} ]]; then
    msg_error "missing parameter(s) (required: ${1} | given: ${2})"
    exit 1
  fi
}


#SPIN="/-\|" #SPINNER POSITION
# PROGRESSBAR / SPINNER

function spinny() {
	#local SPIN="/-\|" #SPINNER POSITION
	echo -ne "\b${SPIN:i++%${#SPIN}:1}"
}

function progress() {
	iecho "  "; # iecho "  ";
	while true; do
		kill -0 $pid &> /dev/null;
		if [[ $? == 0 ]]; then
			spinny
			sleep 0.25
		else
			iecho "\b\b";
			wait $pid
			retcode=$?
			echo -ne "$pid's retcode: $retcode" >> $LOG_FILE
			if [[ $retcode == 0 ]] || [[ $retcode == 255 ]]; then
				#cecho OK!
				necho " ${BGREEN}✔${RESET}" #necho " ${BREEN}✔${RESET}"
			else
				#cecho ERROR!
				necho " ${BRED}✖${RESET}" # necho " ${BRED}✖${RESET}"
				###echo -e "$PKG" >> $PKG_FAIL
				tail -n 15 $LOG_FILE
			fi
			break
		fi
	done
}

# ------ Progress/Spinny samples ---------
# 	mkinitcpio -p linux >>"$LOG" 2>&1 &
#	pid=$!;progress $pid
# ---
#	pacman -S --noconfirm --needed "${PKG}" >>"$LOG" 2>&1 &
#	pid=$!;progress $pid
# ---
#	pacman -Rcsn --noconfirm "${PKG}" >>"$LOG" 2>&1 &
#	pid=$!;progress $pid
# ---
#	systemctl "${_action}" "${_object}" >> "$LOG" 2>&1
#	pid=$!;progress $pid
# ---
#	gpasswd -a "${_user}" "${_group}" >>"$LOG" 2>&1 &
#	pid=$!;progress $pid
# -------------------------------------

# Giuseppe (mhsalvor) Molinaro - g.molinaro@linuxmail.org
# Since there are a few times this script moves things around with no output, here's a spinner
# Sample:
# sleep 5 & spinner $!
# rm -rf "${ARCHIVE}" & spinner $!
# mv "${PREV}" "${OLD}" & spinner $!
function spinner() {
    tput civis; # turns the cursor invisible
    local pid=$1
    local delay=0.05
    while [[ $(ps -eo pid | grep ${pid}) ]]; do
        for i in \| / - \\; do
            printf ' [%c]\b\b\b\b' $i
            sleep ${delay}
        done
    done
    printf '\b\b\b\b'
    tput cnorm; #turns the cursor visible again
}

## Output messages through the notification system, prints to #stdout in the worst escenario
## usage: notify message
## sample: notify "Todas las operaciones de ${TITLE} han finalizado correctamente."
function notify() {
    [ -z "${1}" ] && return 1
    if [ X"${TERM}" = X"linux" ] || [ -z "${TERM}" ]; then
        kill -9 $(pgrep notify-osd) >/dev/null 2>&1
        if ! DISPLAY=${DISPLAY:-:0} notify-send -t 5000 -i utilities-terminal "${1}"; then
            if command -v "gxmessage" 2>/dev/null; then
                font="Monaco 9"
                DISPLAY=${DISPLAY:-:0} gxmessage "${font:+-fn "$font"}" "${1}" "ok"
            elif command -v "xmessage" 2>/dev/null; then
                font="fixed"
                DISPLAY=${DISPLAY:-:0}  xmessage "${font:+-fn "$font"}" "${1}" "ok"
            fi
        fi
    else
        printf "%s\\n" "${1}"
    fi
}

function get_userinfo() {
  if [[ $EUID -ne 0 ]]; then
      if [[ -z $USERNAME ]]; then
          USERNAME="$(whoami)"
          USERHOME="/home/$USERNAME"
      fi
  fi
}


####################
## TIME FUNCTIONS ##
####################

## Displays the current timestamp.
function now() {
    date +%s
}

## Displays the time elapsed between the 'start' and 'stop' parameters.
function elapsed() {
    local start="$1"
    local stop="$2"
    local elapsed=$(( stop - start ))
    iecho $elapsed
}

## Starts the watch.
function start_watch() {
    __START_WATCH=$(now)
}

## Stops the watch and displays the time elapsed.
## @retval 0 if succeed.
## @retval 1 if the watch has not been started.
## @return Time elapsed since the watch has been started.
function stop_watch() {
    if has_value __START_WATCH; then
        STOP_WATCH=$(now)
        elapsed "$__START_WATCH" "$STOP_WATCH"
        return 0
    else
        return 1
    fi
}

###############################################
## CHECK HARDWARE/SOFTWARE/NETWORK FUNCTIONS ##
###############################################

## Check BASH version. In this case, if its >= 3.3
function check_bash() {
    if [[ "${#BASH_VERSINFO[@]}" -eq 0 ||
            ${BASH_VERSINFO[0]}  -lt 3 ||
        ( ${BASH_VERSINFO[0]}  -eq 3 && ${BASH_VERSINFO[1]} -lt 3 ) ]]
    then
        echo 1>&2 "This script can only run with bash version >= 3.3"
        if [[ -n "$BASH_VERSION" ]]; then
            echo 1>&2 "This is bash $BASH_VERSION"
        else
            echo 1>&2 "This is not bash!"
        fi
        exit 75 # EPROGMISMATCH
    fi
}

# By Martin Burger
# Makes sure that the script is run as root. If it is, the function just
# returns; if not, it prints an error message and exits with return code 1 by
# calling `cmn_die`.
#
# Example:
# assert_running_as_root
#
# Note that this function uses variable $EUID which holds the "effective" user
# ID number; the EUID will be 0 even though the current user has gained root
# priviliges by means of su or sudo.
#
# See: http://www.linuxjournal.com/content/check-see-if-script-was-run-root-0
function assert_running_as_root { #public: Makes sure that the script is run as root.
  if [[ ${EUID} -ne 0 ]]; then
    cmn_die "This script must be run as root!"
  fi
}

## Check if current user had admin privileges (root, sudo)
## Note that this function uses variable $EUID which holds the "effective" user
## ID number; the EUID will be 0 even though the current user has gained root
## priviliges by means of su or sudo.
function check_root() {
	#show_msg header "Checking administrative privileges of current user..."
	local text="▪ Checking superuser permissions............................."
	if [[ $EUID -ne 0 ]]; then
		echo -e "${WHITE} ${text} ${BRED}FAILED${RESET}"
		msg_error "The script requieres superuser permissions."
		exit 1
	else
		echo -e "${WHITE} ${text} ${BGREEN}PASSED${RESET}"
		return 0
	fi
}

function check_user() {
	if [[ "$(id -u)" == "0" ]]; then
		msg_error "You must run script with normal user permissions."
	else
		msg_successs "${BGREEN} ▪ Checking normal user permissions........................... PASSED${RESET}"
		return 0
	fi
}

# Check user
function current_user() {
    whoami
}
function running_as_root() {
    [[ $(current_user) == root ]]
}
function must_run_as_root() {
    running_as_root || eexit "'$(progname)' must be run as root"
}
function must_run_as_user() {
    runnin_as_root && eexit "'$(progname)' must be run as user"
}
function eexit() {
    verror "$@"
    exit 1
}
function verror() {
    vout red Error $@
}
function vout() {
    local color=$1; shift
    local level=$1; shift
    local str=$@

    level_is_off $level \
        && return

    local color_str="$(color $color)$level: $(no_color)$str"
    local non_color_str="$level: $str"

    colors_are_on \
        && echo -e "$color_str" \
        || echo "$non_color_str"

    verbose_with_logger_enabled \
        && logger "$non_color_str"

    true
}

## Check if script has at least one instance running
function check_instances() {
    local text="▪ Checking instances of script..............................."
	if [[ -f ${LOCK_FILE} ]]; then
        echo -e "${WHITE} ${text} ${BRED}FAILED${RESET}"
		msg_error "Script cannot be executed because it already has at least one instance running. Aborting..."
		exit 1
	 else
        echo -e "${WHITE} ${text} ${BGREEN}PASSED${RESET}"
		#touch $WORKDIR/$LOCKFILE
		touch "${LOCK_FILE}" &> /dev/null
		return 0
	fi
}

## Check system BIOS type (UEFI/legacy)
function check_bios_uefi() {
    local text="▪ Checking BIOS type........................................."
	if [[ -d "/sys/firmware/efi/efivars/" ]]; then
		BIOS_TYPE="uefi"
		UEFI=1
        echo -e "${WHITE} ${text} ${BGREEN}UEFI${RESET}"
	else
		BIOS_TYPE="bios"
		UEFI=0
        echo -e "${WHITE} ${text} ${BGREEN}Legacy${RESET}"
	fi
}

## Check system CPU
function check_cpu() {
    local text="▪ Checking CPU..............................................."
    if [ -n "$(lscpu | grep GenuineIntel)" ]; then
        CPU_VENDOR="intel"
    elif [ -n "$(lscpu | grep AuthenticAMD)" ]; then
        CPU_VENDOR="amd"
    fi
    echo -e "${WHITE} ${text} ${BGREEN}${CPU_VENDOR}${RESET}"
}

## Check system graphics card
function info_vga() {
    print_title "CHECKING GPU INFO"

    msg_info "Checking LSPCI"
    sudo lspci -x | grep VGA

    if test -f /usr/bin/glxinfo; then
        msg_info "Checking GLXINFO"
        glxinfo | grep -E "OpenGL vendor|OpenGL renderer*"
    else
        msg_warning "glxinfo not installed, installing"
        sudo pacman -S --noconfirm mesa-utils
    fi

    if test -f /usr/bin/nvidia-smi; then
        msg_info "Checking NVIDIA-SMI"
        nvidia-smi -L
    else
        msg_info "No nvidia driver present"
    fi
}

function check_vga() {
    local text="▪ Checking VGA..............................................."
	if [[ $EUID -ne 0 ]]; then
      echo -e "${BWHITE} ${text} ${BRED}FAILED (root required)${RESET}"
	else
      # Determine video chipset - only Intel, ATI and nvidia are supported by this script
      #necho " ${BBLUE}[${RESET}${BOLD} * ${BBLUE}]${RESET} Detecting video chipset..."
      local vga=$(lspci | grep VGA | tr "[:upper:]" "[:lower:]")
      local vga_length=$(lspci | grep VGA | wc -l)

      if [[ -n $(dmidecode --type 1 | grep VirtualBox) ]]; then
        VIDEO_DRIVER="virtualbox"
      elif [[ -n $(dmidecode --type 1 | grep VMware) ]]; then
        VIDEO_DRIVER="vmware"
      elif [[ $vga_length -eq 2 ]] && [[ -n $(echo "${vga}" | grep "nvidia") || -f /sys/kernel/debug/dri/0/vbios.rom ]]; then
        VIDEO_DRIVER="bumblebee"
      elif [[ -n $(echo "${vga}" | grep "nvidia") || -f /sys/kernel/debug/dri/0/vbios.rom ]]; then
        VIDEO_DRIVER="nvidia"
        read_option "Install NVIDIA proprietary driver" OPTION
        if [[ $OPTION == y ]]; then
            VIDEO_DRIVER="nvidia"
        else
            VIDEO_DRIVER="nouveau"
        fi
      elif [[ -n $(echo "${vga}" | grep "advanced micro devices") || -f /sys/kernel/debug/dri/0/radeon_pm_info || -f /sys/kernel/debug/dri/0/radeon_sa_info ]]; then
        #AMD/ATI
        VIDEO_DRIVER="AMDGPU"
        read_option "Install AMDGPU driver" OPTION
        if [[ $OPTION == y ]]; then
            VIDEO_DRIVER="amdgpu"
        else
            VIDEO_DRIVER="ati"
        fi
      elif [[ -n $(echo "${vga}" | grep "intel corporation") || -f /sys/kernel/debug/dri/0/i915_capabilities ]]; then
        VIDEO_DRIVER="intel"
      else
        VIDEO_DRIVER="vesa"
      fi
      OPTION="y"
      [[ $VIDEO_DRIVER == intel || $VIDEO_DRIVER == vesa ]] && read -p "Confirm video driver: $VIDEO_DRIVER [Y/n]" OPTION
      if [[ $OPTION == n ]]; then
        printf "%s" "Type your video driver [ex: sis, fbdev, modesetting]: "
        read -r VIDEO_DRIVER
      fi
      #show_msg info "TU DRIVER DE VIDEO ES: ${VIDEO_DRIVER}"
      echo -e "${WHITE} ${text} ${BGREEN}${VIDEO_DRIVER}${RESET}"
	fi
}

## Check system graphics card
function check_gpu() {
    local text="▪ Checking GPU..............................................."
    local gpuinfo=$(lspci | grep -i --color 'vga\|3d\|2d')
    local gpu
#     if [[ "$gpuinfo" == *"Intel"* ]]; then
#         gpu="INTEL"
#     elif [[ "$gpuinfo" == *"NVIDIA"* ]]; then
#         gpu="NVIDIA"
#     elif [[ "$gpuinfo" == *"AMD"* ]]; then
#         gpu="AMD"
#     else
#         gpu="UNKNOWN"
#     fi
    if has_substring "Intel" "$gpuinfo"; then
        gpu="INTEL"
    elif has_substring "NVIDIA" "$gpuinfo" ; then
        gpu="NVIDIA"
    elif has_substring "AMD" "$gpuinfo"; then
        #AMD/ATI
        gpu="AMD"
    else
        gpu="UNKNOWN"
    fi
    echo -e "${WHITE} ${text} ${BGREEN}$gpu${RESET}"
}

function check_gpu_brand() {
    local text="▪ Checking GPU..............................................."
    local gpuinfo=$(lspci | grep -i --color 'vga\|3d\|2d')
    local gpu
    if has_substring "Intel" "$gpuinfo"; then
        gpu="INTEL"
    elif has_substring "NVIDIA" "$gpuinfo" ; then
        gpu="NVIDIA"
    elif has_substring "AMD" "$gpuinfo"; then
        #AMD/ATI
        gpu="AMD"
    else
        gpu="UNKNOWN"
    fi
    echo $gpu
}

# Check which Operating System is running
function check_os() {
	local text="▪ Checking which OS you are using............................"
	local OS="Linux"

	#echo_message info "Current OS is: "$(uname)
	if [[ $(uname) != "$OS" ]]; then
		#show_msg error "You aren't using $OS! Aborting..."
		#exit 99
        echo -e "${WHITE} ${text} ${BRED}$(uname)${RESET}"
	else
		#show_msg success "You are using ${OS}."
        echo -e "${WHITE} ${text} ${BGREEN}$OS${RESET}"
	fi
}

# Check which distribution is running
function check_distribution() {
	local distro=""
	local text="▪ Checking linux distro....................................."

	# check if 'lsb_release' exists
	if [[ $(which lsb_release &>/dev/null; echo $?) != 0 ]]; then
		show_msg error "\aCan't check which distribution you are using! Aborting."
        show_msg error " Aborting..." && sleep 3 && exit 99
	else
		# if Ubuntu
		if lsb_release -ds | grep -qE '(Ubuntu)'; then
			#echo 'Current distribution is: '$(lsb_release -ds)
			#show_msg success "You are using Ubuntu. :D"
			#echo "Proceeding."
			distro=$(lsb_release -ds)
		# if Mint or elementary
		elif lsb_release -ds | grep -qE '(Mint|elementary)'; then
			#echo 'Current distribution is: '$(lsb_release -ds)
			#show_msg success "You are using an Ubuntu-based distribution. It's probably fine. :)"
			#echo "Proceeding."
			distro=$(lsb_release -ds)
		# if Debian
		elif lsb_release -ds | grep -q 'Debian'; then
			#echo 'Current distribution is: '$(lsb_release -ds)
			#show_msg warning "You are using Debian. This is not recommended. Some functions may not work. :/"
			#echo "Proceeding nonetheless."
			distro=$(lsb_release -ds)
        elif lsb_release -ds | grep -q "Arch"; then
            distro=$(lsb_release -ds)
		# if anything else
		else
			#show_msg warning "You are using a distribution that may not be compatible with this script set."
			#show_msg warning "Proceeding may break your system."
			#show_msg question "Are you sure you want to continue? (Y)es, (N)o : " && read REPLY
			#case $REPLY in
			## Positive action
			#[Yy]* )
			#	show_msg warning "You have been warned."
			#	;;
			## Negative action
			#[Nn]* )
			#	show_msg info "Exiting..."
			#	exit 99
			#	;;
			## Error
			#* )
			#	show_msg error 'Sorry, try again.' && check_distribution
			#	;;
			#esac
			distro=""
		fi
		if [[ -n ${distro} ]]; then
            echo -e "${WHITE} ${text} ${BGREEN}${distro}${RESET}"
		else
            echo -e "${WHITE} ${text} ${BRED}FAILED${RESET}"
		fi
	fi
}

function check_distro() {
    VERSION_ID=""
    ID_LIKE=""
    ARCHLINUX=0
    local text="▪ Checking Arch Linux or Arch based distro..................."

	if [[ -f /etc/os-release ]]; then
		# /etc/os-release or /usr/lib/os-release
        # freedesktop.org and systemd
        . /etc/os-release
        OS=$NAME
        #OSVER=$VERSION
        OSVER=$VERSION_ID
        #OSVER=$BUILD_ID
        ARCH=$ID_LIKE
        #ARCH=$ID
        if [[ -z $OSVER ]]; then OSVER=$BUILD_ID; fi
    elif type lsb_release >/dev/null 2>&1; then
        # linuxbase.org
        OS=$(lsb_release -si)
        OSVER=$(lsb_release -sr)
    elif [ -f /etc/lsb-release ]; then
        # For some versions of Debian/Ubuntu without lsb_release command
        . /etc/lsb-release
        OS=$DISTRIB_ID
        OSVER=$DISTRIB_RELEASE
    else
        OS=$(awk '/DISTRIB_ID=/' /etc/*-release | sed 's/DISTRIB_ID=//' | tr '[:upper:]' '[:lower:]')
        OSVER=$(awk '/DISTRIB_RELEASE=/' /etc/*-release | sed 's/DISTRIB_RELEASE=//' | sed 's/[.]0/./')

        # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
        if [[ -z $OS ]]; then
            OS=$(uname -s)
        fi
        if [[ -z $VER ]]; then
            OSVER=$(uname -r)
        fi
    fi

    if [[ -z $ARCH ]]; then
        #[[ -f /etc/arch-release ]] && ARCHLINUX=1
        if [[ -f /etc/arch-release ]]; then
            ARCHLINUX=1
        fi
    else
        #[[ $ARCH == 'arch' ]] && ARCHLINUX=1
        if [[ $ARCH == 'arch' ]]; then
            ARCHLINUX=1
        fi
    fi

    #echo $OS
    #echo $VER
    #echo $ARCHLINUX

    if  [[ $ARCHLINUX == 0 && $OS != 'arch' ]]
        then
            #show_msg error "You must run the script on a distribution based on Arch Linux ($ARCHLINUX - $OS)"
            echo -e "${WHITE} ${text} ${BRED}FAILED ($OS)${RESET}"
            #exit 1
        else
            echo -e "${WHITE} ${text} ${BGREEN}PASSED${RESET}"
            return 0
    fi
}


function check_desktop_environment() {
	# Compatible, or mostly compatible, window managers
	#Blackbox >= version 0.70
	#IceWM
	#KWin (the default WM for KDE)
	#Metacity (the default WM for GNOME)
	#Openbox >= 3 (the default WM of Lubuntu)
	#sawfish
	#FVWM >= 2.5
	#waimea
	#PekWM
	#enlightenment >= 0.16.6
	#Xfce >= 4
	#Fluxbox >= 0.9.6
	#matchbox
	#Window Maker >= 0.91
	#compiz
	#Awesome
	#wmfs

    local text="▪ Checking desktop environment..............................."
	DESKTOP=""
	local WM=$(wmctrl -m | grep Name | awk '{print $2}')
	WM=${WM,,}  # convert to lower case
	#echo -e ${WM}
	if [[ $WM != "" ]]; then
		case ${WM} in
			kwin)
				DESKTOP="KDE PLASMA"
				KDE=1
				;;
			gnome)
				DESKTOP="GNOME"
				GNOME=1
				;;
			'gnome shell')
				DESKTOP="GNOME"
				GNOME=1
				;;
            xfwm4)
				DESKTOP="XFCE"
				XFCE=1
				;;
			deepin-wm)
				DESKTOP="DEEPIN"
				DEEPIN=1
				;;
			metacity)
				DESKTOP="GNOME"
				GNOME=1
				;;
			* ) ;;
		esac
	fi

	if [[ -n $DESKTOP ]]; then
        #if [[ $DESKTOP == "KDE" ]]; then
        #    echo -e "${BWHITE} ▪ Comprobando entorno de escritorio KDE PLASMA...............${BGREEN}OK!${RESET}"
        #else
        #    echo -e "${BWHITE} ▪ Comprobando entorno de escritorio ${RESET}${BRED}${DESKTOP}${RESET}${BGREEN}......................OK!${RESET}"
        #fi
        #return 0

        echo -e "${WHITE} ${text} ${BGREEN}${DESKTOP}${RESET}"
	else
		#show_msg error "No se ha podido detectar el entorno de escritorio instalado"
		#return 1
		echo -e "${WHITE} ${text} ${BRED}FAILED${RESET}"
	fi
}

function check_kdeplasma() {
    local text="▪ Checking KDE PLASMA desktop environment...................."
    if [ "$(env | grep XDG_CURRENT_DESKTOP=KDE)" ]; then
        DESKTOP="KDE"
        KDE=1
        echo -e "${WHITE} ${text} ${BGREEN}PASSED${RESET}"
    else
        DESKTOP=""
        KDE=0
        echo -e "${WHITE} ${text} ${BRED}FAILED${RESET}"
    fi
}

function check_gnome() {
    # No funciona porque al no ser un variable de entorno exportada, es como si no existiese en un script
    if [ "$(env | grep XDG_CURRENT_DESKTOP=GNOME)" ]; then
        DESKTOP="GNOME"
        GNOME=1
    else
        DESKTOP=""
        GNOME=0
    fi
}

function check_hostname() {
    local text="▪ Checking hostname.........................................."
    if [[ $(echo ${HOSTNAME} | sed 's/ //g') == "" ]]; then
        #msg_error "Nombre de Host (hostname) no está configurado."
        echo -e "${WHITE} ${text} ${BRED}FAILED${RESET}"
    else
        echo -e "${WHITE} ${text} ${BGREEN}PASSED (${HOSTNAME})${RESET}"
    fi
}

function check_internet_wget() {
    #check for internet connection, return 0 on success, 1 otherwise
    local text="▪ Checking internet connection..............................."
    wget --tries=3 --timeout=5 http://www.google.com -O /tmp/index.google > /dev/null 2>&1
    if [ -s /tmp/index.google ]; then
        rm -rf /tmp/index.google
        #show_msg success "You have an Internet connection to run this script."
        #return 0
		echo -e "${WHITE} ${text} ${BGREEN}PASSED${RESET}"
    else
        rm -rf /tmp/index.google
        #show_msg error "You must have an Internet connection to run this script. Exiting..."
        #return 1
        echo -e "${WHITE} ${text} ${BRED}FAILED${RESET}"
        #exit 1
    fi
}

function check_internet_ping() {
	XPINGS=$(( $XPINGS + 1 ))
	function connection_test() {
	  ping -q -w 1 -c 1 `ip r | grep default | awk 'NR==1 {print $3}'` &> /dev/null && return 1 || return 0
	}
	if connection_test; then
		msg_error "You must have an Internet connection to run this script."
	else
		echo -e "${WHITE} ▪ Checking internet connection...............................${BGREEN}OK!${RESET}"
		return 0
	fi
}

function check_internet_netcat() {
    local text="▪ Checking internet connection..............................."
	if netcat -z google.com 80 &>/dev/null; then
		echo -e "${WHITE} ${text} ${BGREEN}PASSED${RESET}"
	else
		#show_msg error "Conexión a internet no disponible."
		echo -e "${WHITE} ${text} ${BRED}FAILED${RESET}"
	fi
}

function check_internet() {
     check_internet_wget
}

function check_virtual_machine() {
# Detect Physical or Virtualization system
#print_title "CHECKING VIRTUALIZATION SYSTEM"

shopt -s nocasematch
result=$(systemd-detect-virt)

if [[ $result == 'none' ]]; then
    export VIRTUALMACHINE=0
	msg_info "You are not in a Virtual Machine. It's a HOST system."
else
    export VIRTUALMACHINE=1

    case $result in
        kvm)
            msg_info "KVM+QEMU guest virtual machine"
            ;;
        oracle)
            msg_info "Oracle VM VirtualBox guest virtual machine"
            ;;
        qemu)
            msg_info "QEMU Software virtualization, without KVM guest virtual machine"
            ;;
        vmware)
            msg_info "VMware Workstation or Server guest virtual machine"
            ;;
        *)
            msg_info "Other Virtualization guest machine"
        ;;
    esac
fi
}

function check_virtualbox() {
    local text="▪ Checking if running under VirtualBox......................."
    if [ -n "$(lspci | grep -i virtualbox)" ]; then
        VIRTUALBOX=1
		echo -e "${WHITE} ${text} ${BGREEN}PASSED${RESET}"
    else
        VIRTUALBOX=0
		echo -e "${WHITE} ${text} ${BRED}FAILED${RESET}"
    fi
}

function check_device_trim() {
	# check_device_trim /dev/sda
    # El hdparm no funciona con SSD's NVME
    # Check if your drive support it: sudo hdparm -I /dev/sdx | grep TRIM
    [[ -n $(hdparm -I $1 | grep TRIM 2> /dev/null) ]] && TRIM=1
    if [[ -n $TRIM ]]; then
		echo -e "${WHITE} ▪ Checking if device supports TRIM........................... ${BGREEN}PASSED${RESET}"
    fi
}

###################################
## SYSTEM AND SERVICES FUNCTIONS ##
###################################

function sysctl() {
	local action=${1}
	local service=${2}
	iecho " ${BBLUE}[${RESET}${BOLD}X${BBLUE}]${RESET} systemctl ${_action} ${_service} "
	systemctl "${_action}" "${_service}" >> "$LOG_FILE" 2>&1 &
	pid=$!;progress $pid
}

function is_service_active() {
    check_args_len 1 ${#}
	local service="$1"
	if [ $(systemctl is-active ${service}) != "active" ]
		then
			msg_info "${service} is not active, starting it..."
			sysctl start ${service}
		else
			msg_info "${service} active"
	fi
}

function is_service_enabled() {
    check_args_len 1 ${#}
	local service="$1"
	if [ $(systemctl is-enabled ${service}) != "enabled" ]
		then
			msg_info "${service} is not enabled, enabling it..."
			sysctl enable ${service}
		else
			msg_info "${service} enabled"
	fi
}

function enable_services() {
#     SERVICES=(
#     'avahi-daemon.service'
#     'bluetooth.service'
#     'NetworkManager.service'
#     'ntpd.service'
#     'fstrim.service'
#     'sshd.service'
#     )

    #sudo systemctl enable bluetooth.service
    #sudo systemctl start bluetooth.service
    #sudo systemctl enable fstrim.timer
    #sudo systemctl start fstrim.timer

    #enable_services "avahi-daemon.service bluetooth.service NetworkManager.service"

    if [[ -z ${@} ]]; then
        msg_error "No services to work with"
    else
        #for service in ${SERVICES[@]}
        for service in "${@}"
        do
            if systemctl is-enabled --quiet $service; then
                if systemctl is-active --quiet $service; then
                    # Reiniciar el servicio si está habilitdo y activo
                    echo "* Reiniciando $service ..."
                    sudo systemctl restart $service
                else
                    # Iniciar el servicio si no está activo
                    echo "* Iniciando $service ..."
                    sudo systemctl start $service
                fi
            else
                # Habilitar e Iniciar el servicio al no estar habilitado
                echo "* Habilitando e iniciando $service ..."
                sudo systemctl enable $service
                sudo systemctl start $service
            fi
        done
    fi
}

function add_module() {
    local modules="$@"
	for module in "$modules"; do
	  #check if the name of the module can be the same of the module or the given name
	  [[ $# -lt 2 ]] && local module_name="$module" || local module_name="$2"
	  local has_module=$(grep "$module" /etc/modules-load.d/"${module_name}".conf 2>&1)
	  [[ -z $has_module ]] && echo "$module" >> /etc/modules-load.d/"${module_name}".conf
	  start_module "$module"
	done
}

function start_module() {
    local modules="$@"
	modprobe "$modules"
}

function update_early_modules() {
	local new_module="$1"
	local current_modules=$(grep -E ^MODULES= /etc/mkinitcpio.conf)

	if [[ -n ${new_module} ]]; then
	  # Determine if the new module is already listed.
	  local exists=$(echo "${current_modules}" | grep "${new_module}")
	  if [ $? -eq 1 ]; then
		source /etc/mkinitcpio.conf
		if [[ -z ${MODULES} ]]; then
		  new_module="${new_module}"
		else
		  new_module="${MODULES} ${new_module}"
		fi
		file_replace_line "MODULES=\"${MODULES}\"" "MODULES=\"${new_module}\"" /etc/mkinitcpio.conf
		iecho " ${BBLUE}[${RESET}${BOLD}X${BBLUE}]${RESET} Rebuilding init "
		mkinitcpio -P >> "$LOG_FILE" 2>&1 &
		pid=$!;progress $pid
	  fi
	fi
}

function run_as_user() {
    # run_as_user "mv /home/${username}/.zshrc /home/${username}/.zshrc.bkp"
    # run_as_user "gconftool-2 --type string --set /system/gstreamer/0.10/audio/profiles/mp3/pipeline \audio/x-raw-int,rate=44100,channels=2 ! lame name=enc preset=1001 ! id3v2mux\""
    # run_as_user "systemctl --user enable psd.service"
    #sudo -H -u ${USER} ${1}
    sudo -H -u $SUDO_USER ${@} 2>&1
    #run_command "sudo -H -u $SUDO_USER ${@}"
}
function add_user_to_group() {
	local user=${1}
	local group=${2}

	if [[ -z ${group} ]]; then
        msg_error "the function 'add_user_to_group' does not have enough parameters."
	fi

	iecho " ${BBLUE}[${RESET}${BOLD}X${BBLUE}]${RESET} Adding ${BOLD}${user}${RESET} to ${BOLD}${group}${RESET} "
	groupadd "${group}" >> "$LOG_FILE" 2>&1 &
	gpasswd -a "${user}" "${group}" >> "$LOG_FILE" 2>&1 &
	pid=$!;progress $pid
}

function add_user_to_groups() {
    #add_user_to_groups "adm users audio docker games kvm libvirt scanner sambashare storage video optical lp network power"

    if [[ -z ${@} ]]; then
        msg_error "No groups to work with"
    else
        local username=$(whoami)
        for group in "${@}"
        do
            sudo usermod -a -G $group $username
            #sudo gpasswd -a $username cups
        done
    fi
}

# Check if user is in group: ingroup group user
# Sample: if ingroup kvm folgui; then echo "You are in group"; fi
function ingroup() {
    [[ " $(id -Gn $2) " == *" $1 "* ]];
}

function path_append() {
	# path_append "$HOME/Tools/Scripts"
	local appendpath="$1"
    if [ -d "$appendpath" ] && [[ ":$PATH:" != *":$appendpath:"* ]]; then
        export PATH="${PATH:+"$PATH:"}$appendpath"
    fi
}

function path_prepend() {
	# path_prepend "$HOME/Tools/Scripts"
	local preappendpath="$1"
    if [ -d "$preappendpath" ] && [[ ":$PATH:" != *":$preappendpath:"* ]]; then
        export PATH="$preappendpath${PATH:+":$PATH"}"
    fi
}

# Remove an entry from $PATH
# Based on http://stackoverflow.com/a/2108540/142339
function path_remove() {
  local arg path
  path=":$PATH:"
  for arg in "$@"; do path="${path//:$arg:/:}"; done
  path="${path%:}"
  path="${path#:}"
  echo "$path"
}

function disable_ask_for_sudo_password() {
    # let regular user run comands without password
    sudo echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel_sudo
}

function enable_ask_for_sudo_password() {
    # remove unprotected root privileges
    sudo echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel_sudo
}

function ask_for_root_password() {
    #Ask root password for sudo usage
    echo "Please introduce the root password..."
    read -s -p Password: rootpswd
}
function sudocmd() {
    echo "$rootpswd" | sudo -S "$@"
    #sudocmd add-apt-repository -y ppa:pi-rho/dev
}

# accept user passwords and pass them to another command that requires superuser privilege
function superuser_do() {
	print_title "Starting 'superuser_do' function"
	# check if current user is root
	if [[ $EUID = 0 ]]; then
		msg_warning "You are logged in as the root user. Again, this is not recommended. :/"
		# Running command without sudo
		$@
	else
		# check sudo uptime to see if a password is needed
		if [ $(sudo -n uptime 2>&1 | grep 'a password is required' | wc -l) != 0 ]; then
			msg_warning 'Admin privileges required.'
			# Draw window
			PASSWORD=$(whiptail --title "Password Required" --passwordbox "\nRequires admin privileges to continue. \n\nPlease enter your password:\n" 12 48 3>&1 1>&2 2>&3)
			if [ $? = 0 ]; then
				# while loop for sudo attempts
				COUNT=0
				MAXCOUNT=3
				while [ $COUNT -lt $MAXCOUNT ]; do
					# check if sudo command fails
					if [[ $(sudo -S <<< "$PASSWORD" echo) -ne 0 ]]; then
						msg_warning "Incorrect password."
						# Prompt for password again
						PASSWORD=$(whiptail --title "Password Error" --passwordbox "\nThe password you provided was not correct.\n\nPlease enter your password again:\n" 12 48 3>&1 1>&2 2>&3)
						# Abort if user cancels
						if [ $? = 1 ]; then
							# Error message if user cancels
							msg_error "Password prompt cancelled. Aborting..."
							main
						fi
						# Increase the count
						let COUNT=COUNT+1
						# Error message if too many attempts
						if [[ "$COUNT" -eq "$MAXCOUNT" ]]; then
							msg_error "Too many failed password attempts. Aborting..."
							whiptail --msgbox "Too many failed password attempts. Please try again." --title "Oops" 8 56
							main
						fi
					else
						# pass the command to sudo
						sudo ${@}
						break
					fi
				done
			else
				# Error message if user cancels
				msg_error "Password prompt cancelled. Aborting..."
				whiptail --msgbox "Password is required to proceed. Please try again." --title "Oops" 8 56
				main
			fi
		else
			msg_info "Admin privileges not required at this time."
			# pass the command to sudo
			sudo $@
		fi
	fi
}

# Author: Tasos Latsas

# spinner.sh
#
# Display an awesome 'spinner' while running your long shell commands
#
# Do *NOT* call _spinner function directly.
# Use {start,stop}_spinner wrapper functions

# usage:
#   1. source this script in your's
#   2. start the spinner:
#       start_spinner [display-message-here]
#   3. run your command
#   4. stop the spinner:
#       stop_spinner [your command's exit status]
#
# Also see: test.sh


function _spinner() {
    # $1 start/stop
    #
    # on start: $2 display message
    # on stop : $2 process exit status
    #           $3 spinner function pid (supplied from stop_spinner)

    local on_success="DONE"
    local on_fail="FAIL"
    local white="\e[1;37m"
    local green="\e[1;32m"
    local red="\e[1;31m"
    local nc="\e[0m"

    case $1 in
        start)
            # calculate the column where spinner and status msg will be displayed
            let column=$(tput cols)-${#2}-8
            # display message and position the cursor in $column column
            echo -ne ${2}
            printf "%${column}s"

            # start spinner
            i=1
            sp='\|/-'
            delay=${SPINNER_DELAY:-0.15}

            while :
            do
                printf "\b${sp:i++%${#sp}:1}"
                sleep $delay
            done
            ;;
        stop)
            if [[ -z ${3} ]]; then
                echo "spinner is not running.."
                exit 1
            fi

            kill $3 > /dev/null 2>&1

            # inform the user uppon success or failure
            echo -en "\b["
            if [[ $2 -eq 0 ]]; then
                echo -en "${green}${on_success}${nc}"
            else
                echo -en "${red}${on_fail}${nc}"
            fi
            echo -e "]"
            ;;
        *)
            echo "invalid argument, try {start/stop}"
            exit 1
            ;;
    esac
}

function start_spinner() {
    # $1 : msg to display
    _spinner "start" "${1}" &
    # set global spinner pid
    _sp_pid=$!
    disown
}

function stop_spinner() {
    # $1 : command exit status
    _spinner "stop" $1 $_sp_pid
    unset _sp_pid
}


# Developer: Maik Ellerbrock <opensource@frapsoft.com>
#
# GitHub:  https://github.com/ellerbrock
# Twitter: https://twitter.com/frapsoft
# Docker:  https://hub.docker.com/frapsoft

#DEP_VARS=("GUI_MSGBOX_HEIGHT GUI_MSGBOX_WIDTH")
#DEP_APPS=("dialog")

#check_deps vars ${DEP_VARS}
#check_deps apps ${DEP_APPS}

# usage: gui_msgbox message [title] [height] [width]
function gui_msgbox() {
  check_args_len 1 ${#}

  local t=""
  local h=${GUI_MSGBOX_HEIGHT}
  local w=${GUI_MSGBOX_WIDTH}

  [[ -n ${2} ]] && t="${2}"
  [[ -n ${3} ]] && h="${3}"
  [[ -n ${4} ]] && w="${4}"

  dialog --title "${t}" --msgbox "${1}" "${h}" "${w}"
}


# usage: gui_yesno callback message [title] [height] [width]
function gui_yesno() {
  check_args_len 2 ${#}

  local h=${GUI_MSGBOX_HEIGHT}
  local w=${GUI_MSGBOX_WIDTH}

  [[ -n ${3} ]] && h="${3}"
  [[ -n ${4} ]] && w="${4}"

  dialog --yesno "${2}" "${h}" "${w}"
  eval "${1} ${?}"
}

#
# from here under development ... (coming in the next release)
#

# # usage: gui_input message [title] [height] [width]
# function gui_input() {
#
#   check_args_len 1 ${#}
#
#   local t=""
#   local h=${GUI_MSGBOX_HEIGHT}
#   local w=${GUI_MSGBOX_WIDTH}
#
#   [[ -n ${2} ]] && t="${2}"
#   [[ -n ${3} ]] && h="${3}"
#   [[ -n ${4} ]] && w="${4}"
#
#   local res=$(dialog --title ${t} --inputbox "${1}" "${h}" "${w}" 3>&1 1>&2 2>&3 3>&-)
#   echo "res:${res}"
# }
#
# # usage: gui_input message [title] [height] [width]
# function gui_menue() {
#   # check_args_len 1 ${#}
#   #
#   # local t=""
#   # local h=${GUI_MSGBOX_HEIGHT}
#   # local w=${GUI_MSGBOX_WIDTH}
#   #
#   # [[ -n ${2} ]] && t="${2}"
#   # [[ -n ${3} ]] && h="${3}"
#   # [[ -n ${4} ]] && w="${4}"
#   #
#   # local res=$(dialog --title ${t} --inputbox "${1}" "${h}" "${w}" 3>&1 1>&2 2>&3 3>&-)
#   # echo "res:${res}"
#
#   local res=$(dialog --title "Please select the image" --menu "my menue" 10 45 3 sel1 "selection1" sel2 "selection2" sel3 "selection3"  3>&1 1>&2 2>&3 3>&-)
#   echo "res:${res}"
#
#   case ${res} in
#     sel1) echo "selection1";;
#     sel2) echo "selection2";;
#     sel3) echo "selection3";;
#   esac
# }

#MENU COMMONS FUNCTIONS {{{
checklist=( 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 )
  function read_input_options() {
    local line
    local packages
    #if [[ $AUTOMATIC_MODE -eq 1 ]]; then
    #  array=("$1")
    #else
    #  read -p "$PROMPT_OPTIONS" OPTION
    #  array=("$OPTION")
    #fi
    read -p "$PROMPT_OPTIONS" OPTION
    array=("$OPTION")
    for line in ${array[@]/,/ }; do
      if [[ ${line/-/} != $line ]]; then
        for ((i=${line%-*}; i<=${line#*-}; i++)); do
          packages+=($i);
        done
      else
        packages+=($line)
      fi
    done
    OPTIONS=("${packages[@]}")
  }
  function checkbox() {
    #display [X] or [ ]
    [[ "$1" -eq 1 ]] && echo -e "${BBLUE}[${RESET}${BOLD}✓${BBLUE}]${RESET}" || echo -e "${BBLUE}[ ${BBLUE}]${RESET}";
    #[[ "$1" -eq 1 ]] && echo -e "${BBlue}[${Reset}${Bold}X${BBlue}]${Reset}" || echo -e "${BBlue}[ ${BBlue}]${Reset}";
  }
  function checkbox_package() {
    #check if [X] or [ ]
    is_package_installed "$1" && checkbox 1 || checkbox 0
  }
  function contains_element() {
    #check if an element exist in a string
    for e in "${@:2}"; do [[ $e == $1 ]] && break; done;
  }
  function invalid_option() {
    print_line
    echo "Opción no válida. Prueba con otra."
    presskey
  }
  function menu_item() {
    #check if the number of arguments is less then 2
    [[ $# -lt 2 ]] && _package_name="$1" || _package_name="$2";
    #list of chars to remove from the package name
    local _chars=("Ttf-" "-bzr" "-hg" "-svn" "-git" "-stable" "-icon-theme" "Gnome-shell-theme-" "Gnome-shell-extension-");
    #remove chars from package name
    for char in ${_chars[@]}; do _package_name=`echo ${_package_name^} | sed 's/'$char'//'`; done
    #display checkbox and package name
    echo -e "$(checkbox_package "$1") ${Bold}${_package_name}${Reset}"
  }
  function mainmenu_item() {
    #if the task is done make sure we get the state
    if [ $1 == 1 -a "$3" != "" ]; then
      state="${BGreen}[${Reset}$3${BGreen}]${Reset}"
    fi
    echo -e "$(checkbox "$1") ${Bold}$2${Reset} ${state}"
  }
#MENU COMMONS FUNCTIONS }}}

# Output private/public functions
# if [[ $1 == '-h' || $1 == '--help' ]]; then
#     _quick_help
#     exit 0
# fi

# entry point
__init__

#export -f __log__
#export -f __msg__
#export -f log_error
#export -f log_info
#export -f log_warning
#export -f msg_error
