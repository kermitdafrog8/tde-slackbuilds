#!/bin/sh

## suppress error messages
exec 2>/dev/null

export TMPVARS=/tmp/build/vars
if [ ! -d $TMPVARS ]; then
  mkdir -p $TMPVARS
fi

## remove marker for git admin/cmake to update or clone only once per run of this script
rm -f $TMPVARS/admin-cmake-done

dialog --cr-wrap --no-shadow --colors --title " Introduction " --msgbox \
"
 This is the set up script for TDE SlackBuilds on Slackware 14.2/current for setting user preferences and options.

 Source archives must be placed in the 'src' directory or will be downloaded during the build from a geoIP located mirror site.

 A package build list is created, and successfully built and installed packages are removed from that list as the build progresses.

 US English is the default language and support for additional languages can be added.

 There is an option to abort the build on the final setup screen - so just run through the options and familiarize yourself with them before an actual build. " \
21 75


rm -f $TMPVARS/build-new
dialog --cr-wrap --yes-label "Re-use" --no-label "New" --defaultno --no-shadow --colors --title " TDE Build " --yesno \
"
Select \Zr\Z4\ZbNew\Zn if:
               This is a new build - OR
               Additional packages are being built
\Zr\Z4\ZbNew\Zn will delete any previous build list.

Selecting <\Z1R\Zb\Z0e-use\Zn> avoids having to create the build list again when re-running the build for any SlackBuilds that failed." \
13 75
[[ $? == 0 ]] && echo no > $TMPVARS/build-new
[[ $? == 1 ]] && rm -f $TMPVARS/TDEbuilds


