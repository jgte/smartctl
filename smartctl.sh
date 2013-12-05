#!/bin/bash -u

# Wrapper for smartctl. Usage:
#
# smartctl.sh <smartctl flags(s)>
#
# or:
#
# smartctl.sh routine
#
# or:
#
# smartctl.sh <device>
#
# In the first case, the smartctl program is run with the <smartctl flags(s)>
# on all known devices, as determined by the following command:
#
# sudo parted -l | grep Disk | awk '{print $2}' | sed 's/://g'
#
# The second case makes successive calls to 'smartctl.sh <smartctl flags(s)>',
# with the following flags (in this order): --info, --capabilities, --health,
# --log=error, --log=selftest, --test=short (every 10 days),
# --test=long (every 105 days). This is suitable for the root crontab, with (e.g.)
# the following entry:
#
# export PATH=/usr/bin:/bin:/usr/sbin:/sbin; /some/path/smartctl.sh routine
#
# The third case runs 'smartctl <flag>' sequentially, on the specified deviced,
# with the following flags (in this order): --info, --capabilities, --health,
# --log=error, --log=selftest. It is useful to (e.g.) get SMART information about
# a new hard drive.

function machine_is
{
  OS=`uname -v`
  [[ ! "${OS//$1/}" == "$OS" ]] && return 0 || return 1
}

function ensure_dependencies
{
  #install dependencies
  for i in $@
  do
    if [ -z "`dpkg -s $i 2> /dev/null`" ]
    then
      echo "Need to install $i"
      if machine_is Ubuntu
      then
        sudo apt-get install $i 1>&2
      else
        echo "ERROR: cannot install $i, cannot continue."
        return 3
      fi
    fi
  done
  #check dependencies
  for i in $@
  do
    if [ -z "`dpkg -s $i 2> /dev/null`" ]
    then
      echo "ERROR: cannot find $i, cannot continue."
      return 3
    fi
  done
}

DEPS="parted smartmontools"
DEVS=$( sudo parted -l | grep Disk | awk '{print $2}' | sed 's/://g' )

#ensure the needed software is available
ensure_dependencies $DEPS || exit $?

if [ $# -eq 0 ]
then
  MODE="routine"
else
  MODE="$1"
fi

case $MODE in
--info|--all|--xall|--scan|--health|--capabilities|--attributes)
  for i in $DEVS
  do
    echo "============== ( $i ) =============="
    sudo smartctl $MODE $i
  done
;;
/dev/*)
  for i in --info --capabilities --health --log=error --log=selftest
  do
    echo "============== ( $i ) =============="
    echo sudo smartctl $i $MODE
  done
;;
routine)
  echo "---------------------------------"
  echo "               INFO"
  echo "---------------------------------"
  $0 --info         || exit 3
  echo "---------------------------------"
  echo "           CAPABILITIES"
  echo "---------------------------------"
  $0 --capabilities || exit 3
  echo "---------------------------------"
  echo "              HEALTH"
  echo "---------------------------------"
  $0 --health       || exit 3
  echo "---------------------------------"
  echo "             LOG=error"
  echo "---------------------------------"
  echo Y | $0 --log=error
  echo "---------------------------------"
  echo "           LOG=selftest"
  echo "---------------------------------"
  echo Y | $0 --log=selftest || exit 3
  #need to know the DOY
  DOY=$(date +%j)
  #only run the short test once every ST days
  ST=10
  if [ $(( $DOY - ($DOY / $ST) * $ST )) -eq 0 ]
  then
    echo "---------------------------------"
    echo "            TEST=short"
    echo "---------------------------------"
    echo Y | $0 --test=short   || exit 3
  fi
  #only run the short test once every LT days
  LT=$(( $ST * 10 + $ST / 2 ))
  if [ $(( $DOY - ($DOY / $LT) * $LT )) -eq 0 ]
  then
    echo "---------------------------------"
    echo "            TEST=long"
    echo "---------------------------------"
    echo Y | $0 --test=long   || exit 3
  fi
;;
*)
  echo "The following command is going to be issued on all devices:"
  echo "sudo smartctl $MODE <device>"
  echo "Continue? [Y/n]"
  read answer
  if [ "$answer" == "N" ] || [ "$answer" == "n" ]
  then
    exit 3
  fi
  for i in $DEVS
  do
    echo "============== ( $i ) =============="
    sudo smartctl $MODE $i || exit $?
  done
;;
esac