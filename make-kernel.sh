#!/bin/bash

if [ "$1" = '64' ] || [ "$(uname -m)" = 'x86_64' ]; then
  [ "$1" = '64' ] && shift
  arch='amd64'
fi

minor=${1:-3.4}
shift
options=$*
append_to_version="-pe${arch:+-$arch}"
archive_dir='/Downloads/sys/GNU/kernel'
build_date="$(date +%Y%m%d.%H%M%S%z)"
revision=$build_date

## functions (must be on top by bash 4.1.5 law)

. dialog_func

warn_root ()
{
  msg=$(printf '%s' "
Apparently you are root.

DO NOT configure or compile as root unless you really know what you
are doing, i.e. if you want to allow makefiles wreaking havoc with
your running system!  Compile as a user in the \`src' group instead,
which currently includes: $(awk -F ':' '/^src:/ {print $4}' /etc/group).

After you have configured or compiled a kernel as root, you may neither
be able to compile it nor clean the kernel source tree as a \`src' user
without previous \`chown -R \$user.src linux/'.  (Did I already say that
compiling as root is an incredibly bad idea?)

You have been warned.
" | fmt)
#  dialog_confirm "$msg" "Warning"
#  exit

  echo "$msg" 
  read -r -s -p 'Continue anyway (AT YOUR OWN RISK!) [y/N]? ' \
       -n 1
  case $REPLY in
    [Yy])
      echo $REPLY
      unset fakeroot
      ;;
    *)
      printf "N\n\n"
      exit 1
  esac
}

check_fakeroot ()
{
  fakeroot=$(which fakeroot)
  [ -z "$fakeroot" ] &&
  {
    echo "
You are not root (which is good) but fakeroot(1) is not on the PATH.
Unlike sudo(1), \`fakeroot' allows only actions that require root
privileges (such as building kernel packages) to run in a privileged
environment.

You may continue anyway AT YOUR OWN RISK (all make(1) scripts will be
executed with root privileges!)  Instead of \`fakeroot', \`sudo' will
be called where necessary, so you need to make sure it is installed and
sudoers(5) is properly configured.

It is strongly recommended to abort now, install \`fakeroot', and
try again.
" | fmt

    local REPLY
    read -r -s -p "Continue without \`fakeroot' [y/N]? " -n 1 REPLY
    case $REPLY in
      [Yy])
        echo $REPLY
        fakeroot=$(which sudo)
        if [ -z "$fakeroot" ]; then
          printf "Sorry, sudo(1) is not on the PATH either.  Abort.\n\n"
          exit 1
        fi
        ;;
      *)
        printf "N\n\n"
        exit 1
    esac
  }
}

## FIXME:
## something is suddenly wrong with this function (Debian unstable problem?)
cmd_msg ()
{
  local msg=$1
  local cmd=$2
  local success=${3:-done.}
  [ -n "$4" ] && local failure=$4

  printf "%s" "$msg"
  local out=$($cmd 2>&1)
  local exit_status=$?
  
  if [ $exit_status -eq 0 ]; then
    echo "$success"
  else
    echo >&2 "${failure:-$out}"
  fi

  return $exit_status
}

update_symlink ()
{
  if [ "$(readlink linux)" != "${source_dir}" ]; then
    rm linux
    ln -sv "${source_dir}" linux
  fi
}

kernel_update ()
{
  select sel2 in $(printf "Read Changelog of %s\nUpdate to/Configure %s (backup possible)\nReturn to main menu" "$ketchup_latest" "$ketchup_latest")
  do
    echo >&2
    case $sel2 in
      Read*)
        wget -O - "http://www.kernel.org/pub/linux/kernel/v$minor/\
ChangeLog-$ketchup_latest" | vim -R -
        ;;

      Update*)
        source_dir=$(echo "$sorted_dirs" | grep "linux-$list_minor" | head -n 1 |
                    sed 's/\/$//')
        
        if [ -n "$source_dir" ]; then
#update_symlink
          current_local=$(
              awk -F ': ' '/Linux kernel version:/ { print $2 }' \
                  linux/.config \
            | awk -F - '{print $1}'
          )
      
          [ "$ketchup_latest" != "$current_local" ] \
            && (
# Allow to skip backup.  For example, in case we have downloaded
# but not compiled an older version, and just want to use the
# new one instead.
                 read -r -s -p "$(printf 'Back up existing kernel source tree [Y/n]? ' \
                   | fold -s)" \
                      -n 1
                 case $REPLY in
                   [Nn])
                     printf "%s\n\nUpdating without backup.\n" "$REPLY"
                     ;;
                   *)
                     printf "Y\n\nBacking up existing kernel source tree ..."
                     backup_dir="${source_dir}.bak" 
                     if [ -d "$backup_dir" ]; then
                       read -r -s -p "$(echo "Backup exists.  Replace [y/N]? " \
                         | fold -s)" \
                             -n 1
                       case $REPLY in
                         [Yy])
                           printf "%s\n\nReplacing backup ... " "$REPLY"
                           rm -r  "$backup_dir"
                           ;;
                         *)
                           echo N
                           read -r -s -p "$(echo "Continue with OLD backup? [y/N]? " | fold -s)" \
                                 -n 1
                           case $REPLY in
                             [Yy])
                               ;;
                             *)
                               printf "N\n\n"
                               exit 1
                           esac
                       esac
                     fi

# TODO: Copying the whole tree with cp is very slow.
#       We really have to use tar or g(un)zip here.
                     [ $? -eq 0 ] && cp -a "$source_dir" "$backup_dir"
                     [ $? -eq 0 ] && printf " done.\n"
                 esac
               ) \
            && cd "$source_dir" \
            && {
                printf "Cleaning kernel source tree ...\n"
                make-kpkg --rootcmd $fakeroot clean
                } \
            && cd .. \
            && cleaned=1
        else
          source_dir="linux-$minor"
        fi

        printf '\nAttempting kernel source update with ketchup ...'

        if [ -n "$ketchup_latest" ]; then
          ketchup --archive "${archive_dir}"/ \
                  --directory "${source_dir}" \
                  --rename-directory \
                  $ketchup_latest \
            && {
#if [ "$source_dir" != "linux-$ketchup_latest" ]; then
#  rm linux && ln -s "linux-$ketchup_latest" linux
#fi
                [ -n "$backup_dir" ] && mv "$backup_dir" "$source_dir"
                } \
            && {
              latest=$ketchup_latest
              source_dir="linux-$latest"
            }
          echo
        fi

        break 2;;

      Return*)
        continue 2;;
    esac
  done
}

kernel_extract ()
{
  source_dir=${sel%.t*z*}

  if [ -d "${source_dir}" ]; then
    echo >&2 "The directory ${source_dir} exists.
It may contain newer source code than in archive $sel."
  fi

  read -r -s -p "$(echo "
Extract archive (existing code is preserved) [y/N]? " |
                    fold -s)" \
        -n 1
  case $REPLY in
    [Yy])
      printf "%s\n" "$REPLY"
      if [ -d "${source_dir}" ]; then
        printf 'Moving existing directory out of the way ... '
        mv ${source_dir}{,-old}
        [ $? -eq 0 ] && echo 'done.'

        cleaned=1
      fi
        
      if [ $? -eq 0 ]; then
        printf 'Extracting archive ... '
        if [ -z "${sel##*gz*}" ]; then
          tar -xjf "$sel"
        elif [ -z "${sel##*xz*}" ]; then
          tar -xJf "$sel"
        fi
        [ $? -eq 0 ] && echo 'done.'
      fi
      ;;
    *)
      echo N
  esac

#update_symlink
  latest=${source_dir##*-}
}

reconfigure ()
{
  (
    if [ ! -s .config ]; then
      boot_config=/boot/config-$(uname -r)
      if [ -s ../.config ]; then
        printf 'Restoring .config from backup (../.config) ... ' 
        cp -Lp ../.config ./
      elif [ -s /proc/config.gz ]; then
        printf 'Restoring .config from /proc/config.gz ... ' 
        cp -Lp /proc/config.gz ./
      elif [ -s "$boot_config" ]; then
        printf 'Restoring .config from %s ...' "$boot_config"
        key_path=$(awk -F '=' '$1 ~ /CONFIG_SYSTEM_TRUSTED_KEYS/ {print $2}' "$boot_config")
        key_path=${key_path#\"}
        key_path=${key_path%\"}
        if [ -n "$key_path" ] && [ ! -f "$key_path" ]; then
          printf '\
  Key path "%s" specified in %s not found.
  Configuring for use with one-time key ... ' "$key_path" "$boot_config"
          sed 's/^\(CONFIG_MODULE_SIG_\(ALL\|KEY\)=\|CONFIG_SYSTEM_TRUSTED_KEYS=\)/#\1/g' \
            "$boot_config" > .config
          [ $? -eq 0 ] && echo 'done.'
        else
          cp -Lp "$boot_config" ./
        fi
      fi
      [ $? -eq 0 ] && echo 'done.'
    elif [ -s .config ]; then
      echo "Backing up .config to ../.config-${minor}-${revision} ... " |
        fold -s
      cp -Lp .config ../.config-${minor}-${revision}
      [ $? -eq 0 ] && echo 'done.'
    fi
  ) \
  && (
      echo
      
      make xconfig || make menuconfig || make config

      if diff -q .config "../.config-${minor}-${revision}" 2>/dev/null; then
        printf '.config unchanged, removing unnecessary backup ... '
        rm ../.config-${minor}-${revision}
        [ $? -eq 0 ] && echo 'done.'
      fi
    )
}

prepare_modules ()
{
  echo "$REPLY


Move the source tree of user defined modules that should be compiled for
the new kernel into \`/usr/src/modules'.  The directory will be created if
it did not already exist; it is used later by \`make-kpkg modules_image'.
Use C-d or type \`exit' to continue.
" | fmt
  mkdir -p /usr/src/modules && cd /usr/src/modules
  /bin/bash -i
}

build_and_install ()
{
  export CONCURRENCY_LEVEL=4 \
  && (
      if [ $cleaned -eq 0 ]; then
        msg="Clean kernel and modules source tree before (say Yes only if you removed
modules or build a new kernel)"
        if [ $dialog ]; then
          dialog_confirm "${msg}?"
          case $? in
            0) REPLY='Y';;
            *) REPLY='N'
          esac
        else
          read -r -s -p "$(echo "
$msg [yes/No/cancel]? " | fold -s)" \
                -n 1
        fi

        case $REPLY in
          [Cc])
            exit 1;;

          [Yy])
            if [ ! $dialog ]; then
              printf "%s\n\n" "$REPLY"
            fi
            make-kpkg --rootcmd $fakeroot clean && cleaned=1;;

          *)
            if [ ! $dialog ]; then
              echo N
            fi
        esac
      fi
     ) \
  && (
       echo

## NOTE: $append_to_version in uname -r, $revision in dpkg -l
## (works around Eclipse version detection bug);
## bash bug expands ${param:+foo bar} to quoted string -> unknown option
## worked around with $1 = '64'
set -x
       if [ "$arch" ]; then
         DEB_HOST_ARCH=$arch nice -- \
           make-kpkg \
             --rootcmd $fakeroot \
             --initrd \
             --cross-compile - \
             --arch "$arch" \
             --revision ${revision} \
             --append-to-version ${append_to_version} \
             $options \
             kernel_image modules_image
       else
         nice -- \
           make-kpkg \
             --rootcmd $fakeroot \
             --initrd \
             --revision ${revision} \
             --append-to-version ${append_to_version} \
             $options \
             kernel_image modules_image
       fi
set +x

## TODO: Display output in scrollable window
       exit_status=$?
       if [ $exit_status -ne 0 ]; then
         echo >&2 'make-kernel: There were errors. Press RETURN to continue.'
         read
         exit $exit_status
       fi
     ) \
  && (
       kernel_version=$(awk '/^# Linux/ {print $3}' "$source_dir/.config")
       read -r -s -p "$(echo "
Install Linux $latest${append_to_version}${revision:+ rv:$revision} now
(current is $current${current_revision:+ rv:$current_revision}) [Y/n]? " \
| fold -s)" \
            -n 1
       case $REPLY in
         [Nn])
           echo $REPLY;;
         *)
           printf "Y\n\n"
## FIXME: Minor 4.9 specified, 4.9.x compiled, cannot install 4.9.x with this script
           cd .. \
             && sudo dpkg -i \
"linux-image-${latest#source-}${append_to_version}_${revision}_i386.deb"
       esac
     )
}

process_sub_selection ()
{
  echo >&2
  case $sel in
    Cancel)
      ;;

    '(Re)configure'*)
      reconfigure
      ;;
    
    Prepare*)
      prepare_modules
      ;;
    
    *)
      build_and_install
  esac
}

process_main_selection ()
{
  echo >&2
  case $sel in
    Cancel)
      ;;

    *.bz2|*.xz)
      ## archive
      kernel_extract
      ;;
    
    */)
      ## directory
      source_dir=${sel%/}
#update_symlink
      latest=${source_dir##*-}
      ;;
  
    *)
      ## kernel.org
      kernel_update
  esac

## FIXME: Changes to wrong directory after backup and update
  cd "$source_dir" \
    && (
        msg="Running Linux $current${current_revision:+ rv:$current_revision}"
        actions=$(printf "%s\n%s\n%s" "(Re)configure Linux $latest" \
          "Prepare modules" \
          "Build Linux $latest${append_to_version}${revision:+ rv:$revision}") 

        if [ $dialog ]; then
          while true
          do
            sel=$(dialog_menu "$msg" "$sel" 0 $actions)

            if [ -z "$sel" ]; then break 1; fi

            process_sub_selection
          done
        else
          while [ "$sel" != 'Cancel' ]
          do
            echo "$msg"
            select sel in $actions 'Cancel'
            do
              process_sub_selection
            done
          done
        fi

      ) \
  && cd -
}

## program

dialog=$(which dialog)
if [ $dialog ]; then
  lines=${lines:-24}
  columns=${columns:-80}
  app_name='make-kernel'
  ver='0.5'
  copy='2012  Thomas Lahn'
  email='linux@PointedEars.de'
  license='GPL v3'
  dialog_backtitle="$app_name $ver - (C) $copy <$email> ($license)"
fi

if [ $(id -u) -eq 0 ]; then
  warn_root
else
  check_fakeroot
fi

cleaned=0

## 1. Determine available versions including archives, sort by version number.
## 2. If more than one version, let user choose version, recommend newer one.
##    a) Version is selected:
##       1. a) Version is archive
##             1. If directory exists ask if it be moved out of the way
##                a) If yes, do so;
##                b) if no, go to 2.a.2.
##             2. Extract archive.
##          b) Version is not archive
##             1. If download necessary, then download with ketchup
##       2. Configure version
##    b) Abort

msg="Determining available kernel versions in /usr/src ..."
current=$(uname -r)
current_revision=$(
  dpkg -l linux-image-$current 2>/dev/null | tail -n 1 | awk '{print $3}')

if [ $dialog ]; then
  dialog_info "$msg" "$backtitle"
else
  printf >&2 "
$msg
running:    "
  printf >&2 "%s%s
kernel.org: " "$current" "${current_revision:+ rv:$current_revision}"
fi

ketchup_latest=$(ketchup -s $minor)
if [ ! $dialog ]; then
  if [ $? -eq 0 ]; then
    echo >&2 $ketchup_latest
  else
    echo >&2 'N/A'
  fi

  printf >&2 "local:      "
fi

## linux-$minor* and linux-source-$minor* directories
cd /usr/src
list_minor=$minor
[ -z "${list_minor##*.*.*}" ] && list_minor=${list_minor%.*}
dirs=$(ls -dF "linux-$list_minor"* "linux-source-$list_minor"* 2>/dev/null | sed -n '/[@/]$/ {s/@$/\//; p}')
sorted_dirs=$(echo "$dirs" | sort -t . -k1,1nr -k2,2nr -k3,3nr -k4,4nr)

## linux-source-$minor* archives
archives=$(ls -dF linux-source-$minor*.t*z* 2>/dev/null | grep -v /)

[ ! $dialog ] && echo $dirs $archives | fold -s >&2 

avail=$(echo "${ketchup_latest:+$ketchup_latest (from kernel.org)}
$dirs
$archives" | sort -t . -k1,1nr -k2,2nr -k3,3nr -k4,4nr)

msg_select='Select the version you wish to configure, or cancel:'

IFS="
"
if [ $dialog ]; then
  while true
  do
    sel=$(dialog_menu "$msg_select" "" 0 $avail)
    
    if [ -z "$sel" ]; then exit; fi

    process_main_selection
  done
else
  while [ "$sel" != 'Cancel' ]
  do
    echo "
${bold}${msg_select}$norm"
    select sel in $(printf "%s\nCancel" "$avail")
    do
      process_main_selection
    done
  done
fi

echo