build_core()
{
# Copyright 2012  Patrick J. Volkerding, Sebeka, Minnesota, USA
# All rights reserved.
#
# Copyright 2014 Willy Sudiarto Raharjo <willysr@slackware-id.org>
# All rights reserved.
#
# Copyright 2015-2017 Thorn Inurcide
# Copyright 2015-2017 tde-slackbuilds project on GitHub
#
# Based on the xfce-build-all.sh script by Patrick J. Volkerding
#
# Redistribution and use of this script, with or without modification, is
# permitted provided that the following conditions are met:
#
# 1. Redistributions of this script must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
#  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
#  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO
#  EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
#  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
#  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
#  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
#  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# These need to be set here:
export INST=${INST:-1}
TMP=${TMP:-/tmp}
export LIBPNG_TMP=$TMP
export BUILD_TDE_ROOT=$(pwd)


###################################################

# set the shell variables needed for the build
#

run_dialog()
{
rm -f $TMPVARS/TDEVERSION
dialog --cr-wrap --nocancel --no-shadow --colors --title " TDE Version " --menu \
"
Set the version of TDE to be built.
 
" \
12 75 2 \
"14.0.7" "the R14.0.7 release - source from archives" \
"cgit" "R14.1.0 development - source from Trinity git" \
2> $TMPVARS/TDEVERSION


rm -f $TMPVARS/INSTALL_TDE
dialog --cr-wrap --nocancel --no-shadow --colors --title " TDE Installation Directory " --menu \
"
Select the directory that TDE is to be installed in.

Any other option will have to be edited into BUILD-TDE.sh 
 
" \
15 75 3 \
"/opt/trinity" "" \
"/opt/tde" "" \
"/usr" "" \
2> $TMPVARS/INSTALL_TDE


rm -f $TMPVARS/SYS_CNF_DIR
dialog --cr-wrap --nocancel --no-shadow --colors --title " TDE System Configuration " --menu \
"
Select the directory that the TDE System Configuration files should be installed in.

Selecting '/etc/tde' will also set TDEHOME=~/.tde and TDEROOTHOME=/root/.tde,
otherwise the defaults of TDEHOME=~/.trinity and TDEROOTHOME=/root/.trinity will apply.
 
" \
18 75 2 \
"/etc/trinity" "" \
"/etc/tde" "" \
2> $TMPVARS/SYS_CNF_DIR


rm -f $TMPVARS/COMPILER
dialog --cr-wrap --nocancel --no-shadow --colors --title " Compiler " --menu \
"
Choose which compiler to use.
 
" \
12 75 2 \
"gcc" "gcc/g++" \
"clang" "clang/clang++" \
2> $TMPVARS/COMPILER


rm -f $TMPVARS/SET_MARCH
rm -f $TMPVARS/ARCH
#
## get the march/mtune options built into gcc to show as an option in the README
GCC_MARCH=$(gcc -Q -O2 --help=target | grep -E "^  -march=|^  -mtune=" | tr -d [:blank:])
#
## what ARCH?
[[ $(getconf LONG_BIT) == 64 ]] && \
echo x86_64 > $TMPVARS/ARCH || \
{ [[ $GCC_MARCH == *armv* ]] && echo arm > $TMPVARS/ARCH
} \
|| echo i586 > $TMPVARS/ARCH
ARCH=$(cat $TMPVARS/ARCH)
#
## if ARCH=arm, add mfpu
[[ $ARCH == arm ]] && GCC_MARCH=$(gcc -Q -O2 --help=target | grep -E "^  -m" | grep -E "arch=|tune=|fpu=" | tr -d [:blank:])
#
## get the native march/mtune options
NATIVE_MARCH=$(echo $(gcc -Q -O2 -march=native --help=target | grep -E "^  -march=|^  -mtune=" | tr -d [:blank:]))
## Slackware 14.2 gcc 5.3.1 fails on this, [*** Error in `gcc': double free or corruption (top): 0x00308b50 ***], so:
NATIVE_MARCH=${NATIVE_MARCH:-"unknown"}
#
## get the default march/mtune options for a 64-bit build from the gcc configuration
[[ $ARCH == x86_64 ]] && DEFAULT_MARCH=$GCC_MARCH
## set the default march etc. options for RPi3 overriding the gcc configuration
[[ $ARCH == arm ]] && DEFAULT_MARCH="-march=armv8-a+crc -mtune=cortex-a53 -mfpu=neon-fp-armv8"
## set the default march/mtune options for i586 and tune for i686 overriding the gcc configuration
[[ $ARCH == i586 ]] && DEFAULT_MARCH="-march=i586 -mtune=i686"
#
## run dialog
EXITVAL=2
until [[ $EXITVAL -lt 2 ]] ; do
dialog --cr-wrap --defaultno --no-shadow --colors --ok-label " 2 / 3 " --cancel-label "1" --help-button --help-label "README" --title " gcc cpu optimization " --inputbox \
"
 The build can be set up for gcc optimization.

 \Zr\Z4\Zb<1>\Zn - the default option \Zb\Z6$(echo $DEFAULT_MARCH)\Zn

 <\Zb\Z02\Zn> - the gcc native option \Zb\Z6$(echo $NATIVE_MARCH)\Zn for this machine

 <\Zb\Z03\Zn> - edit to specify \Zb\Z6march/mtune\Zn for a target machine
\Zb\Z0  [[ use any arrow key x2 to activate the input box for editing ]]\Zn
 
" \
18 75 "$(echo $NATIVE_MARCH)" \
2> $TMPVARS/SET_MARCH && break
EXITVAL=$?
[[ $EXITVAL == 1 ]] && echo $DEFAULT_MARCH > $TMPVARS/SET_MARCH && break
#
## add this to show what mtune option has been overridden
[[ $EXITVAL == 2 ]] && \
{ [[ $ARCH == x86_64 ]] && OPT1_MESSAGE=" * for x86_64 it is \Zb\Z6$(echo $GCC_MARCH)\Zn which is the gcc default."
} || \
{ [[ $ARCH == arm ]] && OPT1_MESSAGE="* for RPi3 [arm] the options are \Zb\Z6-march=armv8-a+crc -mtune=cortex-a53 -mfpu=neon-fp-armv8\Zn overriding the options \Zb\Z6$(echo $GCC_MARCH)\Zn configured into gcc"
} || \
{ [[ $ARCH == i586 ]] && OPT1_MESSAGE=" * for i586 the option has been set at \Zb\Z6-march=i586 -mtune=i686\Zn overriding the option \Zb\Z6$(echo $GCC_MARCH)\Zn configured into gcc"
}
#
dialog --aspect 3 --cr-wrap --no-shadow --colors --scrollbar --ok-label "Return" --msgbox \
"
<\Z2\Zb1\Zn> is the generic default for x86, or is pre-set for RPi3
$OPT1_MESSAGE

<\Z2\Zb2\Zn> is the option identified by gcc as native for this machine.

<\Z2\Zb3\Zn> is to override option <2> to build packages on this machine for installation on another machine with a known cpu-type, allowing that target machine's cpu instruction set to be fully utilized.

The relationship between -march and -mtune options and their use is detailed in the gcc man page in the section 'Intel 386 and AMD x86-64 Options'.
 
" \
0 0
done


rm -f $TMPVARS/NUMJOBS
[[ $ARCH == arm ]] && NUMJOBS="-j8"
dialog --cr-wrap --nocancel --no-shadow --colors --title " Parallel Build " --inputbox \
"
Set the number of simultaneous jobs for make to whatever your system will support.
" \
11 75 ${NUMJOBS:-"-j6"} \
2> $TMPVARS/NUMJOBS


rm -f $TMPVARS/I18N
EXITVAL=2
until [[ $EXITVAL -lt 2 ]] ; do
dialog --cr-wrap --nocancel --no-shadow --colors --help-button --help-label "README" --title " Select Additional Languages " --inputbox \
"
 This is the complete list of additional languages supported by TDE.

 Other package sources may not have support for all these additional languages, but they will be included in the build for that package when the translations are included in its source.
 If any other translation is included in the package source, it can be added here but won't be supported by TDE.

 Multiple selections may be made - space separated.

 Build language packages/support for any of:
\Zb\Z6af ar az be bg bn br bs ca cs csb cy da de el en_GB eo es et eu fa fi fr fy ga gl he hi hr hu is it ja kk km ko lt lv mk mn ms nb nds nl nn pa pl pt pt_BR ro ru rw se sk sl sr sr@Latn ss sv ta te tg th tr uk uz uz@cyrillic vi wa zh_CN zh_TW\Zn
" \
24 75 \
2> $TMPVARS/I18N && break
[[ $EXITVAL == 2 ]] && dialog --cr-wrap --defaultno --yes-label "Ascii" --no-label "Utf-8" --no-shadow --colors --no-collapse --yesno \
"
The source unpacked is ~950MB, so to save on build space, the SlackBuild script extracts, builds, and removes source for each language package one at a time.

If you can see the two 'y' like characters, then you've probably got a suitable terminal font installed and can choose \Zr\Z4\ZbUtf-8\Zb\Zn, otherwise choose \Z1A\Zb\Z0scii\Zn.

                            <<\Z3\Zb ҷ ɣ \Zn>>

\Zb\Z0A suitable font in a utf8 enabled terminal is needed to display all the extended characters in this list. Liberation Mono in an 'xterm' is known to work. Setting up a 'tty' is not worth the effort.\Zn
" \
19 75
EXVAL=$?
[[ $EXVAL == 1 ]] && dialog --cr-wrap --no-shadow --colors --no-collapse --ok-label "Return" --msgbox \
"
\Zb\Z2PgDn/PgUp to scroll\Zn

$(xzless Core/tde-i18n/langcodes.xz | tr "\n" X | sed 's|X|\\n|g;s|Latn\t|Latn|g')
" \
26 75
[[ $EXVAL == 0 ]] && dialog --cr-wrap --no-shadow --colors --no-collapse --ok-label "Return" --msgbox \
"
\Zb\Z2PgDn/PgUp to scroll\Zn

$(xzless Core/tde-i18n/langcodes.xz |sed 's|\t\+|\t|g'|cut -f 1,3-| tr "\n" X | sed 's|X|\\n|g;s|\t|\t\t|g;s|cyrillic\t|cyrillic|g;s|Latn\t|Latn|g')
" \
26 75
done


rm -f $TMPVARS/EXIT_FAIL
dialog --cr-wrap --defaultno --yes-label "Continue" --no-label "Stop" --no-shadow --colors --title " Action on failure " --yesno \
"
Do you want the build to \Zr\Z4\ZbStop\Zn at a failure or <\Z1C\Zb\Z0ontinue\Zn> to the next SlackBuild?

Build logs are $TMP/'program'-*-build-log, and configure/cmake error logs will be in $TMP/build/tmp-'program'.

A practical build method could be:

 1] build the \Zb\Zr\Z4R\Znequired packages with the \Zr\Z4\ZbStop\Zn option - if any SlackBuild fails, the temporary files for that build will be kept and the problem can be identified and the build restarted.
Any problems with the build environment will also become apparent here.

 2] then build other packages with the <\Z1C\Zb\Z0ontinue\Zn> option which deletes the temporary build files while the successful package builds are completing.
