FROM archlinux:base-devel

RUN pacman -Syyu --noconfirm &&            \
    pacman -S --needed --noconfirm openssh \
    coreutils binutils git gnupg fakeroot  \
    awk tar xz bash grep                   \
    gcc clang llvm kmod initramfs pahole   \
    bc cpio libelf perl llvm lld python

RUN bash -c 'if ! grep -q ":<<<<GROUPID>>>>:" /etc/group ; then groupadd -g <<<<GROUPID>>>> <<<<GROUPNAME>>>>; fi'
RUN useradd  -u <<<<USERID>>>> -g <<<<GROUPID>>>> -s /bin/bash <<<<USERNAME>>>>
RUN mkdir -p <<<<TOP_BUILD_MOUNT_PATH>>>>
RUN chown <<<<USERID>>>>:<<<<GROUPID>>>> /home/<<<<USERNAME>>>>

COPY ENTRYPOINT.sh /ENTRYPOINT.sh
RUN  chmod +x /ENTRYPOINT.sh

USER <<<<USERNAME>>>>

ENTRYPOINT ["/ENTRYPOINT.sh"]
