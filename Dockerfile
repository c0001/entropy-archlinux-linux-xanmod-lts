FROM archlinux:base-devel

RUN pacman -Syyu --noconfirm &&            \
    pacman -S --needed --noconfirm openssh \
    coreutils binutils git gnupg fakeroot  \
    awk tar xz                             \
    gcc clang llvm kmod initramfs pahole   \
    bc cpio libelf perl llvm lld python

RUN groupadd -g <<<<GROUPID>>>> builder
RUN useradd  -u <<<<USERID>>>> -g <<<<GROUPID>>>> -s /bin/bash builder
RUN mkdir -p /home/builder/project/linux-xanmod-lts
RUN chown builder:builder /home/builder

COPY ENTRYPOINT.sh /ENTRYPOINT.sh
RUN  chmod +x /ENTRYPOINT.sh

USER builder

ENTRYPOINT ["/ENTRYPOINT.sh"]
