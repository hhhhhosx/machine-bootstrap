# Machine bootstrap

Unattended ssh based operating system installer for Ubuntu 20.04 LTS (Focal)

+ buildin recovery image based on casper of ubuntu 20.04
+ root storage on luks encrypted zfs and other specialized storage layouts,
+ dracut initrd with ssh support for remote luks open of encrypted data

**Usage:** to be executed on an linux liveimage/recoveryimage system connected via ssh.

It can be configured to fit different use cases, eg.
+ as a Desktop/Laptop
+ as a typical Rootserver (2xHD, headless)
+ as a home-nas/home-io headless server with one ssd and two attached spindle disks

**Status:** most combinations work, some break under certain conditions.

## Features

+ **efi and legacy bios** boot compatible hybrid grub setup with grubenv support
+ **one or two disks** (will be automatically setup as mdadm &/ zfs mirror if two disks)
+ **root on luks encrypted zfs** / zfs mirror pool (encrypted storage at rest)
    + and **other common and less common**, easy to configure **storage setups**
+ ubuntu: modern initial ramdisk based on **dracut with ssh for remote unlock luks** on startup, disabled reporting packages
+ **recovery system installation** (based on ubuntu 20.04 casper) on EFI partition
    + unattended cloud-init boot via custom squashfs with ssh ready to login
    + buildin scripts to mount/unmount root and update recovery boot parameter
+ **logging** of recovery and target system installation on the calling machine in directory ./log

### optional Features
+ luks encrypted **hibernate compatible swap** for eg. a desktop installation
+ ubuntu/debian: **gitops stage using saltstack** with states from salt-shared (eg. desktop)
+ **build a preconfigured livesystem image** usable for headless physical installation
    + resulting image is compatible as CD or USB-Stick with BIOS and EFI support
    + optional netplan for static or other non dhcp based ip configurations
    + execute `./machine-bootstrap/bootstrap.sh create-liveimage` to build image and copy to stick
    + use ssh with preconfigured key or physical terminal/console of livesystem for interaction
+ **encrypt sensitive data** in setup repository with git-crypt
    + git & git-crypt repository setup to store machine configuration inside a git repository

#### Example Configurations

+ a root server with custom network (eg. static ip)
    + add custom `netplan.yaml`
+ a laptop with encrypted hibernation:
    + add `storage_opts="--swap=yes"` to `node.env`
+ a vm with a http proxy on its host:
    + add `http_proxy="http://proxyip:port"`to `node.env`
+ install ubuntu eoan instead of focal:
    + add `distrib_codename=eoan` to `node.env`

##### Storage Examples

+ virtual machine with root on ext4
    + `storage_opts="--boot=false --root-fs=ext4 --root-crypt=false"`
+ virtual machine with encrypted root on ext4
    + `storage_opts="--root-fs=ext4"`
+ virtual machine with encrypted lvm and root lv (30gb) on ext4
    + `storage_opts="--root-fs=ext4 --root-lvm=vgroot --root-lvm-vol-size=30720"`
+ desktop: encrypted root and swap, root on zfs
    + `storage_opts="--swap=true"`
+ server: one or two disks, encrypted root on zfs
    + `storage_opts=""`
+ server: one or two disks, encrypted
    with lvm storage (100gb) where root (25gb) is placed and zfs is used on data (rest of disk)
    + `storage_opts="--root-fs=ext4 --root-size=102400 --root-lvm=vgroot --root-lvm-vol-size=25600" --data-fs=zfs"`
+ server: one or two encrypted disks, root on zfs (100g), with data lvm storage vgdata
    + `storage_opts="--root-size=102400 --data-lvm=vgdata --data-lvm-vol-size=25600" --data-fs=ext4"`

## Setup

Requirements:

+ Minimum RAM: 2GB RAM
+ Minimum Storage
    + 10GB (no swap, console)
    + \+ ~5GB (with swap for 4gb memory)
    + \+ ~5GB (full desktop installation)

### make a new project repository (eg. box)
```bash
mkdir box
cd box
git init
mkdir -p config log run
printf "# machine-bootstrap ignores\n/log\n/run\n" > .gitignore
git submodule add https://github.com/wuxxin/machine-bootstrap.git
git add .
git commit -v -m "initial config"
```

### optional: add an upstream
```bash
git remote add origin ssh://git@some.where.net/path/box.git
git push -u origin master
```

### optional: add files for a gitops run (only ubuntu/debian)
```bash
mkdir -p salt/custom
pushd salt
git submodule add https://github.com/wuxxin/salt-shared.git
popd
cat > config/top.sls << EOF
base:
  '*':
    - main
EOF
cp salt/salt-shared/gitops/config.template.sls config/config.sls
cp salt/salt-shared/gitops/pillar.template.sls config/main.sls
cp salt/salt-shared/gitops/state.template.sls salt/custom/top.sls
printf "  '*':\n    - machine-bootstrap\n\n" >> salt/custom/top.sls
touch salt/custom/main.sls
ln -s "../../machine-bootstrap" salt/custom/machine-bootstrap
git add .
git commit -v -m "add saltstack skeleton"
```

