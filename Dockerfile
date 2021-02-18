FROM archlinux

# XXX: seperate runs coz multiline fails with 127 : No such file or directory
RUN echo >> /etc/pacman.conf && \
    echo '[multilib]' >> /etc/pacman.conf && \
    echo 'Include = /etc/pacman.d/mirrorlist' >> /etc/pacman.conf && \
    curl -O https://blackarch.org/strap.sh && \
    echo d062038042c5f141755ea39dbd615e6ff9e23121 strap.sh | sha1sum -c && \
    chmod +x strap.sh
# set term to supress tput warnings
RUN TERM=dumb ./strap.sh


# install the packages
RUN pacman -Sy pacman-contrib --noconfirm
RUN curl -s 'https://archlinux.org/mirrorlist/?country=AU&protocol=https&ip_version=4&use_mirror_status=on' | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 5 - > /etc/pacman.d/mirrorlist

RUN pacman -Syu awk base-devel curl git gnu-netcat \
        metasploit nmap openvpn perl socat sploitctl stow tcpdump tmux vi wget \
        --noconfirm --needed

# set up the new user
# XXX: security consideration: from here on the passwd is in plaintext on disk
RUN PASSWD=`< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-32};echo;`; \
    useradd -m -G wheel cfa && echo 'cfa:'"$PASSWD" | chpasswd && \
    echo "$PASSWD" >> ~cfa/.passwd && \
    chown cfa:cfa ~cfa/.passwd && \
    echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' | sudo EDITOR='tee -a' visudo

    #echo '%wheel ALL=(ALL:ALL) ALL' | sudo EDITOR='tee -a' visudo

# tunnel logging
RUN mkdir -p /etc/network/if-up.d && \
    echo '#!/bin/sh' >> /etc/network/if-up.d/tun-up && \
    echo '[[ "$IFACE" == tun* ]] && tcpdump -n -e -q -i "$IFACE" -s 96 -w $(date -Iseconds)-network.log' >> /etc/network/if-up.d/tun-up
                        
# set up 
RUN sudo -u cfa sh -c "cd && \
    git clone --quiet --branch pentest https://www.github.com/cjfloresalonso/.s && \
    cd ~/.s && make pentest"

# get a couple aur packages

# the openbsd ksh (the good one)
RUN su - cfa -c "cd && mkdir -p aur && cd aur && \
    git clone -q https://aur.archlinux.org/oksh.git oksh && cd oksh && \
    git checkout -q 0f2b202f && \
    echo 7ae29da818ac1441489d329ceb0b1ec4a91eb8d9 PKGBUILD | sha1sum -c && \
    echo 883d21dcd814ac9446d19ee3044b9a22b5262bbb .SRCINFO | sha1sum -c && \
    MAKEFLAGS=-j makepkg -sirmc --noconfirm" && \
    ln -s /usr/bin/oksh /bin/ksh && \
    rm /bin/sh && \
    ln -s /usr/bin/oksh /bin/sh && \
    echo /bin/ksh >> /etc/shells && \
    chsh -s /bin/ksh cfa