Any failures here are likely to be related to dependencies not found.

 3] re-run the build for the failed programs from [2] by re-using the build list and with the \Zr\Z4\ZbStop\Zn option ...
 " \
26 75
[[ $? == 0 ]] && 2> $TMPVARS/EXIT_FAIL
[[ $? == 1 ]] && echo "exit 1" > $TMPVARS/EXIT_FAIL


rm -f $TMPVARS/KEEP_BUILD
dialog --cr-wrap --no-shadow --colors --defaultno --title " Temporary Build Files " --yesno \
"
'tmp' & 'package' files from a previous package build are removed at the start of building the next package to keep the build area clear.

If following the build method on the previous screen, the answer here should probably be \Zr\Z4\ZbNo\Zn.

Keep \ZuALL\ZU the temporary files, including for successfully built packages?" \
14 75
[[ $? == 0 ]] && echo yes > $TMPVARS/KEEP_BUILD
[[ $? == 1 ]] && echo no > $TMPVARS/KEEP_BUILD


rm -f $TMPVARS/SELECT
dialog --cr-wrap --no-shadow --colors --defaultno --title " Required dependencies " --yesno \
"
Pre-select TDE core modules and required dependencies for the build list?

Select \Zr\Zb\Z4No\Zn here if they have already been built and installed and you are building additional packages.
" \
11 75
[[ $? == 0 ]] && echo on > $TMPVARS/SELECT
[[ $? == 1 ]] && echo off > $TMPVARS/SELECT
export SELECT=$(cat $TMPVARS/SELECT)


rm -f $TMPVARS/PREPEND
EXITVAL=2
until [[ $EXITVAL -lt 2 ]] ; do
dialog --cr-wrap --no-shadow --yes-label "Prepend" --help-button --help-label "README" --no-label "Default" --colors --defaultno --title " Libraries Search Path " --yesno \
"
Select <\Z1P\Zb\Z0repend\Zn> to add the TDE libs paths to the beginning of the search path.

Try \Zr\Zb\Z4Default\Zn first - in most cases this will work.
" \
10 75
EXITVAL=$?
[[ $EXITVAL == 0 ]] && echo yes > $TMPVARS/PREPEND
[[ $EXITVAL == 1 ]] && 2> $TMPVARS/PREPEND
[[ $EXITVAL == 2 ]] && dialog --cr-wrap --no-shadow --colors --ok-label "Return" --msgbox \
"
The default with the tqt3 build is to append the TDE lib paths to /etc/ld.so.conf.

This means that TDE libs will be at the end of the search path. If the package configuration sets up the search path without using the shell variables set up in this script, those TDE libs will not be used if a library of the same name exists - a conflict which could arise if another DE is installed.

If you experience any problems of this nature, then try the \Z1P\Zb\Z0repend\Zn option, which will set up doinst.sh for tqt3 to add the TDE libs paths to the beginning of the search path.

 Then \Zb\Z2rebuild tqt3\Zn. This build option only applies to that package.
" \
 20 75
done


rm -f $TMPVARS/TDEbuilds
dialog --cr-wrap --nocancel --no-shadow --colors --title " TDE Packages Selection " --item-help --checklist \
"
Required builds for a basic working TDE are marked \Zb\Zr\Z4R\Zn.

The packages selected form the build list and so dependencies are listed before the packages that need them. After the \Zb\Zr\Z4R\Znequired packages, the listing is grouped Core/Libs/Apps and then alphabetically within those groups, excluding tde prefixes added to package names, and the dependencies.

Look out for messages in the bottom line of the screen, especially relating to dependencies.

