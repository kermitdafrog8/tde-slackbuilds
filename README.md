[<img src="https://ray-v.github.io/TDE-aarch64-gui.png">](https://ray-v.github.io/TDE-aarch64-gui.png)
... a TDE desktop, cross compiled for aarch64, running on a RPi3.

---
***Build TDE [Trinity Desktop Environment]***  
.. for Slackware 14.2 or current on i586+ and x86_64.  
.. see 'Cross compiling for RPi3' for building for armv7/aarch64.

Build the release version 14.0.8 from tar archives; or the development versions 14.0.9, 14.1.0 from trinitydesktop cgit.  
For a native build, run **./BUILD-TDE.sh** - a dialog based script with a series of screens for user input.  

[<img src="https://ray-v.github.io/TDE-version.png">](https://ray-v.github.io/TDE-version.png)

The default is to install the packages as they are built, which is necessary initially for the required packages and for some interdependencies [for example, tdesdk requires tdepim].  

Run **INST=0 ./BUILD-TDE.sh** to build only.  
This is a global option so can't be used where the build list includes packages which will be dependencies for other packages in the build list.

Any package, or set of packages, can be selected in the 'TDE Packages Selection' screen.  
Information about dependencies for some packages has been added at the bottom of the dialog screen.

14.0.8 source archives will be downloaded from a geoIP located mirror site, or the development sources [14.0.9/14.1.0] cloned or updated from cgit.  
Downloading can be done pre-build [useful for an off-line build], or during the build.

If you're curious about what this might involve, [take a look at a sample build set up](https://ray-v.github.io/A_typical_TDE_SlackBuild.html).

---

***Other command line options*** that can be used to set some build parameters:
* TDE_MIRROR= - override the trinitydesktop.org geoIP redirector to use https - example, *https://mirrorservice.org/sites/trinitydesktop.org/trinity*. URLs @ https://www.trinitydesktop.org/mirrorstatus.php
* BUILD= - sets the package build identifier, overriding the SlackBuild default of 1
* USE_CMAKE_MM=yes - to build tdemultimedia with cmake - see Core/tdemultimedia/README.
* VERBOSE=1 - show command lines during cmake builds

---

***The directory structure*** for the SlackBuild scripts is in line with the Trinity release source repositories:  
```
Deps [dependencies/]
Core []
Libs [libraries/]
Apps [applications/]
```
Other directories are:  
```
Misc - for non-Trinity package builds
src - to hold all the sources, either pre-downloaded or downloaded during the build.
```
Other scripts:  
```
get-source.sh - a chunk of common code for the SlackBuilds
              - used for getting the sources, setting FLAGS, creating build directories, ...
```
There is an override in the Misc SlackBuilds for non-trinity source archive URLs. Non-trinity builds have been included where a TDE package requires a dependency that is not in Slackware, or where it's an alternative to a TDE package.

---

***Required packages*** for a basic working TDE are:  
```
Deps/tqt3
Deps/tqtinterface
Deps/arts
Deps/dbus-tqt
Deps/dbus-1-tqt
Deps/tqca-tls
Deps/libart-lgpl
Core/tdelibs
Core/tdebase
```
---

***Internationalization***

i18n support [locale and html/help docs] in the packages is restricted to whatever is selected in the ./BUILD-TDE.sh 'Select Additional Languages' screen and, of that, to whatever is available in any individual package source.

Additionally for the development builds, translations for the .desktop files are determined from the LINGUAS variable which is set in this build shell to the additional languages selected.

There is an option in tde-i18n.SlackBuild to include a user created language specific patch file in the build.  
It needs to be named *tde-i18n-{lang}-patch* and will then automatically be included for the build for that language.  
Because of its position in the Slackbuild and the patch -p0 option, the path to the patched file must start with 'tde-i18n-{lang}' - see tde-i18n-en_GB-patch for an example.

---

***Building the development versions from git sources***

The individual TDE apps can be cloned from Trinity git, so the build is set up to do that - except for individual language packs of tde-i18n. The whole tde-i18n download is ~1x10^6 bytes, so to reduce that, wget is used to download individual tde-i18n-$lang packs as they are not git repositories.

Once any git repository has been cloned, further downloads are updates only[2], giving the best options - only fetching what is needed, and incremental updates.

The git repositories are cloned to 'src/cgit'

---

***Cross compiling for RPi3***

Cross compiling a number of packages for the Raspberry Pi3 based on these scripts is detailed in the html page in the gh-pages branch:
```
git clone https://github.com/Ray-V/tde-slackbuilds.git  
cd tde-slackbuilds  
git checkout gh-pages
```

which can be viewed [online](https://ray-v.github.io/tde-slackbuilds/cross-compiling-TDE-for-the-RPi3.html).

Includes:
* Setting parameters for a 32-bit [armv7 hard float], or 64-bit [aarch64], build,  
   .. and building ..
*  a cross compiler toolchain
*  a 64-bit kernel which can be used for the 32-bit system
*  qemu to run the TDE binaries built and used during compilation
*  the required TDE apps
*  a few other TDE and non-TDE apps to provide a basic, but useful, TDE desktop.

---

***Known issues***

[1] TDM may need some manual setting up - see Core/tdebase/README, which can also be viewed while running ./BUILD-TDE.sh if tdebase is selected.

[2] The i18n downloads with wget can't be updated because cgit produces 'current time' timestamps. The consequence is that if tde-i18n-$lang is a part of the build after its initial download, it will be downloaded again. As updates are infrequent, once built, there will probably be no need to do so again and so tde-i18n for a particular language will probably only be run once. On that basis I don't see this being a significant issue.

[3] The Misc directory contains SlackBuilds for software that might already be installed from other sources. Please check because any misc builds selected here could overwrite them.

[4] The README for a native build for Raspberry Pi3 [[README-Raspberry-Pi3.md](./README-Raspberry-Pi3.md)] is now rather dated and cross compiling is a better option.

[5] Building the kalzium equation solver needs ocaml and facile installed. They will be built, packaged, and installed during the tdeedu build if the source archives are pre-downloaded to the 'src' directory.  
https://github.com/ocaml/ocaml/archive/4.05.0.tar.gz  
http://www.recherche.enac.fr/opti/facile/distrib/facile-1.1.3.tar.gz

---

See https://wiki.trinitydesktop.org/How_to_Build_TDE_Core_Modules for more information

