#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2068,SC2046,SC2086,SC2002,SC2206,SC2116

## Author: Tommy Miland (@tmiland) - Copyright (c) 2025


######################################################################
####                    Python Installer.sh                       ####
####                  Script to install Python                    ####
####                   Maintained by @tmiland                     ####
######################################################################


VERSION='1.0.0' # Must stay on line 14 for updater to fetch the numbers

#------------------------------------------------------------------------------#
#
# MIT License
#
# Copyright (c) 2025 Tommy Miland
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
#------------------------------------------------------------------------------#
## Take 'debug' as argument for debugging purpose
if [[ $* =~ "debug" ]]
then
  set -o errexit
  set -o pipefail
  set -o nounset
  set -o xtrace
fi
# Inspired Source: https://cloudspinx.com/how-to-install-python-on-debian
install_dir=/tmp

pip=1

# ANSI Colors
GREEN='\e[1;32m' # Bright Green
RED='\e[1;31m'   # Bright Red
RESET='\e[0m'    # Reset color

# Print an error message and exit (Red)
err() {
  printf "${RED}ERROR: %s${RESET}\n" "$*" >&2
  exit 1
}

# Print a log message (Green)
ok() {
  printf "${GREEN}%s${RESET}\n" "$*"
}

# Ensure the script is run as root
if [[ "$EUID" -ne 0 ]]; then
  err "This script must be run as root!"
fi

python_versions=$(curl -sSL https://www.python.org/ftp/python/ | sed -n 's!.*href="\([0-9]\+\.[0-9]\+\.[0-9]\+\)/".*!\1!p')

# python_versions_array=$(ls "$sources_dir")
python_version=($python_versions)
read -rp "$(
      v=0
      for v in ${python_version[@]}
      do
        echo "$((++f)): $v"
      done
      echo -ne "Please select a python version: "
)" selection
selected_python_version="${python_version[$((selection-1))]}"
ok "You selected $selected_python_version"

python_file_version=$(echo "$selected_python_version")

f1=$(echo "$python_file_version" | cut -d . -f 1)
f2=$(echo "$python_file_version" | cut -d . -f 2)

python_file_version="$f1.$f2"

# Distro support
ARCH_CHK=$(uname -m)
if [ ! ${ARCH_CHK} == 'x86_64' ]; then
  err "Sorry, your OS ($ARCH_CHK) is not supported."
fi
shopt -s nocasematch
if lsb_release -si >/dev/null 2>&1; then
  DISTRO=$(lsb_release -si)
else
  if [[ -f /etc/debian_version ]]; then
    DISTRO=$(cat /etc/issue.net)
  elif [[ -f /etc/redhat-release ]]; then
    DISTRO=$(cat /etc/redhat-release)
  elif [[ -f /etc/os-release ]]; then
    DISTRO=$(cat /etc/os-release | grep "PRETTY_NAME" | sed 's/PRETTY_NAME=//g' | sed 's/["]//g' | awk '{print $1}')
  fi
fi
case "$DISTRO" in
  Debian*|Ubuntu*|LinuxMint*|PureOS*|Pop*|Devuan*)
    export DEBIAN_FRONTEND=noninteractive
    # shellcheck disable=SC2140
    UPDATE="apt-get -o Dpkg::Progress-Fancy="1" update -qq"
    # shellcheck disable=SC2140
    INSTALL="apt-get -o Dpkg::Progress-Fancy="1" install -qq"
    ;;
  CentOS*)
    UPDATE="yum update -q"
    INSTALL="yum install -y -q"
    ;;
  Fedora*)
    UPDATE="dnf update -q"
    INSTALL="dnf install -y -q"
    ;;
  Arch*|Manjaro*)
    UPDATE="pacman -Syu"
    INSTALL="pacman -S --noconfirm --needed"
    ;;
  *) err "unknown distro: '$DISTRO'" ;;
esac

ok "Downloading Python-$selected_python_version.tar.xz..."
cd $install_dir \
|| err "Something went wrong changing to directory $install_dir."
wget https://www.python.org/ftp/python/"$selected_python_version"/Python-"$selected_python_version".tar.xz >/dev/null 2>&1 \
|| err "Something went wrong downloading Python-$selected_python_version.tar.xz"
ok "Done."

ok "Upacking Python-$selected_python_version.tar.xz"
tar -xvf Python-"$selected_python_version".tar.xz >/dev/null 2>&1
ok "Done."

ok "Compiling Python-$selected_python_version"
cd Python-"$selected_python_version" || exit 0
./configure --enable-optimizations --with-lto >/dev/null 2>&1
ok "Compiling and Installing Python-$selected_python_version"
make -j $(nproc) altinstall >/dev/null 2>&1
ok "done."

ok "Cleaning up..."
cd ..
rm -rf Python-"$selected_python_version"
ok "Done."

ok "Adding Python-$selected_python_version to system..."
update-alternatives --install /usr/bin/python"$python_file_version" python"$python_file_version" /usr/local/bin/python"$python_file_version" 10
ok "Done."

if python"$python_file_version" --version
then
  ok "Python-$selected_python_version installed successfully."
else
  err "Something went wrong installing Python-$selected_python_version"
fi

if [ $pip == "1" ]
then
  curl -sSL https://bootstrap.pypa.io/get-pip.py > get-pip.py >/dev/null 2>&1
  python"$python_file_version" ./get-pip.py
  if pip"$python_file_version" --version
  then
    ok "Pip installed successfully."
  else
    err "Something went wrong installing pip."
  fi
else
  ok "Not installing pip."
fi

ok "Installation done."
exit 0
