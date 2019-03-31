.PHONY: all
all: TinyEMU-iOS.xcodeproj

TinyEMU-iOS.xcodeproj: project.yml Assets/Machine.bundle
	xcodegen

Assets/Machine.bundle: machine.tar.gz
	rm -rf $@.tmp
	mkdir -p $@.tmp
	tar -O -xf $< diskimage-linux-riscv-2018-09-23/bbl64.bin >$@.tmp/bbl.bin
	tar -O -xf $< diskimage-linux-riscv-2018-09-23/kernel-riscv64.bin >$@.tmp/kernel.bin
	tar -O -xf $< diskimage-linux-riscv-2018-09-23/root-riscv64.bin >$@.tmp/root.img
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

machine.tar.gz:
	curl -o $@.tmp https://bellard.org/tinyemu/diskimage-linux-riscv-2018-09-23.tar.gz
	mv $@.tmp $@

clean:
	rm -rf TinyEMU-iOS.xcodeproj Assets/Machine.bundle machine.tar.gz
