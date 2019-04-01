.PHONY: all
all: TinyEMU-iOS.xcodeproj

TinyEMU-iOS.xcodeproj: project.yml Assets/Machine.bundle
	xcodegen

Assets/Machine.bundle: Downloads/kernel.tar.gz Downloads/root.img.bz2
	rm -rf $@.tmp
	mkdir -p $@.tmp
	tar -O -xf Downloads/kernel.tar.gz diskimage-linux-riscv-2018-09-23/bbl64.bin >$@.tmp/bbl.bin
	tar -O -xf Downloads/kernel.tar.gz diskimage-linux-riscv-2018-09-23/kernel-riscv64.bin >$@.tmp/kernel.bin
	bzcat Downloads/root.img.bz2 >$@.tmp/root.img
	chmod -x $@.tmp/*
	@echo -n '<?xml version="1.0" encoding="UTF-8"?>' >$@.tmp/Machine.plist
	@echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >$@.tmp/Machine.plist
	@echo '<plist version="1.0">' >>$@.tmp/Machine.plist
	@echo '<dict/>' >>$@.tmp/Machine.plist
	@echo '</plist>' >>$@.tmp/Machine.plist
	plutil -insert BIOS -string bbl.bin $@.tmp/Machine.plist
	plutil -insert Kernel -string kernel.bin $@.tmp/Machine.plist
	plutil -insert KernelCommandLine -string 'console=hvc0 root=/dev/vda ro' $@.tmp/Machine.plist
	plutil -insert RootDrive -string root.img $@.tmp/Machine.plist
	mv $@.tmp $@

Downloads/kernel.tar.gz:
	mkdir -p Downloads
	curl -L -o $@.tmp https://bellard.org/tinyemu/diskimage-linux-riscv-2018-09-23.tar.gz
	@echo '808ecc1b32efdd76103172129b77b46002a616dff2270664207c291e4fde9e14  Downloads/kernel.tar.gz.tmp' >$@.tmp.sha256
	shasum -a 256 -c $@.tmp.sha256
	mv $@.tmp $@

Downloads/root.img.bz2:
	mkdir -p Downloads
	curl -L -o $@.tmp https://github.com/fernandotcl/TinyEMU-iOS-Images/releases/download/2019-04-01/root.img.bz2
	@echo '3cddbcf608aa2393b82a6769623713305e2aa29cc271bb79b2ecfd163f4575fa  Downloads/root.img.bz2.tmp' >$@.tmp.sha256
	shasum -a 256 -c $@.tmp.sha256
	mv $@.tmp $@

clean:
	rm -rf TinyEMU-iOS.xcodeproj Assets/Machine.bundle Downloads
