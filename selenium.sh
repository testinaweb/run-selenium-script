#!/bin/bash
# Author: Manuel Kanah <emanuele.kanah@dxi.eu>

# Colors
RED="\033[0;31m"
YELLOW="\033[0;33m"
GREEN="\033[0;32m"
NO_COLOUR="\033[0m"

# go to script path
pushd `dirname $0` > /dev/null
SCRIPTPATH=`pwd`

# loader [\|/-]
function spinner {
    local pid=$1
    local delay=0.15
    local spinstr='\|/-'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# --help
function help {
    echo -e "$YELLOW Usage:$NO_COLOUR
  ./selenium.sh [command_name]

$YELLOW Arguments:$NO_COLOUR
 $GREEN command$NO_COLOUR       The command to execute
 $GREEN command_name$NO_COLOUR  The command name (default: "--help")

$YELLOW Options:$NO_COLOUR
  $GREEN--help$NO_COLOUR        Display this help message.
  $GREEN--install$NO_COLOUR     Forces installation of packages you need.
  $GREEN--status$NO_COLOUR      Shows if the processes are running.
  $GREEN--start$NO_COLOUR       Starts all the processes.
  $GREEN--restart$NO_COLOUR     Re-starts all the processes.
  $GREEN--stop$NO_COLOUR        Stops all the processes.
"
}

# get the linux distribution family
function getLinuxDistribution {
    if [ -f /etc/debian_version ]; then
        OS="Debian"  # Debian, Ubuntu or Debian like
        VER=$(cat /etc/debian_version)
    elif [ -f /etc/redhat-release ]; then
        OS="RedHat" # Red Hat and CentOS
        VER=$(cat /etc/redhat-release)
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi

    echo ${OS}
}

# install packages for Red Hat like Linux systems
function installRedHatPackages {
    echo "Installing required packages to run Selenium with Firefox: firefox Xvfb libXfont Xorg java..."
    yum -y install firefox Xvfb libXfont Xorg java > /dev/null 2>&1 &
    if [ $(pidof yum) ] ; then
        spinner $(pidof yum)
    fi
}

# install packages for Debian like Linux systems
function installDebianPackages {
    echo "Installing required packages to run Selenium with Firefox: firefox xvfb libxfont1 libxft2 default-jre xorg openbox..."
    apt-get update && apt-get -y install firefox xvfb libxfont1 libxft2 default-jre xorg openbox > /dev/null 2>&1 &
    if [ $(pidof apt-get) ] ; then
        spinner $(pidof apt-get)
    fi
}

# --install
function install {
    # check permission
    if [ `whoami` != "root" ]; then
        echo "You must be root."
        return 0
    fi

    # install packages
    case $(getLinuxDistribution) in
        "RedHat")  installRedHatPackages
            ;;
        "Debian")  installDebianPackages
            ;;
        *) echo -e "${RED}This linux distribution is not supported${NO_COLOUR}"
            ;;
    esac

    # download selenium-server-standalone
    local SELENIUMVERSION="2.44/selenium-server-standalone-2.44.0.jar"
    if [ ! -f ${SELENIUMVERSION##*/} ]; then
        echo "Download selenium-server..."
        wget http://selenium-release.storage.googleapis.com/${SELENIUMVERSION} > /dev/null 2>&1 &
        if  [ $(pidof wget) ] ; then
            spinner $(pidof wget)
        fi
    else
        echo "${SELENIUMVERSION##*/} already exists. Nothing to do."
    fi
    echo -e "[${GREEN}Done${NO_COLOUR}]"
}

# get pid of Xvfb
function getXvfbPid {
    echo $(ps -ef | grep -i Xvfb | grep -v grep | awk '{print $2}')
}

# get pid of selenium-server
function getSeleniumServerPid {
    echo $(ps -ef | grep -i 'selenium-server' | grep -v grep | awk '{print $2}')
}

# --status
function status {
    #check Xvfb
    local XVFB=$(getXvfbPid)
    if [ ${XVFB} ] ; then
        echo "Xvfb or X virtual framebuffer is running with pid: $XVFB"
    else
        echo "Xvfb or X virtual framebuffer is not running. (Run: $0 --restart)"
    fi

    # check selenium
    local SELENIUM=$(getSeleniumServerPid)
    if [ ${SELENIUM} ] ; then
        echo "Selenium server is running with pid: $SELENIUM"
    else
        echo "Selenium server is not running. (Run: $0 --restart)"
    fi
}

# --stop
function stop {
    echo "Stopping Xvfb and selenium-server..."
    kill -9 $(getXvfbPid)
    kill -9 $(getSeleniumServerPid)
    echo -e "[${GREEN}Stopped${NO_COLOUR}]"
}

# --start
function start {
    if [ ! $(getXvfbPid) ] ; then
        echo "Starting Xvfb..."
        nohup Xvfb :99 -ac -screen 0 1280x1024x24 &
        export DISPLAY=:99
        echo -e "[${GREEN}Started${NO_COLOUR}]"
    else
        echo "Xvfb is running..."
    fi
    if [ ! $(getSeleniumServerPid) ] ; then
        echo "Starting selenium-server..."
        DISPLAY=:99 nohup /usr/bin/java -jar selenium-server-standalone-2.44.0.jar &
        echo -e "[${GREEN}Started${NO_COLOUR}]"
    else
        echo "selenium-server is running..."
    fi
}

# --restart
function restart {
    stop
    start
}

case "$1" in
    "--help")  help
        ;;
    "--install")  install
        ;;
    "--status")  status
        ;;
    "--start") start
       ;;
    "--restart") restart
        ;;
    "--stop") stop
        ;;
    *) help
       ;;
esac

# return to initial directory
popd > /dev/null