Non-TDE apps are in the Misc category and don't need the \Zb\Zr\Z4R\Znequired TDE packages." \
0 0 0 \
"Deps/tqt3" "\Zb\Zr\Z4R\Zn The Qt package for TDE" ${SELECT:-off} "\Zb\Z6  \Zn" \
"Deps/tqtinterface" "\Zb\Zr\Z4R\Zn TDE bindings to tqt3." ${SELECT:-off} "\Zb\Z6  \Zn" \
"Deps/arts" "\Zb\Zr\Z4R\Zn Sound server for TDE" ${SELECT:-off} "\Zb\Z6   \Zn" \
"Deps/dbus-tqt" "\Zb\Zr\Z4R\Zn A simple IPC library" ${SELECT:-off} "\Zb\Z6   \Zn" \
"Deps/dbus-1-tqt" "\Zb\Zr\Z4R\Zn D-Bus bindings" ${SELECT:-off} "\Zb\Z6   \Zn" \
"Deps/libart-lgpl" "\Zb\Zr\Z4R\Zn The LGPL'd component of libart" ${SELECT:-off} "\Zb\Z6   \Zn" \
"Deps/tqca-tls" "\Zb\Zr\Z4R\Zn Plugin to provide SSL/TLS capability" ${SELECT:-off} "\Zb\Z6   \Zn" \
"Deps/avahi-tqt" "Avahi support" off "\Zb\Z6 Requires Avahi. Optional for tdelibs and used by default if installed. \Zn" \
"Core/tdelibs" "\Zb\Zr\Z4R\Zn TDE libraries" ${SELECT:-off} "\Zb\Z6 Will build with Avahi support if avahi/avahi-tqt are installed. \Zn" \
"Core/tdebase" "\Zb\Zr\Z4R\Zn TDE base" ${SELECT:-off} "\Zb\Z6   \Zn" \
"Core/tde-i18n" "Additional language support for TDE" off "\Zb\Z6 Required when \Zb\Z3Additional language support\Zb\Z6 has been selected \Zn" \
"Core/tdeaccessibility" "Accessibility programs" off "\Zb\Z6  \Zn" \
"Core/tdeadmin" "System admin packages" off "\Zb\Z6  \Zn" \
"Core/tdeartwork" "Extra artwork/themes/wallpapers for TDE" off "\Zb\Z6   \Zn" \
"Core/tdeedu" "Educational software" off "\Zb\Z6   \Zn" \
"Core/tdegames" "Games for TDE - atlantik, kasteroids, katomic, etc." off "\Zb\Z6   \Zn" \
" Misc/imlib" "An image loading and rendering library" off "\Zb\Z6 Build-time option for tdegraphics - needed for kuickshow \Zn" \
"Core/tdegraphics" "Misc graphics apps" off "\Zb\Z6   \Zn" \
"Deps/akode" "A player and plugins for aRts music formats" off "\Zb\Z6 For tdemultimedia - aRts-plugin and Juk \Zn" \
"Core/tdemultimedia" "Multimedia packages for TDE" off "\Zb\Z6   \Zn" \
" Misc/speex" "Audio compression format designed for speech" off "\Zb\Z6 Buildtime option for tdenetwork and amarok. Requires l/speexdsp  \Zn" \
"Core/tdenetwork" "Networking applications for TDE" off "\Zb\Z6 Optional build-time dependency - speex \Zn" \
"Deps/libcaldav" "Calendaring Extensions to WebDAV" off "\Zb\Z6 Optional dependency for korganizer [tdepim] \Zn" \
"Deps/libcarddav" "Online address support" off "\Zb\Z6 Optional dependency for korganizer [tdepim] \Zn" \
"Core/tdepim" "Personal Information Management" off "\Zb\Z6   \Zn" \
"Core/tdeaddons" "Additional plugins and scripts" off "\Zb\Z6 Optional plugins from tdegames, tdemultimedia, tdepim \Zn" \
"Core/tdesdk" "Tools used by TDE developers" off "\Zb\Z6 Requires tdepim \Zn" \
"Core/tdetoys" "TDE Amusements" off "\Zb\Z6   \Zn" \
"Core/tdeutils" "Collection of utilities including ark" off "\Zb\Z6   \Zn" \
"Core/tdevelop" "TDE development programs" off "\Zb\Z6 Requires tdesdk  \Zn" \
" Misc/tidy-html5" "Corrects and cleans up HTML and XML documents" off "\Zb\Z6 Runtime option for Quanta+ [tdewebdev] \Zn" \
"Core/tdewebdev" "Quanta Plus and other applications" off "\Zb\Z6   \Zn" \
"Libs/tdelibkdcraw" "Decode RAW picture files" off "\Zb\Z6 Required for digikam, tdegwenview and ksquirrel \Zn" \
"Libs/tdelibkexiv2" "Library to manipulate picture metadata" off "\Zb\Z6 Required for digikam, tdegwenview and ksquirrel. Needs l/exiv2... \Zn" \
"Libs/tdelibkipi" "A common plugin structure" off "\Zb\Z6 Required for digikam, tdegwenview and ksquirrel \Zn" \
"Libs/kipi-plugins" "Additional functions for digiKam, ksquirrel and gwenview" off "\Zb\Z6 Required for digikam, tdegwenview and ksquirrel. Requires tdelibkdcraw tdelibkexiv2 tdelibkipi. \Zn" \
" Misc/xmedcon" "A medical image conversion utility & library" off "\Zb\Z6 Buildtime option for libksquirrel \Zn" \
"Libs/libksquirrel" "A set of image codecs for KSquirrel" off "\Zb\Z6 Required for ksquirrel. Buildtime options include l/netpbm, t/transfig [fig2dev], Misc/xmedcon \Zn" \
"Apps/abakus" "PC calculator" off "\Zb\Z6 optional dependency l/mpfr which requires l/gmp \Zn" \
" Misc/libmp4v2" "Create and modify mp4 files" off "\Zb\Z6 Buildtime option for Amarok  \Zn" \
" Misc/moodbar" "GStreamer plugin for Amarok for moodbar feature" off "\Zb\Z6 Runtime option for Amarok \Zn" \
" Misc/yauap" "simple commandline audio player" off "\Zb\Z6 Provides an optional engine for Amarok \Zn" \
"Apps/tdeamarok" "A Music Player" off "\Zb\Z6 Optional dependencies - xine-lib, libmp4v2, speex, moodbar \Zn" \
"Apps/digikam" "A digital photo management application + Showfoto viewer" off "\Zb\Z6 Requires kipi-plugins tdelibkdcraw tdelibkexiv2 tdelibkipi.  \Zn" \
"Apps/dolphin" "Dolphin file manager for TDE" off "\Zb\Z6 A d3lphin.desktop file is included - see dolphin.SlackBuild.  \Zn" \
"Apps/tdefilelight" "Graphical diskspace display" off "\Zb\Z6 Runtime requirement x/xdpyinfo \Zn" \
"Apps/gtk-qt-engine" "A GTK+2 theme engine" off "\Zb\Z6   \Zn" \
"Apps/gtk3-tqt-engine" "A GTK+3 theme engine" off "\Zb\Z6   \Zn" \
"Apps/tdegwenview" "An image viewer" off "\Zb\Z6 Requires kipi-plugins tdelibkdcraw tdelibkexiv2 tdelibkipi.  \Zn" \
"Apps/tdegwenview-i18n" "Internationalization files for gwenview." off "\Zb\Z6 Required for tdegwenview when \Zb\Z3Additional language support\Zb\Z6 has been selected  \Zn" \
"Apps/tdek3b" "The CD Creator" off "\Zb\Z6   \Zn" \
"Apps/tdek3b-i18n" "Internationalization files for tdek3b." off "\Zb\Z6 Required for tdek3b when \Zb\Z3Additional language support\Zb\Z6 has been selected  \Zn" \
"Apps/k9copy" "A DVD backup utility" off "\Zb\Z6 Requires [tde]k3b and ffmpeg \Zn" \
"Apps/kaffeine" "Media player for TDE" off "\Zb\Z6   \Zn" \
"Apps/kbfx" "Alternate menu for TDE" off "\Zb\Z6   \Zn" \
"Apps/kbookreader" "Twin-panel text files viewer esp. for reading e-books." off "\Zb\Z6   \Zn" \
"Apps/kdbg" "GUI for gdb using TDE" off "\Zb\Z6   \Zn" \
"Apps/kdbusnotification" "A DBUS notification to TDE interface" off "\Zb\Z6   \Zn" \
"Apps/kile" "A TEX and LATEX source editor and shell" off "\Zb\Z6   \Zn" \
"Apps/kkbswitch" "A keyboard layout indicator" off "\Zb\Z6   \Zn" \
"Apps/knemo" "The TDE Network Monitor" off "\Zb\Z6   \Zn" \
"Apps/knetstats" "A network monitor that shows rx/tx LEDs" off "\Zb\Z6   \Zn" \
"Apps/knights" "A graphical chess interface" off "\Zb\Z6   \Zn" \
"Apps/knmap" "A graphical nmap interface" off "\Zb\Z6 Might need tdesudo \Zn" \
" Misc/GraphicsMagick" "Swiss army knife of image processing" off "\Zb\Z6 Buildtime option for chalk[krita] in koffice \Zn" \
"Apps/koffice" "Office Suite" off "\Zb\Z6 Optional build-time dependencies - GraphicsMagick/libpng14 [for chalk/krita]  \Zn" \
"Apps/koffice-i18n" "Internationalization files for koffice" off "\Zb\Z6 Required for koffice when \Zb\Z3Additional language support\Zb\Z6 has been selected  \Zn" \
"Apps/krusader" "File manager for TDE" off "\Zb\Z6   \Zn" \
" Misc/graphviz" "Graph Visualization" off "\Zb\Z6 Runtime option for kscope. pdf/html docs not built by default  \Zn" \
"Apps/kscope" "A source-editing environment for C and C-style languages." off "\Zb\Z6 Runtime options cscope [d/cscope], ctags [ap/vim], dot [graphviz] \Zn" \
"Apps/ksensors" "A graphical interface for sensors" off "\Zb\Z6 Runtime requirement ap/lm_sensors \Zn" \
"Apps/kshutdown" "Shutdown utility for TDE" off "\Zb\Z6   \Zn" \
"Apps/ksquirrel" "An image viewer with OpenGL and KIPI support." off "\Zb\Z6 Requires kipi-plugins tdelibkdcraw tdelibkexiv2 tdelibkipi libksquirrel. \Zn" \
"Apps/tdektorrent" "A BitTorrent client for TDE" off "\Zb\Z6   \Zn" \
"Apps/kvkbd" "A virtual keyboard for TDE" off "\Zb\Z6   \Zn" \
"Apps/kvpnc" "TDE frontend for various vpn clients" off "\Zb\Z6 Miscellaneous documentation will be in $(cat $TMPVARS/INSTALL_TDE)/doc/kvpnc-$(cat $TMPVARS/TDEVERSION)  \Zn" \
"Apps/piklab" "IDE for PIC microcontrollers" off "\Zb\Z6   \Zn" \
" Misc/potrace" "For tracing bitmaps to a vector graphics format" off "\Zb\Z6 Required for potracegui, optional for inkscape \Zn" \
"Apps/potracegui" "A GUI for potrace" off "\Zb\Z6 Requires potrace \Zn" \
"Apps/rosegarden" "Audio sequencer and musical notation editor" off "\Zb\Z6 Requires jack-audio-connection-kit liblo and dssi for proper funtionality \Zn" \
"Apps/soundkonverter" "frontend to various audio converters" off "\Zb\Z6   \Zn" \
"Apps/tde-style-lipstik" "lipstik theme" off "\Zb\Z6   \Zn" \
"Apps/tde-style-qtcurve" "QtCurve theme" off "\Zb\Z6   \Zn" \
"Apps/tdeio-locate" "TDE frontend for the locate command" off "\Zb\Z6   \Zn" \
"Apps/tdesudo" "Graphical frontend for the sudo command" off "\Zb\Z6   \Zn" \
"Apps/tdmtheme" "tdm theme editor module" off "\Zb\Z6   \Zn" \
"Apps/twin-style-crystal" "twin theme" off "\Zb\Z6   \Zn" \
"Apps/yakuake" "Quake-style terminal emulator" off "\Zb\Z6   \Zn" \
" Misc/lxml" "Python bindings for libxml2 and libxslt" off "\Zb\Z6 Required to use Inkscape online help \Zn" \
" Misc/inkscape" "SVG editor - an alternative to potrace, potracegui [and GraphicsMagick]." off "\Zb\Z6 Requires lxml if online help facility is required, potrace is a build-time option. \Zn" \
2> $TMPVARS/TDEbuilds
# successful builds are removed from the TDEbuilds list by '$dir ' so add a space to the last entry
# and the " needs to be removed because the Misc entries are double-quoted
sed -i -e 's|$| |' -e 's|"||g' $TMPVARS/TDEbuilds


