INSTALL_DIR ?= /usr

.PHONY: default install uninstall 

default:
	@echo "make install|uninstall"

install:
	@echo "Installing..."
	@install -d ${INSTALL_DIR}/bin
	@install -d ${INSTALL_DIR}/share/suncron/lib/Astro
	@install -d /etc/default
	@install -m755 src/suncron.pl ${INSTALL_DIR}/bin/suncron
	@sed < src/suncron.sh >/tmp/suncron.sh -e "s#SUNCRON_PATH#${INSTALL_DIR}#"
	@install -m755 /tmp/suncron.sh /etc/cron.daily/suncron
	@rm -f /tmp/suncron.sh
	@install -m644 src/suncron.conf /etc/default/suncron
	@install -m644 README.md ${INSTALL_DIR}/share/suncron
	@install -m644 LICENSE ${INSTALL_DIR}/share/suncron
	@install -m755 src/lib/CalcTime.pm ${INSTALL_DIR}/share/suncron/lib
	@install -m755 src/lib/ConfigFile.pm ${INSTALL_DIR}/share/suncron/lib
	@install -m755 src/lib/Astro/Sunrise.pm ${INSTALL_DIR}/share/suncron/lib/Astro
	@echo "Done."
	@echo "A sample configuration file has been copied to '/etc/default/suncron'."
	@echo "Existing file has a '~' appended."
	@echo "You need to change the coordinates and time zone information in order to get"
	@echo "correct calculation for sunset and sunrise. The configuration file also contain"
	@echo "two sample entries showing the format of rules."
	@echo "A cron script has been added to /etc/cron.daily so that new entris are made"
	@echo "every day. Verify the daily cron jobs are run at about midnight."

uninstall:
	@echo "Uninstalling..."
	@rm -f /etc/cron.daily/suncron
	@rm -f /etc/cron.d/suncron
	@rm -f ${INSTALL_DIR}/bin/suncron
	@rm -f /etc/default/suncron
	@rm -Rf ${INSTALL_DIR}/share/suncron
	@echo "Done"

