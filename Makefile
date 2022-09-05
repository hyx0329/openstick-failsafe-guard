# The installer

PREFIX ?=
ENABLE ?= 0

.PHONY : install-basics install-all
.PHONY : install-startup-diagnose install-button-monitor install-gc-manager install-sim-changer
.PHONY : install-sshkey-regen install-expanddisk

install-startup-diagnose :
	install -D -o root -g root -m 644 -t $(PREFIX)/etc/systemd/system/ openstick-startup-diagnose/*.service 
	install -D -o root -g root -m 644 -t $(PREFIX)/etc/systemd/system/ openstick-startup-diagnose/*.timer 
	install -D -o root -g root -m 755 -t $(PREFIX)/usr/sbin/ openstick-startup-diagnose/*.sh 
	if [ 1 -eq $(ENABLE) ]; then systemctl enable openstick-startup-diagnose.timer; fi

install-button-monitor :
	install -D -o root -g root -m 644 -t $(PREFIX)/etc/systemd/system/ openstick-button-monitor/*.service 
	install -D -o root -g root -m 755 -t $(PREFIX)/usr/sbin/ openstick-button-monitor/*.sh 
	if [ 1 -eq $(ENABLE) ]; then systemctl enable openstick-button-monitor.service; fi

install-gc-manager :
	install -D -o root -g root -m 644 -t $(PREFIX)/etc/systemd/system/ openstick-gc-manager/*.service 
	install -D -o root -g root -m 755 -t $(PREFIX)/usr/sbin/ openstick-gc-manager/*.sh 
	if [ 1 -eq $(ENABLE) ]; then systemctl enable openstick-gc-manager.service; fi

install-sim-changer :
	install -D -o root -g root -m 644 -t $(PREFIX)/etc/systemd/system/ openstick-sim-changer/*.service 
	install -D -o root -g root -m 755 -t $(PREFIX)/usr/sbin/ openstick-sim-changer/*.sh 
	if [ 1 -eq $(ENABLE) ]; then systemctl enable openstick-sim-changer.service; fi

install-sshkey-regen :
	install -D -o root -g root -m 644 -t $(PREFIX)/etc/systemd/system/ regenerate-ssh-host-keys.service 
	if [ 1 -eq $(ENABLE) ]; then systemctl enable regenerate-ssh-host-keys.service; fi

install-expanddisk :
	install -D -o root -g root -m 644 -t $(PREFIX)/etc/systemd/system/ openstick-expanddisk-startup/*.service 
	install -D -o root -g root -m 755 -t $(PREFIX)/usr/sbin/ openstick-expanddisk-startup/*.sh 
	if [ 1 -eq $(ENABLE) ]; then systemctl enable openstick-expanddisk-startup.service; fi

install-binaries :
	install -D -o root -g root -m755 bin/gc-static $(PREFIX)/usr/bin/gc
	install -D -o root -g root -m755 bin/adbd-static $(PREFIX)/usr/bin/adbd

install-basics : install-startup-diagnose install-button-monitor install-gc-manager

install-all : install-basics install-sim-changer install-sshkey-regen install-expanddisk install-binaries

firmware-%.deb :
	fakeroot -- sh -c "chown -R root:root ./firmwares/$(subst .deb,,$@) && dpkg-deb --build firmwares/$(subst .deb,,$@)"
	mv firmwares/$@ .

create-firmwares-deb : firmware-ufi001c.deb firmware-ufi003.deb

openstick-utils.deb :
	cp -r package openstick-utils
	fakeroot -- sh -c "PREFIX=./openstick-utils $(MAKE) install-all && dpkg-deb --build openstick-utils"

create-deb : openstick-utils.deb

all-deb : create-deb create-firmwares-deb

clean-deb :
	-rm -f *.deb
	-rm -f firmwares/*.deb
	-rm -rf openstick-utils

.DEFAULT : install-basics