## only run this if tqt3 has been selected
rm -f $TMPVARS/TQT_OPTS
[[ $(grep -o tqt3 $TMPVARS/TDEbuilds) ]] && {
dialog --cr-wrap --nocancel --no-shadow --colors --title " TQt options " --item-help --checklist \
"
A minimal packaging of tqt3 will install only the run-time library required for TDE, and the headers and binaries required to build most of TDE.

But tdepim, ksquirrel, and tdevelop need additional libraries. If you select minimal packaging and intend to build any of those at any time, select keeping their required libs now.

TQt html documentation is ~21M, and can be excluded from the package.
 
" \
21 75 4 \
" minimal" "Minimal packaging" off "\Zb\Z6 Exclude libs and binaries not required for TDE \Zn" \
" pim_ksq" "Keep lib for tdepim and/or ksquirrel" off "\Zb\Z6 Only required if minimal build selected \Zn" \
" tdevel" "Keep libs for tdevelop" off "\Zb\Z6 Only required if minimal build selected \Zn" \
" nodocs" "Exclude html documentation" on "\Zb\Z6  \Zn" \
2> $TMPVARS/TQT_OPTS
}

## only run this if tdebase has been selected
rm -f $TMPVARS/RUNLEVEL
[[ $(grep -o tdebase $TMPVARS/TDEbuilds) ]] && {
EXITVAL=2
until [[ $EXITVAL -lt 2 ]] ; do
dialog --cr-wrap --no-shadow --yes-label "4" --no-label "3" --help-button --help-label "README" --colors --defaultno --title " TDM " --yesno \
"
TDM is included in the tdebase build.

Choose whether to boot into the GUI and login with TDM - runlevel \Zb\Z64\Zn
or
boot into a terminal - runlevel \Zb\Z63\Zn - the Slackware default.

This option can be overridden later by editing /etc/inittab.
" \
13 75
EXITVAL=$?
[[ $EXITVAL == 0 ]] && echo 4 > $TMPVARS/RUNLEVEL
[[ $EXITVAL == 1 ]] && echo 3 > $TMPVARS/RUNLEVEL
[[ $EXITVAL == 2 ]] && dialog --cr-wrap --no-shadow --colors --ok-label "Return" --msgbox \
"
$(cat Core/tdebase/README|sed "s|/{TDE_installation_dir}|$(cat $TMPVARS/INSTALL_TDE)|;s|(|\\\Z6\\\Zb|;s|)|\\\Zn|")
" \
30 75
done
}