### optional: git-crypt config

```bash
git-crypt init
cat > .gitattributes <<EOF
**/secret/** filter=git-crypt diff=git-crypt
**/secrets/** filter=git-crypt diff=git-crypt
*secrets* filter=git-crypt diff=git-crypt
*secret* filter=git-crypt diff=git-crypt
*key filter=git-crypt diff=git-crypt
*keys filter=git-crypt diff=git-crypt
*id_rsa* filter=git-crypt diff=git-crypt
*id_ecdsa* filter=git-crypt diff=git-crypt
*id_ed25519* filter=git-crypt diff=git-crypt
*.sec* filter=git-crypt diff=git-crypt
*.key* filter=git-crypt diff=git-crypt
*.pem* filter=git-crypt diff=git-crypt
*.p12 filter=git-crypt diff=git-crypt
credentials* filter=git-crypt diff=git-crypt
csrftokens* filter=git-crypt diff=git-crypt
random_seed filter=git-crypt diff=git-crypt
EOF
git-crypt add-gpg-user user.email@address.org
git add .
git commit -v -m "add git-crypt config"
```

### optional: add machine git-crypt user
```

```

### configure machine

```bash
cat > config/node.env <<EOF
# mandatory
sshlogin=root@1.2.3.4
hostname=box.local
firstuser=$(id -u -n)
# storage_ids=""

# optional

# http_proxy="http://192.168.122.1:8123" # default ""
# distrib_id="Nixos" # default "Ubuntu"
# distrib_codename="19.09-small" # default "focal"
# recovery_autologin="true" # default "false"

# gitops_user="$firstuser" # default $firstuser
# gitops_target="/home/$firstuser" # default /home/$firstuser
# gitops_source=""
# gitops_branch=""

# storage_opts=""
# [--reuse]
# [--efi-size=   <efisizemb, default: 2200 mb>]
# [--boot=       true|*false|<bootsizemb,  default if true: 400 mb>]
# [--boot-fs=    *zfs|ext4|xfs]
# [--swap=       true|*false|<swapsizemb,  default if true: 1.25xRAM mb>]
# [--log=        true|*false|<logsizemb,   default if true: 1024 mb>]
# [--cache=      true|*false|<cachesizemb, default if true: 59918 mb (eq. 1gb RAM)>]

# [--root-fs=    *zfs|ext4|xfs]
# [--root-size=  *all|<rootsizemb>]
# [--root-crypt= *true|false]
# [--root-lvm=   *""|<vgname>]
# [--root-lvm-vol-size= <volsizemb, default if lvm is true: 20480 mb>]

# [--data-fs=    *""|zfs|ext4|xfs|other, if not empty: --root-size must be set]
# [--data-crypt= *true|false]
# [--data-lvm=   *""|<vgname>]
# [--data-lvm-vol-size= <volsizemb, default if lvm is true: 20480 mb>]

EOF

# copy current user ssh public key as authorized_keys
cat ~/.ssh/id_rsa.pub ~/.ssh/id_ed25519.pub \
    > config/authorized_keys

# list serial(s) of harddisk(s)
./machine-bootstrap/connect.sh temporary "ls /dev/disk/by-id/"

# add serial(s) to config, eg. filter all virtio (but no partitions)
echo $(printf 'storage_ids="'; for i in \
    $(./machine-bootstrap/connect.sh temporary "ls /dev/disk/by-id/" | \
        grep -E "^virtio-[^-]+$"); do \
    printf "$i "; done; printf '"') >> config/node.env

# create disk.passphrase.gpg
# example: create a random diskphrase and encrypted with user gpg key
(x=$(openssl rand -base64 16); echo -n "$x" | \
    gpg --encrypt -r username@email.address) \
    > config/disk.passphrase.gpg

```

### optional: add ssh credentials for git repository cloning on target

+ if gitops_source is empty, rsync will be used to transfer the files to the target
+ if gitops_source is set, the script will clone the repository files on target
+ if gitops_source is a ssh git url, additional files are needed in config dir
    + gitops.id_ed25519, gitops.id_ed25519.pub, gitops_known_hosts
```bash
ssh-keygen -q -t ed25519 -N '' -C 'gitops@box' -f config/gitops.id_ed25519
ssh-keyscan -H -p 10023 git.server.domain > config/gitops.known_hosts
```

### optional: add gpg key for git-crypt encrypted files access

+ if git-crypt is used on repository files, additional files are needed in config dir
    + gitops@node-secret-key.gpg gitops@node-public-key.gpg
```bash
gpgutils.py gen_keypair gitops@node "box" config/gitops@node-secret-key.gpg config/gitops@node-public-key.gpg
```

### optional: create a custom netplan.yaml file

