#!/bin/bash

app=${0##*/}

# rm linux
# ln -s linux-2.6.*/ linux

installed ()
{
  dpkg -l "$1" 2>/dev/null | grep ^.i >/dev/null 2>&1
}

install_package ()
{
  [ ! "$updated" -a ! "$asked_for_aptitude" ] && aptitude update
  if [ $? -eq 0 -a ! "$asked_for_aptitude" ]; then
    updated='yes'
    aptitude install "$1"
  elif [ ! "$asked_for_aptitude" ]
    if ! installed aptitude; then
      read -r -s -p "\
\`aptitude' is preferred as package manager above \'apt-get' (e.g. it has
debfoster's functionality, but integrates into the apt environment), but
it appears not to be installed.  Install \`aptitude' now [Y/n]? " \
           -n 1
      asked_for_aptitude='yes'
      
      case $REPLY in
        [Nn]) ;;
        *)
          if install_package aptitude
      esac
      
    apt-get update
    if [ $? -eq 0 ]; then
      read -r -s -p "\
$app: \`apt-get update' failed.  This could mean the following
\`apt-get install $2 fails, too, due to obsolete package information.
Continue anyway [y/N]? " -n 1
      case
        [Yy]) ;;
        *)
         return 1
      esac
    fi
    if ! apt-get install aptitude; then
      echo "$app: aptitude install failed, attempting reinstall."
      if apt-get --reinstall install aptitude; then
        if ! install_ketchup; then
        fi
      fi
    fi
  fi
    
    case $REPLY in
      [Nn])
        echo $REPLY
        exit 1;;
      *)
        echo Y
    esac
    echo
    
  else
    return 1
  fi
}

required_install ()
{
  if ! installed "$1"; then
    read -r -s -p "\
\`$1' is required${2:+ (i$2)},
but it appears not to be installed.  Install it now [Y/n]? " \
         -n 1
    case $REPLY in
      [Nn])
        echo $REPLY
        return 1;;
      *)
        echo Y
    esac
    echo

    if ! install_package "$1"; then
      echo >&2 "\
$app: All attempts to install ketchup have failed.
Sorry, you need to make your kernel manually."
      return 1
    fi
  fi

  return 0
}

if required_install ketchup "to detect and obtain the latest kernel source"
then

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
          fi
        fi
      fi
    fi
  fi
fi

latest=`ketchup -s ${1:-2.6}`

ketchup -a /Downloads/os/GNU_Linux/kernel/ -d linux/ -r ${1:-2.6} \
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
     )

if [ $? -eq 0 ]; then
  if ! installed kernel-package; then
    read -r -s -p "\
\`kernel-package' is required (to detect and obtain the latest kernel source),
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
    
  fi

  export CONCURRENCY_LEVEL=4 || echo >&2 "\
$app: Warning: Could not export CONCURRENCY_LEVEL=4,
thus using default (slower) compilation method."
  make-kpkg clean \
  make-kpkg --append-to-version -`date +%Y%m%d.%H%M%S%z` \
    kernel_image modules_image