## only run this if building koffice has been selected
[[ $(sed 's|koffice-||' $TMPVARS/TDEbuilds | grep -o Apps/koffice) ]] && \
{
rm -f $TMPVARS/Krita_OPTS
dialog --cr-wrap --nocancel --no-shadow --colors --title " Building chalk in koffice " --item-help --checklist \
"
There are three options that can be set up for building the imaging app in koffice.

[1] It is called \Zb\Z3chalk\Zn in TDE but is known as \Zb\Z3krita\Zn most other places.

[2] .pngs loaded into chalk/krita will crash if it is built with libpng-1.6, but will load if libpng-1.4 is used for the build.
  If libpng is chosen here, it will be added to the build list and the package placed in $TMP - not installed. It will then be installed by koffice.SB if the libpng unversioned headers and libs are not linked to libpng14.
  The koffice.SB will restore those links to libpng16 when the build has finished or failed.

[3] GraphicsMagick will enable an extended range of image formats to be loaded and saved. ImageMagick should be an alternative, but building fails with that, so without GM, the range of supported image formats will be limited.
  If GM is chosen here, it will be added to the build list if not already selected or installed." \
30 75 3 \
" krita" "Set the app name to krita" on "\Zb\Z6 otherwise will be \Zb\Z3chalk\Zn" \
" libpng14" "Build with libpng-1.4" on "\Zb\Z6 otherwise will be \Zb\Z3libpng-1.6\Zn" \
" useGM" "Use GraphicsMagick" on "\Zb\Z6  \Zn" \
2> $TMPVARS/Krita_OPTS
## If GM has been selected and isn't in the build list or installed, add it to the build list before koffice
GM_VERSION=$(grep VERSION:- $BUILD_TDE_ROOT/Misc/GraphicsMagick/GraphicsMagick.SlackBuild|cut -d- -f2|cut -d} -f1)
[[ $(cat $TMPVARS/Krita_OPTS) == *useGM* ]] && \
[[ $(cat $TMPVARS/TDEbuilds) != *GraphicsMagick* ]] && \
[[ ! $(ls /var/log/packages/GraphicsMagick-$GM_VERSION*) ]] && \
sed -i 's|Apps/koffice|Misc/GraphicsMagick &|' $TMPVARS/TDEbuilds
## If libpng-1.4 has been selected and hasn't already been built, add it to the build list before koffice
PNG_VERSION=$(grep VERSION:- $BUILD_TDE_ROOT/Misc/libpng/libpng.SlackBuild|cut -d- -f2|cut -d} -f1)
[[ $(cat $TMPVARS/Krita_OPTS) == *libpng14* ]] && \
[[ ! $(ls $LIBPNG_TMP/libpng-$PNG_VERSION-*-1.txz) ]] && \
sed -i 's|Apps/koffice|Misc/libpng &|' $TMPVARS/TDEbuilds
}


## this dialog will only run if any of the selected packages has a README
rm -f $TMPVARS/READMEs
## generate list of READMEs ..
RM_LIST=$(find [ACDLM][a-z]* -name "README" | grep -v tdebase)
for package in $(cat $TMPVARS/TDEbuilds)
do
[[ $RM_LIST == *$package* ]] && {
echo "\Zb\Z6\Zu$package\ZU\Zn

$(cat $package/README)
" >> $TMPVARS/READMEs
}
done
## .. if there is a list, run dialog
[[ $(cat $TMPVARS/READMEs) ]] && {
dialog --cr-wrap --defaultno --no-shadow --colors --title " READMEs " --yesno \
"
A number of selected packages have READMEs in their SlackBuilds directories.

Do you want to read them?
 " \
10 75
[[ $? == 0 ]] && dialog --no-collapse --cr-wrap --no-shadow --colors --ok-label "Close" --msgbox \
"
$(cat $TMPVARS/READMEs)" \
30 75
}


rm -f $TMPVARS/CGIT  # place this here to facilitate testing for summary screen
[[ $(cat $TMPVARS/TDEVERSION) == cgit ]] && \
[[ $(grep -o [ACDLM][a-z]*/ $TMPVARS/TDEbuilds | sort | head -n1) != Misc/ ]] && {
dialog --cr-wrap --no-shadow --colors --defaultno --title " TDE development build " --yesno \
"
This routine creates and updates the git repositories local copies.

If this is a first run, answer 'yes' - be patient, downloads from git are slowwww...

For subsequent runs, 'yes' will update only.

Local repositories are created/updated as each package is built.
If the current build list includes new apps, and you don't want the existing repos updated, the new apps should be run as a new group initially as selective updating is not supported.

Do you want to create or update the git repositories?
 
" \
20 75
[[ $? == 0 ]] && echo yes > $TMPVARS/CGIT
[[ $? == 1 ]] && echo no > $TMPVARS/CGIT
}


}

