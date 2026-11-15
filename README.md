# fedora-edge-custom-installer

[tmpfsroot-fedora](https://github.com/seqsense/tmpfsroot-fedora) の仕組みでカスタムFedoraのインストール ISOを作成し、QEMUのVMでインストールや起動確認を行うもの。


## 動作条件
ホストで以下が動作していること。
- Docker
- qemu-system-x86_64
- edk2-ovmf
- ssh-keygen

## 使い方

```bash
make iso          # output/fedora-edge-custom.isoを作成する。
make vm-install   # 32 GB の仮想ディスクを作って ISO からインストールする。
make vm-run       # インストール済みディスクから仮想マシンを起動する。
make vm-ssh       # 仮想マシンにsshする。
make clean
```


## パーティション構成 (32 GB)

| Mount point | Size (MiB) | Filesystem | 用途 |
| --- | --- | --- | --- |
| /boot/efi | 200 | vfat | EFI |
| / (A) | 2048 | ext4 | Readonly rootfs (main/fallback) |
| / (B) | 2048 | ext4 | Readonly rootfs (main/fallback) |
| /persist | 200 | ext4 | Readonly persistent data |
| /var/log | 2048 | ext4 | Logs (automatically refreshed on failure) |
| /opt | 4096 | btrfs | User applications |
| /var/cache | 4096 | btrfs | User cache |
| /var/lib/docker | 14848 | btrfs | Docker |
