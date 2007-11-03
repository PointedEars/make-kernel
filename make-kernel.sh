#!/bin/bash

app=${0##*/}

# rm linux
# ln -s linux-2.6.*/ linux

installed ()
{
  dpkg -l "$1" 2>/dev/null | grep ^.i >/dev/null 2>&1
}

# required_install ()
# {
#   if ! installed "$1"; then
#   fi
# }

install_ketchup ()
{
  [ ! "$updated" ] && aptitude update
  if [ $? -eq 0 ]; then
    updated='yes'
    aptitude install ketchup
  fi
}

if ! installed ketchup ; then
  read -r -s -p "\
\`ketchup' is required (to detect and obtain the latest kernel source),
but it appears not to be installed.  Install it now [Y/n]? " \
       -n 1
  case $REPLY in
    [Nn])
      echo $REPLY
      exit 1;;
    *)
      echo Y
  esac
  echo

  if ! install_ketchup; then
    read -r -s -p "\
\`aptitude' is preferred as package manager above \'apt-get' (e.g. it has
debfoster's functionality, but integrates into the apt environment), but
it appears not to be installed.  Install \`aptitude' now [Y/n]? " \
         -n 1
    case $REPLY in
      [Nn])
        echo $REPLY
        exit 1;;
      *)
        echo Y
        apt-get update && apt-get install ketchup
        if [ $? -ne 0 ]; then
          echo >&2 "\
$app: An error has occured while installing \`ketchup' (required)."
        fi
    esac
    echo

    if apt-get update; then
      if ! apt-get install aptitude; then
        echo "$app: aptitude install failed, attempting reinstall."
        if apt-get --reinstall install aptitude; then
          if ! install_ketchup; then
            echo >&2 "\
$app: All attempts to install ketchup have failed.
Sorry, you need to make your kernel manually."
            exit 1
          fi
        fi
      fi
    fi
  fi
fi

latest=`ketchup -s ${1:-2.6}`

ketchup -a /Downloads/sys/GNU/kernel/ -d linux/ -r ${1:-2.6} \
&& (test -L linux && rm linux; ln -s linux-$latest linux)
  
cd linux \
  && ([ ! -s .config -a -s ../.config ] && cp -p ../.config ./ || true) \
  && (make xconfig || make menuconfig || make config) \
  && (
       read -r -s -p "Build Linux $latest now [y/N]? " -n 1
       case $REPLY in
         [Yy])
           echo $REPLY;;
         *)
           echo N
           exit 1
       esac
       echo
     ) \
  && (export CONCURRENCY_LEVEL=4 || echo >&2 "
$app: Warning: Could not export CONCURRENCY_LEVEL=4,
thus using default (slower) compilation method.
") \
  && make-kpkg clean \
  && make-kpkg --append-to-version -`date +%Y%m%d.%H%M%S%z` \
       kernel_image modules_image
