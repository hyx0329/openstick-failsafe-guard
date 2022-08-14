# The installer

.PHONY : install-basics install-all
.PHONY : install-startup-diagnose install-button-monitor install-gc-startup install-sim-changer
.PHONY : install-sshkey-regen install-expanddisk

install-startup-diagnose :
	install -o root -g root -m 644 openstick-startup-diagnose/openstick-startup-diagnose.service /etc/systemd/system/
	install -o root -g root -m 644 openstick-startup-diagnose/openstick-startup-diagnose.timer /etc/systemd/system/
	install -o root -g root -m 755 openstick-startup-diagnose/openstick-startup-diagnose.sh /usr/sbin/
	systemctl enable openstick-startup-diagnose.timer

install-button-monitor :
	install -o root -g root -m 644 openstick-button-monitor/openstick-button-monitor.service /etc/systemd/system/
	install -o root -g root -m 755 openstick-button-monitor/openstick-button-monitor.sh /usr/sbin/
	systemctl enable openstick-button-monitor.service

install-gc-startup :
	install -o root -g root -m 644 openstick-gc-startup/openstick-gc-startup.service /etc/systemd/system/
	install -o root -g root -m 644 openstick-gc-startup/adbd.service /etc/systemd/system/
	install -o root -g root -m 755 openstick-gc-startup/openstick-gc-startup.sh /usr/sbin/
	systemctl enable openstick-gc-startup.service

install-sim-changer :
	install -o root -g root -m 644 openstick-sim-changer/openstick-sim-changer.service /etc/systemd/system/
	install -o root -g root -m 755 openstick-sim-changer/openstick-sim-changer.sh /usr/sbin/
	systemctl enable openstick-sim-changer.service

install-sshkey-regen :
	install -o root -g root -m 644 regenerate-ssh-host-keys.service /etc/systemd/system/
	systemctl enable regenerate-ssh-host-keys.service

install-expanddisk :
	install -o root -g root -m 644 openstick-expanddisk-startup/openstick-expanddisk-startup.service /etc/systemd/system/
	install -o root -g root -m 755 openstick-expanddisk-startup/openstick-expanddisk-startup.sh /usr/sbin/
	systemctl enable openstick-expanddisk-startup.service

install-basics : install-startup-diagnose install-button-monitor install-gc-startup

install-all : install-basics install-sim-changer install-sshkey-regen install-expanddisk

.DEFAULT : install-basics