[[ ! -e $TMPVARS/TDEbuilds ]] && run_dialog


# option to change to stop the build when it fails
if [[ $(cat $TMPVARS/build-new) == no ]] ; then
if [[ $(cat $TMPVARS/EXIT_FAIL) == "" ]] ; then
if [[ $(cat $TMPVARS/KEEP_BUILD) == no ]] ; then
dialog --cr-wrap --defaultno --yes-label "Stop" --no-label "Continue" --no-shadow --colors --title " Action on failure - 2 " --yesno \
"
You have chosen to re-use the TDE build list, which now contains only those programs that failed to build.

But this script is set to Continue in the event of a failure, which will delete all but the last build record. It will be easier to investigate each failure if the build is stopped when it fails.

Do you still want the build to \Zr\Z4\ZbContinue\Zn at a failure
 or change to \Z1S\Zb\Z0top\Zn ?
 " \
15 75
[[ $? == 0 ]] && echo "exit 1" > $TMPVARS/EXIT_FAIL
fi;fi;fi



######################
# there should be no need to make any changes below

export TDEVERSION=$(cat $TMPVARS/TDEVERSION)
export INSTALL_TDE=$(cat $TMPVARS/INSTALL_TDE)
export SYS_CNF_DIR=$(cat $TMPVARS/SYS_CNF_DIR)
export COMPILER=$(cat $TMPVARS/COMPILER)
[[ $COMPILER == gcc ]] && export COMPILER_CXX="g++" || export COMPILER_CXX="clang++"
export SET_march=$(cat $TMPVARS/SET_MARCH)
export ARCH=$(cat $TMPVARS/ARCH)	# set again for the 'continue' option
export TDE_MIRROR=mirror.ppa.trinitydesktop.org/trinity
export NUMJOBS=$(cat $TMPVARS/NUMJOBS)
export I18N=$(cat $TMPVARS/I18N)
export TQT_OPTS=$(cat $TMPVARS/TQT_OPTS)
export EXIT_FAIL=$(cat $TMPVARS/EXIT_FAIL)
export KEEP_BUILD=$(cat $TMPVARS/KEEP_BUILD)
export PREPEND=$(cat $TMPVARS/PREPEND)
export RUNLEVEL=$(cat $TMPVARS/RUNLEVEL)
# these exports are for koffice.SB
[[ $(cat $TMPVARS/Krita_OPTS) == *krita* ]] && export REVERT=yes
[[ $(cat $TMPVARS/Krita_OPTS) == *libpng14* ]] && export USE_PNG14=yes

# Is this a 64 bit system?
# 'uname -m' won't identify a 32 bit system with a 64 bit kernel
[[ ! -d /lib64 ]] && LIBDIRSUFFIX="" || LIBDIRSUFFIX="64"

TQTDIR=$INSTALL_TDE/lib$LIBDIRSUFFIX/tqt3

CPLUS_INCLUDE_PATH=$TQTDIR/include:${CPLUS_INCLUDE_PATH:-}

PKG_CONFIG_PATH=$INSTALL_TDE/lib$LIBDIRSUFFIX/pkgconfig:${PKG_CONFIG_PATH:-}

PATH=$TQTDIR/bin:$INSTALL_TDE/bin:$PATH

# needed for CMAKE_C_FLAGS
# and used for CFLAGS instead of 'configure --with-qt-includes=' option which doesn't always work
TQT_INCLUDE_PATH="-I$TQTDIR/include"

export LIBDIRSUFFIX
export TQTDIR
export CPLUS_INCLUDE_PATH
export PKG_CONFIG_PATH
export PATH
export TQT_INCLUDE_PATH
## to provide an ARCH suffix for the package name - see makepkg_fn in get-source.sh
export ARM_FABI=$(readelf -Ah $(which bash)|grep -oE "soft|hard")

### set up variables for the summary list:
## New build
[[ $(cat $TMPVARS/build-new) != no ]] && NEW_BUILD=yes || NEW_BUILD='no - re-use existing'
## Action on failure
AOF=$(echo $EXIT_FAIL|cut -d" " -f1)
## if tdebase selected
[[ $(grep -o tdebase $TMPVARS/TDEbuilds) ]] && TDMRL=\\Zb\\Z6$RUNLEVEL\\Zn && SHADERL=" "
## koffice - only if it is being built
[[ $(sed 's|koffice-||' $TMPVARS/TDEbuilds | grep -o Apps/koffice) ]] && {
[[ $REVERT == yes ]] && RVT=\\Zb\\Z6yes\\Zn || RVT=\\Zb\\Z6no\\Zn
[[ $(cat $TMPVARS/Krita_OPTS) == *useGM* ]] && USE_GM=\\Zb\\Z6yes\\Zn || USE_GM=\\Zb\\Z6no\\Zn
[[ $USE_PNG14 == yes ]] && USE_PNG=\\Zb\\Z6yes\\Zn || USE_PNG=\\Zb\\Z6no\\Zn
SHADEKO=" "
}
## tqt3 options, if tqt3 is being built
[[ $(grep -o tqt3 $TMPVARS/TDEbuilds) ]] && {
TQT_BLD=yes && [[ $TQT_OPTS != *minimal* ]] && TQT_BLD=no
TQT_DOCS=no && [[ $TQT_OPTS != *nodocs* ]] && TQT_DOCS=yes
}
## whether cloning or updating cgit
CLONE=$(cat $TMPVARS/CGIT)
## start dialog
EXITVAL=2
until [[ $EXITVAL -lt 2 ]] ; do
dialog --aspect 3 --no-collapse --cr-wrap --yes-label "Start" --no-label "Abort" --help-button --help-label "Build List" --no-shadow --defaultno --colors --title " Start TDE Build " --yesno \
"
Setup is complete - these are the build options:

