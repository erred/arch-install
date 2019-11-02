#!/usr/bin/env bash

set -euxo pipefail

pacman-key --init
pacman-key --populate archlinux
pacman -Sy --noconfirm reflector
reflector --save /etc/pacman.d/mirrorlist -f 5 -l 20 -p https

pacstrap /mnt base base-devel linux linux-firmware intel-ucode \
  zsh wpa_supplicant git sway docker sudo \
  go{,-tools} htop man-{db,pages} neovim python{,2,-neovim} prettier \
  reflector exa ripgrep aria2 openssh zsh-completions yubikey-manager \
  xf86-video-intel swaylock mako i3status bemenu grim slurp playerctl \
  brightnessctl alsa-utils kitty xorg-server-xwayland noto-fonts{,-emoji,-cjk} ttf-ibm-plex
genfstab -U /mnt >> /mnt/etc/fstab

#
# BEGIN post chroot
#

_tz=Europe/Amsterdam
_host=eevee
_user=arccy
cat << POSTCHROOT > /mnt/install.sh
#!/usr/bin/env zsh

set -euxo pipefail


pacman-key --init
pacman-key --populate archlinux
ln -sf /usr/share/zoneinfo/$_tz /etc/localtime
hwclock --systohc
sed -i 's/auth      required  pam_unix.so     try_first_pass nullok/auth      required  pam_unix.so     try_first_pass nullok nodelay/'

sed -i 's/#UseSyslog/UseSyslog/' /etc/pacman.conf
sed -i 's/#Color/Color/' /etc/pacman.conf
sed -i 's/#TotalDownload/TotalDownload/' /etc/pacman.conf
sed -i 's/#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
sed -i 's/#DefaultTimeoutStartSec=90s/DefaultTimeoutStartSec=10s/' /etc/systemd/user.conf /etc/systemd/system.conf
sed -i 's/#DefaultTimeoutStopSec=90s/DefaultTimeoutStopSec=10s/' /etc/systemd/user.conf /etc/systemd/system.conf
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
echo $_host > /etc/hostname

cat << RESOLVEOF > /etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.8.8
nameserver 2001:4860:4860::8888
RESOLVEOF

cat << HOSTSEOF > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $_host.localdomain  $_host
HOSTSEOF

rm -rf /etc/skel/.*
sed -i 's|/bin/bash|/bin/zsh|' /etc/default/useradd
groupadd -r sudo
useradd -m -G adm,log,wheel,docker $_user
sed -i 's/# %wheel/%wheel/' /etc/sudoers

#
# begin post user
#
cat << USERINSTALL > /home/$_user/user.sh
#!/usr/bin/env zsh

set -euxo pipefail

git clone https://github.com/seankhliao/pkgbuilds
git clone https://aur.archlinux.org/yay-bin.git
git clone https://github.com/seankhliao/config .config

sudo ln -sf /home/$_user/.config/zsh/zshenv /etc/zsh/zshenv

cd yay-bin && makepkg -si --noconfirm && cd ~
yay -S wl-clipboard-x11 tag-ag neovim-plug-git google-chrome{,-dev}
nvim +PlugInstall +q +q

cd pkgbuilds/sway-service && makepkg -si --noconfirm && cd ~
mkdir -p data/{down,screen,xdg/{nvim/{backup,undo},zsh}}

USERINSTALL
#
# end post user
#
chown $_user:$_user /home/$_user/user.sh
chmod +x /home/$_user/user.sh

sudo systemctl enable --now docker.socket wpa_supplicant

# su -c /user.sh - $_user


POSTCHROOT
#
# END post chroot
#
chmod +x /mnt/install.sh
arch-chroot /mnt /install.sh

unset -x
echo "\n\n  TODO:"
echo "      check /mnt/etc/fstab for errors (bind mount)"
echo "      setup boot entry with uuid"
echo "      set passwd for root"
echo "      set passwd for $_user"
echo "      run ~/user.sh"
