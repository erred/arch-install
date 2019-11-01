#!/usr/bin/env bash

set -euxo pipefail

pacman-key --init
pacman-key --populate archlinux
pacman -Sy --noconfirm reflector
reflector --save /etc/pacman.d/mirrorlist -f 5 -l 20 -p https

pacstrap /mnt base base-devel linux linux-firmware intel-ucode \
  zsh wpa_supplicant git sway docker sudo \
  go{,-tools} htop man-{db,pages} neovim python{,2,-neovim} \
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
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
echo $_host > /etc/hostname
cat << RESOLV > /etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.8.8
nameserver 2001:4860:4860::8888
RESOLV
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
cat << USERINSTALL > /user.sh
#!/usr/bin/env zsh

set -euxo pipefail

git clone https://github.com/seankhliao/config .config
sudo ln -s /home/$_user/.config/zsh/zshenv /etc/zsh/zshenv

git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin && makepkg -si && cd ..
yay -S wl-clipboard-x11 tag-ag

git clone https://github.com/seankhliao/pkgbuilds
cd pkgbuilds/sway-service && makepkg -si && cd ..
mkdir -p data/{down,screen,xdg/{nvim/{backup,undo},zsh}}

USERINSTALL
#
# end post user
#
chmod +x /user.sh

su -c /user.sh - $_user


POSTCHROOT
#
# END post chroot
#
chmod +x /mnt/install.sh
arch-chroot /mnt /install.sh

echo "\n\n\tTODO:"
echo "\t\tcheck /mnt/etc/fstab for errors (bind mount)"
echo "\t\tsetup boot entry with uuid"
echo "\t\tset passwd for root"
echo "\t\tset passwd for $_user"
