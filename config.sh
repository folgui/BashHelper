#!/usr/bin/env bash
# -*- tab-width: 4; encoding: utf-8 -*-

## TPUT COLORS ##
# Special
declare -rx	BOLD=$(tput bold)
declare -rx UNDERLINE=$(tput sgr 0 1)
declare -rx DEFAULT=$(tput sgr0)
declare -rx RESET=$(tput sgr0)
# Regular colors for foreground
declare -rx BLACK=$(tput setaf 0)
declare -rx RED=$(tput setaf 1)
declare -rx GREEN=$(tput setaf 2)
declare -rx YELLOW=$(tput setaf 3)
declare -rx BLUE=$(tput setaf 4)
declare -rx MAGENTA=$(tput setaf 5)
declare -rx CYAN=$(tput setaf 6)
declare -rx WHITE=$(tput setaf 7)
declare -rx ORANGE=$(tput setaf 202)
# Bold + Regular colors for foreground
declare -rx BBLACK=${BOLD}${BLACK}
declare -rx BRED=${BOLD}${RED}
declare -rx BGREEN=${BOLD}${GREEN}
declare -rx BYELLOW=${BOLD}${YELLOW}
declare -rx BBLUE=${BOLD}${BLUE}
declare -rx BMAGENTA=${BOLD}${MAGENTA}
declare -rx BCYAN=${BOLD}${CYAN}
declare -rx BWHITE=${BOLD}${WHITE}
declare -rx BORANGE=${BOLD}${ORANGE}
# Regular colors for background
declare -rx BLACK_BG=$(tput setab 0)
declare -rx RED_BG=$(tput setab 1)
declare -rx GREEN_BG=$(tput setab 2)
declare -rx YELLOW_BG=$(tput setab 3)
declare -rx BLUE_BG=$(tput setab 4)
declare -rx MAGENTA_BG=$(tput setab 5)
declare -rx CYAN_BG=$(tput setab 6)
declare -rx WHITE_BG=$(tput setab 7)

## MESSAGE SETTINGS
# Other special chars: ✖
declare -rx MSG_TITLE="${BBLUE}# "
declare -rx MSG_QUESTION=" ${YELLOW}[ ? ]"
declare -rx MSG_EMERGENCY=" ${BORANGE}[ ⚡]"
declare -rx MSG_CRITICAL=" ${BORANGE}[ ⚡]"
declare -rx MSG_ALERT=" ${BORANGE}[ ⚡]"
declare -rx MSG_ERROR=" ${BRED}[ ✘ ]"
declare -rx MSG_ERR=" ${BRED}[ ✘ ]"
declare -rx MSG_WARNING=" ${BORANGE}[ ⚡]"
declare -rx MSG_WARN=" ${BORANGE}[ ⚡]"
declare -rx MSG_OK=" ${BWHITE}[ ✓ ]"
declare -rx MSG_INFO=" ${BBLUE}[ ➜ ]"
declare -rx MSG_NOTICE=" ${BWHITE}[ * ]"
declare -rx MSG_DEBUG=" ${BWHITE}[ ➜ ]"
declare -rx MSG_PASSED=" ${BWHITE}[ ✓ ]"
declare -rx MSG_FAILED=" ${BWHITE}[ ✘ ]"
declare -rx MSG_SUCCESS=" ${BGREEN}[ ✓ ]"

## SCRIPT INFO
#declare -rx SCRIPT_DIR=$(dirname "$0"))
declare -rx SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
declare -rx WORK_DIR=$(cd "$(dirname "$0")" && pwd)
#declare -r SCRIPT_NAME="${0}"

### DEBUG / LOGGING ###
## Enables / disables the debug mode.
## Value: yes or no (y / n).
declare -x DEBUG="no"

## LOG FILE LOCATION AND FORMAT, ENABLE/DISABLE.
declare -x LOG_DATEFORMAT="%y-%m-%d_%H:%M"
declare -x LOG_DIR="$SCRIPT_DIR/logs"
declare -x LOG_FILE="$LOG_DIR/$0.log"
declare -x LOG_ENABLED="no"

## SYSLOGLOG FORMAT, ENABLE/DISABLE.
declare -x SYSLOG_TAG="$0"
declare -x SYSLOG_ENABLED="no"

## LOCK FILE LOCATION
declare -x LOCK_FILE="${SCRIPT_DIR}/$0.lock"

#Configurar la variable Internal Field Separator (Separador de campo interno) y lograr una mejor visualización
# y / o captura de las palabras (campos) de una cadena de caracteres. ¡CUIDADO! Afecta a dialogos como dialog, whiptail,
# zenity, etc. y estos dejan de funcionar.
#IFS=$'\n\t'

#DATE_NOW=$(date '+%y-%m-%d_%H-%M')
DATE_NOW=$(date +%Y%m%d_%H%M%S)

## PROMPTS
declare -x PAUSE="${BOLD}${WHITE}Press any key to continue...${RESET}"
declare -x PROMPT_OPTION="${BOLD}${WHITE}Select an option: ${RESET}"
declare -x PROMPT_OPTIONS="Enter number of option(s) (sample: 1 2 3 o 1-3): "

## MISC STUFF
declare -x SPIN="/-\|" #SPINNER POSITION
declare -x GUI="y"

# The logname function from coreutils provides us with the username that launches the script even if
# it is launched with sudo. Also we can use the $SUDO_USER environment variable.
declare -rx USER=$(logname)
declare -x NOW=
declare -rx AUTOMODE="no"

## DIALOG Declarations
#DIALOG=${DIALOG=dialog}
DIALOG=${DIALOG=whiptail}
#DIALOG=""
## Constantes para diálogos
declare -r MENU_ASK_LABEL="\n¿Qué deseas hacer?"
declare -r MENU_BTN_CANCEL="Salir"
declare -r MENU_PREFIX="[- "
declare -r MENU_POSTFIX=" -]"
declare -r EXIT_CONFIRM="¿Está seguro que desea salir?"
declare -r YES_BUTTON="Sí"

## GLOBAL VARS
    # Este debería ser la sección que contenga todas aquellas variables que el script de shell necesita o necesitará a lo largo de su ejecución.

    #_WORKDIR
    #_SCRIPTDIR
    #_DEPS="$SCRIPTDIR/pkg/dependencies.list"
    #_PURGED="$SCRIPTDIR/pkg/purge.list"
    #_PKGDIR="$(dirname "$0")/pkg"
    #_ LOG="${WORKDIR}/${SCRIPTNAME}.log"
    #_PKG_FAIL="${WORKDIR}/packages_failed.log"
    #_LOCKFILE
    #_PROMPT

    #_OS=$(lsb_release -d | awk '{print $2}')
    #_OS=$(awk '/DISTRIB_ID=/' /etc/*-release | sed 's/DISTRIB_ID=//' | tr '[:upper:]' '[:lower:]')
    #_DISTROLARGE=$(cat /etc/os-release | grep NAME | grep -v "VERSION" | sed -n '2p' | cut -f2 -d\")
    #_DISTROSHORT=$(cat /etc/os-release | grep NAME | grep -v "VERSION" | sed -n '2p' | cut -f2 -d\" | awk '{print $1}')

    #_DIALOG=${DIALOG=dialog}

    #_AUR=`echo -e "(${BPurple}aur${Reset})"`
    #_AUR_PKG_MANAGER="yaourt --tmp /var/tmp/"
    #_AUR_PKG_MANAGER="yay --noconfirm"
    #_AUR_PKG_MANAGER="yay"
    #_XPINGS=0 # CONNECTION CHECK
    #_EDITOR=nano


## INIT STUFF

