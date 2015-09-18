#!/bin/bash -x
#
# Oracle VM VirtualBox
# VirtualBox Makeself installation starter script
# for Linux Guest Additions

#
# Copyright (C) 2006-2015 Oracle Corporation
#
# This file is part of VirtualBox Open Source Edition (OSE), as
# available from http://www.virtualbox.org. This file is free software;
# you can redistribute it and/or modify it under the terms of the GNU
# General Public License (GPL) as published by the Free Software
# Foundation, in version 2 as it comes in the "COPYING" file of the
# VirtualBox OSE distribution. VirtualBox OSE is distributed in the
# hope that it will be useful, but WITHOUT ANY WARRANTY of any kind.
#

# This is a stub installation script to be included in VirtualBox Makeself
# installers which removes any previous installations of the package, unpacks
# the package into the filesystem (by default under /opt) and starts the real
# installation script.
#
PATH=$PATH:/bin:/sbin:/usr/sbin

# Note: These variable names must *not* clash with variables in $CONFIG_DIR/$CONFIG!
PACKAGE="VBoxGuestAdditions"
PACKAGE_NAME="VirtualBox Guest Additions"
ROUTINES="routines.sh"
INSTALLATION_VER="5.0.0"
INSTALLATION_REV="101573"
BUILD_TYPE="release"
USERNAME="vbox"

INSTALLATION_DIR="/opt/$PACKAGE-$INSTALLATION_VER"
CONFIG_DIR="/var/lib/$PACKAGE"
CONFIG="config"
# CONFIG_FILES="filelist"
# SELF=$1
LOGFILE="/var/log/$PACKAGE.log"

. "./$ROUTINES"

check_root
create_log "$LOGFILE"

# Create a symlink in the filesystem and add it to the list of package files
add_symlink()
{
    self=add_symlink
    ## Parameters:
    # The file the link should point to
    target="$1"
    # The name of the actual symlink file.  Must be an absolute path to a
    # non-existing file in an existing directory.
    link="$2"
    link_dir="`dirname "$link"`"
    test -n "$target" ||
        { echo 1>&2 "$self: no target specified"; return 1; }
    test -d "$link_dir" ||
        { echo 1>&2 "$self: link directory $link_dir does not exist"; return 1; }
    test ! -e "$link" ||
        { echo 1>&2 "$self: link file "$link" already exists"; return 1; }
    expr "$link" : "/.*" > /dev/null ||
        { echo 1>&2 "$self: link file name is not absolute"; return 1; }
    rm -f "$link"
    ln -s "$target" "$link"
    # echo "$link" >> "$CONFIG_DIR/$CONFIG_FILES"
}

# Create symbolic links targeting all files in a directory in another
# directory in the filesystem
link_into_fs()
{
    ## Parameters:
    # Directory containing the link target files
    target_branch="$1"
    # Directory to create the link files in
    directory="$2"
    for i in "$INSTALLATION_DIR/$target_branch"/*; do
        test -e "$i" &&
            add_symlink "$i" "$directory/`basename $i`"
    done
}

# Find the most appropriate libary folder by seeing which of the candidate paths
# are actually in the shared linker path list and choosing the first.  We look
# for Debian-specific paths first, then LSB ones, then the new RedHat ones.
libs=`ldconfig -v 2>/dev/null | grep -v ^$'\t'`
lib_candidates="/usr/lib/x86_64-linux-gnu /usr/lib64 /usr/lib /lib64 /lib"
for i in $lib_candidates; do
  if echo $libs | grep -q $i; then
    lib_path=$i
    break
  fi
done
if [ ! -x "$lib_path" ]; then
  info "Unable to determine correct library path."
  exit 1
fi

mkdir -p -m 755 "$CONFIG_DIR"
mkdir -p -m 755 "$INSTALLATION_DIR"

cp -r . "$INSTALLATION_DIR"

cat > "$CONFIG_DIR/$CONFIG" << EOF
# $PACKAGE installation record.
# Package installation directory
INSTALL_DIR='$INSTALLATION_DIR'
# Additional installation modules
INSTALL_MODULES_DIR='$INSTALLATION_MODULES_DIR'
INSTALL_MODULES_LIST='$INSTALLATION_MODULES_LIST'
# Package uninstaller.  If you repackage this software, please make sure
# that this prints a message and returns an error so that the default
# uninstaller does not attempt to delete the files installed by your
# package.
UNINSTALLER='$UNINSTALL'
# Package version
INSTALL_VER='$INSTALLATION_VER'
INSTALL_REV='$INSTALLATION_REV'
# Build type and user name for logging purposes
BUILD_TYPE='$BUILD_TYPE'
USERNAME='$USERNAME'
EOF

# Set symlinks into /usr and /sbin
link_into_fs "bin" "/usr/bin"
link_into_fs "sbin" "/usr/sbin"
link_into_fs "lib" "$lib_path"
add_symlink "$INSTALLATION_DIR/lib/$PACKAGE" /usr/lib/"$PACKAGE"
link_into_fs "share" "/usr/share"
link_into_fs "src" "/usr/src"


# Install, set up and start init scripts
for i in "$INSTALLATION_DIR/init/"*; do
  if test -r "$i"; then
    install_init_script "$i" "`basename "$i"`" 2>> "${LOGFILE}"
    addrunlevel "`basename "$i"`" 2>> "${LOGFILE}"
    grep -q '^# *setup_script *$' "${i}" && "${i}" setup 1>&2 2>> "${LOGFILE}"
    start_init_script "`basename "$i"`" 2>> "${LOGFILE}"
  fi
done
