FROM archlinux:base-devel

RUN pacman -Syyu --noconfirm && \
    pacman -S --needed --noconfirm openssh \
    git fakeroot binutils gcc awk binutils xz \
    libarchive bzip2 coreutils file findutils \
    gettext grep gzip sed ncurses

RUN groupadd -g <<<<GROUPID>>>> builder
RUN useradd  -u <<<<USERID>>>> -g <<<<GROUPID>>>> -s /bin/bash builder
RUN mkdir -p /home/builder/project/linux-xanmod-lts
RUN chown builder:builder /home/builder

COPY ENTRYPOINT.sh /ENTRYPOINT.sh
RUN  chmod +x /ENTRYPOINT.sh

USER builder

ENTRYPOINT ["/ENTRYPOINT.sh"]