```bash
cat > config/netplan.yaml << EOF
network:
  version: 2
  ethernets:
    all-en:
      match:
        name: "en*"
      dhcp4: true
    all-eth:
      match:
        name: "eth*"
      dhcp4: true
EOF
```

### optional: create a minimal Nixos configuration.nix

```bash
cat > config/configuration.nix << EOF
# Help is available in the configuration.nix(5) man page
{ config, pkgs, ... }:
{
  imports =
    [ # Include the results of the hardware scan and machine-bootstrap scripts
      ./hardware-configuration.nix
      ./machine-bootstrap-configuration.nix
    ];
}
EOF
```

### optional: make physical bootstrap-0 liveimage

create-liveimage creates an iso hybrid image usable as CD or usb-stick,
bootable via efi or bios.

this can be useful eg. if the target is headless,
or inside an emulator supplied with a live image preconfigured with ssh and other keys.

```bash
./machine-bootstrap/bootstrap.sh create-liveimage
# copy run/liveimage/bootstrap-0-liveimage.iso to usbstick
# boot target machine from usbstick
```

## Installation

installation is done in 4 steps:

+ 1 initial live system: partition disk, recovery install to EFI partition, reboot into recovery
+ 2 recovery live system: build patches, create boot & root, debootstrap, configure system, chroot into target
+ 3 recovery chroot target: configure system, kernel, initrd, install standard software, reboot into target
+ 4 target system: install and run saltstack

```bash
# test if everything needed is there
./machine-bootstrap/bootstrap.sh test

# if alls looks fine, commit config
git add .
git commit -v -m "bootstrap run"

# run all steps (recovery, install, gitops) combined
./machine-bootstrap/bootstrap.sh execute all box.local

# or each step seperate
./machine-bootstrap/bootstrap.sh execute recovery box.local
./machine-bootstrap/bootstrap.sh execute install box.local
./machine-bootstrap/bootstrap.sh execute gitops box.local

# logs of each step will be written to log/bootstrap-*.log
# but log directory is in .gitignore and content won't be comitted
```

### optional: push committed changes upstream

```bash
git push -u origin master

```

## Maintenance

### connect to machine

+ connect to target machine running in the temporary liveimage, in the recovery system, in the initrd of the productiton system, or the production system
```bash
./machine-bootstrap/connect.sh temporary|recovery|initrd|system
```

+ connect to initrd, open luks disks, exit, machine will continue to boot
```bash
./machine-bootstrap/connect.sh initrdluks
```

+ connect to recovery, open luks disks, mount storage, prepare chroot, shell
```bash
./machine-bootstrap/connect.sh recoverymount
```

### switch next boot to boot into recovery (from running target system)
```bash
grub-reboot recovery
reboot
```

## Notes

### Limits, Automatics, Contraints, Safety, Security

+ one or two disks only, if machine has more disks they have to be setup later

+ ZFS on two disks will get two seperate devices to let zfs manage the mirroring,
    any other filesystem combination will get an mdadm-mirror device.

+ SWAP
    if using a SWAP partition, the swap partition will always be encrypted.
    Also ROOT should be encrypted in this case.
    Suspend to disk has all memory secrets written to disk,
    so a suspend would store these secrets in plaintext to disk.
    if encryption of swap is not desired, a swap file can be created using
    create_file_swap() which is feature equal to the swap partition
    beside the suspend to disk functionality.

+ ZFS or LVM but not both on one partition
    on partittions ROOT and DATA, currently only either zfs or lvm can be used.
    if both are specified at the same time, the script will fail.

+ GPT Name Scheme information leakage
    be aware that, the way gpt labels are setup in this script, they leak metadata of encrypted data, eg. raid_luks_lvm.vg0_ext4_ROOT leaks the information that behind the luks encrypted data is a lvm partition with a volume group named vg0 and the root file system is ext4 (but not how to read this data). if this is an issue, rename the volume labels after bootstrap completed, mounts will still work because they are pointing to the uuid

### Partition (GPT) Layout

Nr |Name(max 36 x UTF16)|Description|
---|---|---
6  | `BIOS,1,2`  | GRUB-BIOS boot binary partition, used to host grub code on gpt for bios boot
5  | `EFI,1,2`   | EFI vfat partition, unencrypted
.  | .           | dual efi & bios grub installation
.  | .           | recovery system: kernel,initrd,fs
.  | .           | /boot for system: kernel,initrd
4  | `LOG,1,2`   | **optional** ZFS Log or other usages
3  | `CACHE,1,2` | **optional** ZFS Cache or other usages
2  | `[raid_]luks_SWAP,1,2`  | **optional** encrypted hibernation compatible swap
1  | `[raid_](zfs:ext4:xfs)_BOOT,1,2`  | **optional**,**legacy** boot partition, unencrypted, kernel,initrd
0  | `[raid_][luks_][lvm.vg0_](zfs:ext4:xfs)_ROOT,1,2` | root partition
7  | `[raid_][luks_][lvm.vgdata_](zfs:ext4:xfs:other)_DATA,1,2` | **optional** data partition
