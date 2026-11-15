SHELL := /bin/bash
.SHELLFLAGS := -eu -c

FEDORA_MAJOR  ?= 44
BUILDER_IMAGE ?= ghcr.io/seqsense/tmpfsroot-fedora-builder:$(FEDORA_MAJOR)
UPDATER_IMAGE ?= ghcr.io/seqsense/tmpfsroot-fedora-updater:$(FEDORA_MAJOR)

export DISK_DEVS       ?= vda
export MAIN_DISK       ?= vda
export PARTSIZE_LOG    ?= 2048
export PARTSIZE_OPT    ?= 4096
export PARTSIZE_CACHE  ?= 4096
export PARTSIZE_DOCKER ?= 14848

TARGET_HOSTNAME ?= edge

VM_DISK_SIZE ?= 32000000000
VM_SSH_PORT  ?= 2222
OVMF_CODE    ?= /usr/share/edk2/ovmf/OVMF_CODE_4M.qcow2
OVMF_VARS    ?= /usr/share/edk2/ovmf/OVMF_VARS_4M.qcow2

ISO := output/fedora-custom.iso
VM  := $(CURDIR)/vm

.PHONY: iso rpm-lock check clean vm-install vm-run vm-ssh

iso: $(VM)/id_ed25519
	rm -rf build/ks
	mkdir -p build/ks output cache/dnf cache/downloads
	cp ks/*.cfg build/ks/
	echo "network --hostname=$(TARGET_HOSTNAME)" >> build/ks/ks.root.cfg
	echo "sshkey --username=root \"$$(cat $(VM)/id_ed25519.pub)\"" >> build/ks/ks.root.cfg
	docker run -i --rm \
	  -v "$(CURDIR)/packages.list:/work/packages.list:ro" \
	  -v "$(CURDIR)/rpms.lock:/work/rpms.lock:ro" \
	  -v "$(CURDIR)/build/ks:/work/ks:ro" \
	  -v "$(CURDIR)/hooks.d:/work/hooks.d:ro" \
	  -v "$(CURDIR)/root.override:/work/root.override:ro" \
	  -v "$(CURDIR)/iso-root.override:/work/iso-root.override:ro" \
	  -v "$(CURDIR)/cache/dnf:/var/cache/dnf" \
	  -v "$(CURDIR)/cache/downloads:/work/downloads" \
	  -v "$(CURDIR)/output:/work/output" \
	  -e DISK_DEVS \
	  -e MAIN_DISK \
	  -e PARTSIZE_LOG \
	  -e PARTSIZE_OPT \
	  -e PARTSIZE_CACHE \
	  -e PARTSIZE_DOCKER \
	  $(BUILDER_IMAGE)

rpm-lock:
	mkdir -p build/updater cache/dnf
	cp packages.list build/updater/
	docker run -i --rm \
	  -v "$(CURDIR)/build/updater:/work" \
	  -v "$(CURDIR)/cache/dnf:/var/cache/dnf" \
	  $(UPDATER_IMAGE)
	cp build/updater/rpms.lock rpms.lock

clean:
	rm -rf build output

QEMU = qemu-system-x86_64 \
  -machine q35,accel=kvm \
  -cpu host \
  -smp 2 \
  -m 4096 \
  -drive if=pflash,format=qcow2,readonly=on,file=$(OVMF_CODE) \
  -drive if=pflash,format=qcow2,file=$(VM)/OVMF_VARS.qcow2 \
  -drive file=$(VM)/disk.qcow2,format=qcow2,if=none,id=disk0 \
  -device virtio-blk-pci,drive=disk0,bootindex=1 \
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:$(VM_SSH_PORT)-:22 \
  -device virtio-net-pci,netdev=net0

$(VM)/id_ed25519:
	mkdir -p $(VM)
	ssh-keygen -q -t ed25519 -N '' -f $@

$(VM)/disk.qcow2:
	mkdir -p $(VM)
	qemu-img create -q -f qcow2 $@ $(VM_DISK_SIZE)

$(VM)/OVMF_VARS.qcow2:
	mkdir -p $(VM)
	cp $(OVMF_VARS) $@

vm-install: $(VM)/disk.qcow2 $(VM)/OVMF_VARS.qcow2
	$(QEMU) \
	  -display none \
	  -monitor none \
	  -no-reboot \
	  -chardev stdio,id=ser0,logfile=$(VM)/install.log \
	  -serial chardev:ser0 \
	  -drive file=$(ISO),media=cdrom,if=none,id=cd0,readonly=on \
	  -device ide-cd,drive=cd0,bootindex=0

vm-run: $(VM)/disk.qcow2 $(VM)/OVMF_VARS.fd
	$(QEMU) \
	  -display none \
	  -monitor none \
	  -no-reboot \
	  -chardev stdio,id=ser0,logfile=$(VM)/console.log \
	  -serial chardev:ser0

vm-ssh:
	ssh -p $(VM_SSH_PORT) -i $(VM)/id_ed25519 \
	  -o IdentitiesOnly=yes \
	  -o StrictHostKeyChecking=no \
	  -o UserKnownHostsFile=/dev/null \
	  root@127.0.0.1
