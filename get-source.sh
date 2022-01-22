#!/bin/sh
# Copyright 2015-2017  tde-slackbuilds project on GitHub
# All rights reserved.
#
#   Permission to use, copy, modify, and distribute this software for
#   any purpose with or without fee is hereby granted, provided that
#   the above copyright notice and this permission notice appear in all
#   copies.
#
#   THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESSED OR IMPLIED
#   WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
#   MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
#   IN NO EVENT SHALL THE AUTHORS AND COPYRIGHT HOLDERS AND THEIR
#   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
#   LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
#   USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#   ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
#   OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
#   OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
#   SUCH DAMAGE.

getsource_fn ()
{
#!/bin/sh
# Generated by Alien's SlackBuild Toolkit: http://slackware.com/~alien/AST
# Copyright 2009, 2010, 2011, 2012, 2013, 2014, 2015  Eric Hameleers, Eindhoven, Netherlands
# Copyright 2015-2017  Thorn Inurcide USA
# Copyright 2015-2017  tde-slackbuilds project on GitHub
# All rights reserved.
#
#   Permission to use, copy, modify, and distribute this software for
#   any purpose with or without fee is hereby granted, provided that
#   the above copyright notice and this permission notice appear in all
#   copies.
#
#   THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESSED OR IMPLIED
#   WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
#   MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
#   IN NO EVENT SHALL THE AUTHORS AND COPYRIGHT HOLDERS AND THEIR
#   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
#   LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
#   USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#   ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
#   OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
#   OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
#   SUCH DAMAGE.

# Place to build (TMP_BUILD) package (PKG) and output (OUTPUT) the program:
## ### moved to BUILD-TDE.sh to export variables for ocaml, facile, gdl, and double-conversion builds
# ### TMP_BUILD=/tmp/build
PKG=$TMP_BUILD/package-$PRGNAM
# ### OUTPUT=/tmp

# remove any previous builds if option chosen
[[ $KEEP_BUILD != "yes" ]] && [[ $PRE_DOWNLOAD != yes ]] && echo -e "\n removing previous build data .." && rm -rf $TMP_BUILD/{tmp,package}*
# Only create working directories if building packages:
[[ $PRE_DOWNLOAD != yes ]] && {
mkdir -p $OUTPUT
mkdir -p $TMP_BUILD/tmp-$PRGNAM
mkdir -p $PKG
rm -rf $PKG/*
rm -rf $TMP_BUILD/tmp-$PRGNAM/*
rm -rf $OUTPUT/*-$PRGNAM.log
}

# Where do we look for sources?
SRCDIR=$BUILD_TDE_ROOT/src
## SlackBuild source directory for local patches
SB_SRCDIR=$(cd $(dirname $0); pwd)

## for 14.0.11 onwards, check for cmake archive ..
[[ $TDEVERSION == 14.0.11 && ! -s $SRCDIR/cmake-$TDEVERSION.tar.xz ]] && (
    echo -e "\nDownloading to $SRCDIR"
    wget -T 20 -O $SRCDIR/cmake-$TDEVERSION.tar.xz $TDE_MIRROR/releases/R$TDEVERSION/main/common/cmake-trinity-$TDEVERSION.tar.xz
    echo -e "----\n"
)

## if 14.0.11 or misc, download archive:
[[ $TDEVERSION == 14.0.11 || $TDEMIR_SUBDIR == misc ]] && {
## check for and remove any zero byte archive files
[[ ! -s $SRCDIR/$PRGNAM-$VERSION.${ARCHIVE_TYPE:-"tar.xz"} ]] && \
rm $SRCDIR/$PRGNAM-$VERSION.${ARCHIVE_TYPE:-"tar.xz"} 2>/dev/null || true
SOURCE=$SRCDIR/$PRGNAM-$VERSION.${ARCHIVE_TYPE:-"tar.xz"}

# SRCURL for non-TDE archives, set in the SB, will override the Trinity default *tar.xz URL
SRCURL=${SRCURL:-"$TDE_MIRROR/releases/R$VERSION/main$TDEMIR_SUBDIR/$PRGNAM-trinity-$VERSION.tar.xz"}
# Source file availability:
[[ -f $SOURCE ]] && [[ $PRE_DOWNLOAD == yes ]] && echo "  $(basename $SOURCE) already downloaded ..."

if ! [ -f $SOURCE ]; then
  echo "Source '$(basename $SOURCE)' not available yet..."
  # Check if the $SRCDIR is writable at all - if not, download to $OUTPUT
  [ -w "$SRCDIR" ] || SOURCE="$OUTPUT/$(basename $SOURCE)"
  if ! [ "x$SRCURL" == "x" ]; then
    echo -e "\nDownloading to $(dirname $SOURCE)"
    wget -T 20 -O "$SOURCE" "$SRCURL"
    if [ $? -ne 0 -o ! -s "$SOURCE" ]; then
      echo "Downloading '$(basename $SOURCE)' failed... cancelling the build."
      rm -f "$SOURCE"
## set this for BUILD-TDE.sh to stop on failure
      [[ $EXIT_FAIL == "exit 1" ]] && touch $TMPVARS/download-failure
      ${EXIT_FAIL:-":"}
    fi
  else
    echo "File '$(basename $SOURCE)' not available... cancelling the build."
    ${EXIT_FAIL:-":"}
  fi
fi

if [ "$P1" == "--download" ]; then
  echo "Download complete."
  exit 0
fi
} || {
## otherwise, not R14.0.11 or misc, and we are creating/updating git,
## so [1] start with admin/cmake:
[[ $(cat $TMPVARS/DL_CGIT) == yes ]] && {
cd $BUILD_TDE_ROOT/src/cgit

[[ ! -e $TMPVARS/admin-cmake-done ]] && {
## if admin and cmake exist, update them
[[ -d admin ]] && \
(echo "Updating admin ..."
cd admin
git checkout -- *
git pull
## repo is in master - update r14.0.x to latest revision
git fetch origin r14.0.x:r14.0.x)
[[ -d cmake ]] && \
(echo "Updating cmake ..."
cd cmake
git checkout -- *
git pull
git fetch origin r14.0.x:r14.0.x)

## if admin and cmake don't exist, clone them
[[ ! -d admin ]] && git clone https://mirror.git.trinitydesktop.org/gitea/TDE/tde-common-admin admin
[[ ! -d cmake ]] && git clone https://mirror.git.trinitydesktop.org/gitea/TDE/tde-common-cmake cmake

## place a marker so that admin/cmake update or clone only once per run of BUILD-TDE.sh
touch $TMPVARS/admin-cmake-done
}

## if not tde-i18n
## [2] update or clone PRGNAM

[[ $PRGNAM != tde-i18n ]] && {
## get latest commits if the local repository for PRGNAM exists
[[ -d $PRGNAM ]] && \
(echo "Updating $PRGNAM ..."
cd $PRGNAM
git checkout -- *
git pull
git fetch origin r14.0.x:r14.0.x)
## if the local repository for PRGNAM doesn't exist, clone it ..
[[ ! -d $PRGNAM ]] && \
git clone https://mirror.git.trinitydesktop.org/gitea/TDE/$PRGNAM

## if arts/tdelibs, need libltdl
[[ " arts tdelibs " == *$PRGNAM* ]] && {
[[ -d libltdl ]] && \
(echo "Updating libltdl ..."
cd libltdl
git checkout -- *
git pull
git fetch origin r14.0.x:r14.0.x)

[[ ! -d libltdl ]] && \
git clone https://mirror.git.trinitydesktop.org/gitea/TDE/libltdl
}

## if tdenetwork, need libtdevnc, but not yet for 14.0.x==14.0.11[?] which uses krfb/libvncserver
[[ " tdenetwork " == *$PRGNAM* ]] && {
[[ -d libtdevnc ]] && \
(echo "Updating libtdevnc ..."
cd libtdevnc
git checkout -- *
git pull
# git fetch origin r14.0.x:r14.0.x
)

[[ ! -d libtdevnc ]] && \
git clone https://mirror.git.trinitydesktop.org/gitea/TDE/libtdevnc
}

true # prevent the following i18n download (attempts) if this routine fails
} || {
## still creating/updating git
## so [3] for tde-i18n-$lang:

## Use wget to download the required i18n repos to avoid the ~1x10^6 byte download for the full tde-i18n
## - same for both creating and updating

cd tdei18n
# ### will download the template, translations, and tde-i18n-$lang modules to:
# ### $BUILD_TDE_ROOT/src/cgit/tdei18n/cgit/tde-i18n/plain/...
wget -m --no-parent --no-host-directories https://mirror.git.trinitydesktop.org/cgit/tde-i18n/plain/translations/desktop_files/entry.desktop/entry.desktop.pot
rm -rf cgit/tde-i18n/plain/template
wget -m --no-parent --no-host-directories https://mirror.git.trinitydesktop.org/cgit/tde-i18n/plain/template/

for lang in $I18N
do
## remove the previous repo to avoid build failures caused by any unused old files
rm -rf cgit/tde-i18n/plain/tde-i18n-$lang
wget -m --no-parent --no-host-directories https://mirror.git.trinitydesktop.org/cgit/tde-i18n/plain/tde-i18n-$lang/
wget -m --no-parent --no-host-directories https://mirror.git.trinitydesktop.org/cgit/tde-i18n/plain/translations/desktop_files/entry.desktop/$lang.po || true # in case it doesn't exist
done
cd ..
}
}
}

## Installation RPATH:
## Set this to ensure TDE libs have priority when installed
## For tqt3, the configure -R option is used
## Add -Wl,-rpath for gcc/g++ -
## - use --disable-rpath in autotools builds to avoid paths set by configure
## - double quote $SLK[R]CFLAGS with cmake in the SBs for it to recognize the whole string
INST_RPATH="$TQTDIR/lib$LIBDIRSUFFIX"
[[ $TQTDIR != $INSTALL_TDE ]] && INST_RPATH="$INST_RPATH:$INSTALL_TDE/lib$LIBDIRSUFFIX"
SLKCFLAGS="-O2 ${NO_WARN:-} ${SET_march:-}" # for Misc and libart-lgpl
SLKRCFLAGS="$SLKCFLAGS -Wl,-rpath,'$INST_RPATH'" # for TQt/TDE
[[ $ARCH == x86_64 ]] && \
SLKCFLAGS="$SLKCFLAGS -fPIC" && \
SLKRCFLAGS="$SLKRCFLAGS -fPIC"

# Exit the script on errors:
set -e
trap 'echo "$0 FAILED at line $LINENO"' ERR
# Catch unitialized variables:
set -u
P1=${1:-1}

# Save old umask and set to 0022:
_UMASK_=$(umask)
umask 0022

[[ $PRE_DOWNLOAD == yes ]] && exit || true # need true to override exit 1 if 'PRE_DOWNLOAD != yes'
}

untar_fn ()
{
cd $TMP_BUILD/tmp-$PRGNAM
##
## [1] firstly test for R14 or misc ..
##
[[ $TDEVERSION == 14.0.11 || $TDEMIR_SUBDIR == misc ]] && {
## unpack R14 or misc
echo -e "\n unpacking $(basename $SOURCE) ... \n"
tar -xf $SOURCE
[[ $TDEMIR_SUBDIR != misc ]] && (
cd $PRGNAM*
tar -xf $SRCDIR/cmake-$TDEVERSION.tar.xz
mv cmake-trinity-$TDEVERSION cmake
)

: # if this fails, don't try a git build, and go to [3]

} || {

## [2] not 14.0.11 nor misc, so must be git ..
[[ $TDEVERSION == 14.1.0 ]] && DEV_BRANCH=master || DEV_BRANCH=r14.0.x

## copy git content to build area:
(
cd $BUILD_TDE_ROOT/src/cgit/$PRGNAM/
echo -e "\n copying $PRGNAM git sources to build area ... \n"
## remove any old .git/worktrees records - only being used here as a build source
rm -rf .git/worktrees/*
## use FEAT as a command line option to checkout any other development branch ..
## .. plus FEATa for admin, FEATc for cmake if required
git worktree add -f $TMP_BUILD/tmp-$PRGNAM/$PRGNAM/ ${FEAT:-$DEV_BRANCH}

## work-around for some cr*p in admin in the r14.0.x branch of tdeio-locate
## it's a cmake build, so admin isn't needed
[[ $PRGNAM != tdeio-locate ]] && {
cd ../admin
echo -e "\n copying admin git sources to build area ... \n"
rm -rf .git/worktrees/*
git worktree add -f $TMP_BUILD/tmp-$PRGNAM/$PRGNAM/admin/ ${FEATa:-$DEV_BRANCH}
}

cd ../cmake
echo -e "\n copying cmake git sources to build area ... \n"
rm -rf .git/worktrees/*
git worktree add -f $TMP_BUILD/tmp-$PRGNAM/$PRGNAM/cmake/ ${FEATc:-$DEV_BRANCH}

[[ " arts tdelibs " == *$PRGNAM* ]] && {
cd ../libltdl
echo -e "\n copying libltdl git sources to build area ... \n"
rm -rf .git/worktrees/*
git worktree add -f $TMP_BUILD/tmp-$PRGNAM/$PRGNAM/libltdl/ $DEV_BRANCH
}

[[ " tdenetwork " == *$PRGNAM* && $TDEVERSION != 14.0.x ]] && {
cd ../libtdevnc/
echo -e "\n copying libtdevnc git sources to build area ... \n"
rm -rf .git/worktrees/*
git worktree add -f $TMP_BUILD/tmp-$PRGNAM/$PRGNAM/libtdevnc/ $DEV_BRANCH
}
echo # if this fails, SlackBuild will fail from [3]
)
}
#
## [3] finally, cd into source directory
#
cd $PRGNAM*
}

listdocs_fn ()
{
DOCDIR=$PWD # this is set for installdocs_fn
DOCS=$(for file in AUTHORS* rfc4791.pdf ChangeLog* COPYING* CreatingThemes FAQ* HOWTO INSTALL* KNOWNBUGS* LICEN?E* NEWS* *README{$,.md,^[\.*\.txt],/}* ^[README]*.txt ${RM_LIST:-} ${KEYS_LIST:-} TODO* *.lsm PKG-INFO doc/licenses/* doc/FAQ.txt REMARKS ; do [[ -s $file ]] && ls -1 $file;done ) || true
}

chown_fn ()
{
chown -R root:root .
chmod -R u+w,go+r-w,a+rX-st .
}

ltoolupdate_fn ()
{
## edit hard coded tqt directory for tqt3/tqtinterface installed to TQTDIR [!= /usr]
sed -i "s|/usr/include/tqt\"|$TQTDIR/include/tqt\"|" admin/acinclude.m4.in
sed -i "s|/usr/include/tqt3|$TQTDIR/include/tqt|" admin/acinclude.m4.in
## edit hard coded plugins installation directories - could be 'tde'
sed -i "s|trinity|$PLUGIN_INSTALL_DIR|g" admin/acinclude.m4.in

cp /$(grep -h ltmain.sh /var/log/packages/libtool*) admin/
cp /$(grep -h libtool.m4 /var/log/packages/libtool*) admin/libtool.m4.in
cp /$(grep -h missing /var/log/packages/libtool*) admin/

make -f admin/Makefile.common
}

cd_builddir_fn ()
{
mkdir -p build-$PRGNAM
cd build-$PRGNAM
}

make_fn ()
{
[[ -s build.ninja ]] && {
MAKE_PRG=ninja && [[ ${VERBOSE:-} == 1 ]] && MAKE_PRG='ninja -v'
} || {
[[ ${VERBOSE:-} == 1 ]] && MAKE_PRG='make --debug=b'
}
${MAKE_PRG:-make} ${NUMJOBS:-} || exit 1
DESTDIR=$PKG ${MAKE_PRG:-make} install || exit 1
}

installdocs_fn ()
{
[[ $INSTALL_TDE != "/usr/local" ]] && [[ $TDEMIR_SUBDIR == misc || $PRGNAM == libart-lgpl ]] && INSTALL_TDE=/usr
mkdir -p $PKG$INSTALL_TDE/doc/$PRGNAM-$VERSION
(cd ${DOCDIR:-};cp -a --parents ${DOCS:-} $PKG$INSTALL_TDE/doc/$PRGNAM-$VERSION) || true # DOCDIR might not exist
chown -R root:root $PKG$INSTALL_TDE/doc/$PRGNAM-$VERSION
find $PKG$INSTALL_TDE/doc -type f -exec chmod 644 {} \;
}

mangzip_fn ()
{
[[ ! -d $PKG$INSTALL_TDE/man ]] && true || { # true == don't let the SB fail if there are no man pages ..
  find $PKG$INSTALL_TDE/man -type f -name "*.?" -exec gzip -9f {} \;
  for i in $(find $PKG$INSTALL_TDE/man -type l -name "*.?") ; do ln -s $( readlink $i ).gz $i.gz ; rm $i ; done
} # .. but let the SB fail if there is a problem with the gzipping
}

strip_fn ()
{
find $PKG | xargs file | grep -e "executable" -e "shared object" | grep ELF \
  | cut -f 1 -d : | xargs strip --strip-unneeded 2> /dev/null || true
}

mkdir_install_fn ()
{
mkdir -p $PKG/install
}

makepkg_fn ()
{
cd $PKG
[[ ! $ARM_FABI ]] || { [[ $ARM_FABI == hard ]] && ARCH=${ARCH}_hf || ARCH=${ARCH}_sf
}
makepkg --linkadd y --chown n $OUTPUT/$PRGNAM-$VERSION-$ARCH-$BUILD.${PKGTYPE:-txz} 
cd $OUTPUT
md5sum $PRGNAM-$VERSION-$ARCH-$BUILD.${PKGTYPE:-txz} > $PRGNAM-$VERSION-$ARCH-$BUILD.${PKGTYPE:-txz}.md5
cat $PKG/install/slack-desc | grep "^$PRGNAM" | grep -v handy > $OUTPUT/$PRGNAM-$VERSION-$ARCH-$BUILD.txt

# Restore the original umask:
umask ${_UMASK_}
}


## paths in doinst.sh should be relative to allow for installation to ROOT != "/"
doinst_sh_fn ()
{
echo "
# Update the desktop database:
/usr/bin/update-desktop-database .$INSTALL_TDE/share/applications

# Update hicolor theme cache:
/usr/bin/gtk-update-icon-cache -f -t .$INSTALL_TDE/share/icons/hicolor

# Update the mime database:
/usr/bin/update-mime-database -Vn usr/share/mime
" >> $PKG/install/doinst.sh
}

libpng16_fn ()
{
(cd /usr/bin
ln -sf libpng16-config libpng-config )
(cd /usr/include
ln -sf libpng16/pngconf.h pngconf.h
ln -sf libpng16/png.h png.h )
(cd /usr/lib$LIBDIRSUFFIX/pkgconfig
ln -sf libpng16.pc libpng.pc )
(cd /usr/lib$LIBDIRSUFFIX
ln -sf libpng16.so libpng.so
ln -sf libpng16.la libpng.la )
}
