# Save old config files:
if [ ! -L etc/X11/tdm ]; then
  if [ -d etc/X11/tdm ]; then
  mkdir -p .{SYS_CNF_DIR}/tdm
  cp -a etc/X11/tdm/* .{SYS_CNF_DIR}/tdm
  rm -rf etc/X11/tdm
  ( cd etc/X11 ; ln -sf ../..{SYS_CNF_DIR}/tdm tdm )
    elif [ ! -e etc/X11/tdm ]; then
    mkdir -p etc/X11
    ( cd etc/X11 ; ln -sf ../..{SYS_CNF_DIR}/tdm tdm )
  fi
fi


config() {
  NEW="$1"
  OLD="`dirname $NEW`/`basename $NEW .new`"
  # If there's no config file by that name, mv it over:
  if [ ! -r $OLD ]; then
    mv $NEW $OLD
  elif [ "`cat $OLD | md5sum`" = "`cat $NEW | md5sum`" ]; then # toss the redundant copy
    rm $NEW
  fi
  # Otherwise, we leave the .new copy for the admin to consider...
}
config .{SYS_CNF_DIR}/tdm/tdmrc.new
config .{SYS_CNF_DIR}/tdm/backgroundrc.new

# Update the desktop database:
/usr/bin/update-desktop-database .{INSTALL_TDE}/share/applications

# Update the mime database:
/usr/bin/update-mime-database usr/share/mime

# Update hicolor theme cache:
/usr/bin/gtk-update-icon-cache -f -t .{INSTALL_TDE}/share/icons/hicolor


# update PATH
# upgradepkg runs this twice, so even though {TQTDIR}/bin will be
# a new PATH, it needs to be tested for the second run
if ! grep {INSTALL_TDE}/bin /etc/profile
then
echo "PATH=\$PATH:{INSTALL_TDE}/bin:{TQTDIR}/bin" >> /etc/profile
else
if ! grep {TQTDIR}/bin /etc/profile
then
echo "PATH=\$PATH:{TQTDIR}/bin" >> /etc/profile
fi
fi


# update MANPATH
if ! grep {INSTALL_TDE}/man /etc/profile
then
echo "export MANPATH=\$MANPATH:{INSTALL_TDE}/man" >> /etc/profile
fi


## you may not want to do this ##
# start a 'konsole' with system-wide profile
[[ ! $(grep -x "source /etc/profile" $HOME/.bashrc ) ]] && echo "source /etc/profile" >> $HOME/.bashrc || true
# don't want this
sed -i 's|source /etc/profile.d/mc.sh|#source /etc/profile.d/mc.sh|' $HOME/.bashrc || true