New build list                          \Zb\Z6$NEW_BUILD\Zn
TDE version                             \Zb\Z6$TDEVERSION\Zn
Clone/update cgit local repositories    \Zb\Z6${CLONE:-\Z0\Zbn/a}\Zn
TDE installation directory              \Zb\Z6$INSTALL_TDE\Zn
TDE system configuration directory      \Zb\Z6$SYS_CNF_DIR\Zn
Compiler                                \Zb\Z6$COMPILER\Zn
gcc cpu optimization                    \Zb\Z6$SET_march\Zn
Number of parallel jobs                 \Zb\Z6$(echo $NUMJOBS|sed 's|-j||')\Zn
Additional languages                    \Zb\Z6${I18N:-\Z0\Zbnone}\Zn
Minimal tqt build                       \Zb\Z6${TQT_BLD:-\Z0\Zbn/a}\Zn
Include tqt html docs                   \Zb\Z6${TQT_DOCS:-\Z0\Zbn/a}\Zn
Action on failure                       \Zb\Z6${AOF:-continue}\Zn
Keep the temporary build files          \Zb\Z6$KEEP_BUILD\Zn
Prepend TDE libs paths                  \Zb\Z6${PREPEND:-no}\Zn${SHADERL:-\Z0\Zb}
Runlevel for TDM                        ${TDMRL:-n/a}\Zn${SHADEKO:-\Z0\Zb}
koffice:
 revert chalk to krita                  ${RVT:-n/a}
 build with libpng14                    ${USE_PNG:-n/a}
 build with GraphicsMagick              ${USE_GM:-n/a}\Zn

 <\Z1S\Zb\Z0tart\Zn> building the packages or \Zr\Z4\ZbAbort\Zn
 
" \
0 0
EXITVAL=$?
[[ $EXITVAL == 2 ]] && dialog --aspect 5 --cr-wrap --no-shadow --colors --scrollbar --ok-label "Return" --msgbox \
"
The packages to be built are:

$(cat $TMPVARS/TDEbuilds | tr -s " " "\n"|sed 's|^|\\Z0\\Zb|;s|/|\\Zn  |'|sort -k 2)

" \
0 0
[[ $EXITVAL == 0 ]] && break
[[ $EXITVAL == 1 ]] && echo -e "\n\nBuild aborted\n" && exit 1
echo
done

######################################################
# package(s) build starts here
## If there is a download failure in getsource_fn, it needs to be communicated to this script if the build is set to stop on failure
## getsource_fn is a function in get-source.sh which is a child of the SlackBuild script which is a child of this script and that failure needs to be carried back here
## $TMPVARS/download-failure will be created if needed for that purpose, so remove any possible previous file
rm -f $TMPVARS/download-failure

# Loop for all packages
for dir in $(cat $TMPVARS/TDEbuilds)
do
[[ ! -e $TMPVARS/download-failure ]] && {
   { [[ $dir == Deps* ]] && export TDEMIR_SUBDIR="/dependencies"; } \
|| { [[ $dir == Core* ]] && export TDEMIR_SUBDIR=""; } \
|| { [[ $dir == Libs* ]] && export TDEMIR_SUBDIR="/libraries"; } \
|| { [[ $dir == Apps* ]] && export TDEMIR_SUBDIR="/applications"; } \
|| { [[ $dir == *Misc* ]] && export TDEMIR_SUBDIR="misc"; } # used for untar_fn - leading slash deliberately omitted

  # Get the package name
  package=$(echo $dir | cut -f2- -d /)

  # Change to package directory
  cd $BUILD_TDE_ROOT/$dir || ${EXIT_FAIL:-"true"}

  # Get the version
  version=$(cat $package.SlackBuild | grep "VERSION:" | head -n1 | cut -d "-" -f2 | rev | cut -c 2- | rev)

  # Get the build
  build=$(cat $package.SlackBuild | grep "BUILD:" | cut -d "-" -f2 | rev | cut -c 2- | rev)

  # The real build starts here
  script -c "sh $package.SlackBuild" $TMP/$package-$TDEVERSION-$ARCH-$build-build-log || ${EXIT_FAIL:-"true"}

# remove colorizing escape sequences from build-log
# Re: http://serverfault.com/questions/71285/in-centos-4-4-how-can-i-strip-escape-sequences-from-a-text-file
  sed -ri "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" $TMP/$package-$TDEVERSION-$ARCH-$build-build-log || ${EXIT_FAIL:-"true"}

checkinstall ()
{
## test for what package is being built .. 
## if it's not libpng, test for the package installed
## otherwise test for the libpng package only, not installed
{
{
[[ $package != libpng ]] && [[ $(ls /var/log/packages/$package-*$(eval echo $version)-*-$build*) ]]
} || {
[[ $package == libpng ]] && [[ $(ls $LIBPNG_TMP/$package-$(eval echo $version)-*-$build*.txz) ]]
}
} && \
## if either test is successful, the above will exit 0, then remove 'package' from the build list \
sed -i "s|$dir ||" $TMPVARS/TDEbuilds || \
## if unsuccessful, display error message \
{
echo "
      Error:  $package package build failed
      Check the build log $TMP/$package-$TDEVERSION-$ARCH-$build-build-log
      "
## if koffice was building with libpng14, restore the libpng16 headers for any following builds
[[ ${USE_PNG14:-} == yes ]] && source $BUILD_TDE_ROOT/get-source.sh && libpng16_fn || true
${EXIT_FAIL:-":"}
}
}
# tde-i18n package installation is handled in tde-i18n.SlackBuild because if more than one i18n package is being built, only the last one will be installed by upgradepkg
## tidy-html5 is a special case because the version number is not in the archive name
## create libpng-1.4 package only - it will be installed by the koffice.SB because it overrides libpng headers which for Sl14.2/current point to libpng16.
[[ $package == tidy-html5 ]] && version=$(unzip -c tidy-html5-master.zip | grep -A 1 version.txt | tail -n 1)
if [[ $INST == 1 ]] && [[ $package != tde-i18n ]] && [[ $package != libpng ]]; then upgradepkg --install-new --reinstall $TMP/$package-$(eval echo $version)-*-$build*.txz
checkinstall
## test for last language in the I18N list to ensure they've all been built
elif [[ $INST == 1 ]] && [[ $package == tde-i18n ]]; then package=$package-$(cat $TMPVARS/LASTLANG)
checkinstall
elif [[ $package == libpng ]]; then checkinstall
fi

  # back to original directory
  cd $BUILD_TDE_ROOT
}
done
}

build_core || ${EXIT_FAIL:-"true"}

