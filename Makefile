# Because our project includes some C artifacts like rhsmd and rhsm_icon, the standard
# Python setup.py doesn't cover all our bases.  Additionally, setuptools does not like
# to install files outside of /usr (see http://stackoverflow.com/a/13476594/6124862).
#
# Therefore the Makefile performs the master build, but please keep the following guidelines
# in mind when updating it:
#
# * If the file goes under /usr, put it in setup.py
# * Linting checks, etc. should be implemented in Python and invoked via setup.py
# * If functionality cannot be added to setup.py without extensive effort, place the
#   functionality in the Makefile.  Otherwise, add it to setup.py.
# * The ultimate goal is to have a clean build process so do things the best way, not
#   just the fastest or easiest way.

SHELL := /bin/bash
PYTHON ?= python
DESTDIR ?= /
PREFIX ?= /usr/local
SYSCONF ?= etc
INSTALL_DIR = $(PREFIX)/share

OS = $(shell lsb_release -i | awk '{ print $$3 }' | awk -F. '{ print $$1}')
OS_VERSION = $(shell lsb_release -r | awk '{ print $$2 }' | awk -F. '{ print $$1}')
OS_DIST ?= $(shell rpm --eval='%dist')

PYTHON_VER ?= $(shell $(PYTHON) -c 'import sys; print("python%s.%s" % sys.version_info[:2])')

PYTHON_SITELIB ?= $(PREFIX)/lib/$(PYTHON_VER)/site-packages
# Note the underscore used instead of a hyphen
PYTHON_INST_DIR = $(PYTHON_SITELIB)/subscription_manager

# Where various bits of code live in the git repo
SRC_DIR := src/subscription_manager
RCT_SRC_DIR := src/rct
RHSM_ICON_SRC_DIR := src/rhsm_icon
DAEMONS_SRC_DIR := src/daemons
CONTENT_PLUGINS_SRC_DIR := src/content_plugins/

ANACONDA_ADDON_NAME = com_redhat_subscription_manager
ANACONDA_ADDON_MODULE_SRC_DIR := src/initial-setup/$(ANACONDA_ADDON_NAME)

# dirs we install to
SYSTEMD_INST_DIR := $(PREFIX)/lib/systemd/system
RHSM_PLUGIN_DIR := $(PREFIX)/share/rhsm-plugins/
RHSM_PLUGIN_CONF_DIR := /etc/rhsm/pluginconf.d/
ANACONDA_ADDON_INST_DIR := $(PREFIX)/share/anaconda/addons
INITIAL_SETUP_INST_DIR := $(ANACONDA_ADDON_INST_DIR)/$(ANACONDA_ADDON_NAME)
POLKIT_ACTIONS_INST_DIR := $(INSTALL_DIR)/polkit-1/actions
LIBEXEC_DIR ?= $(shell rpm --eval='%_libexecdir')

# If we skip install ostree plugin, unset by default
# override from spec file for rhel6
INSTALL_OSTREE_PLUGIN ?= true

WITH_SYSTEMD ?= true

# Default differences between el6 and el7
ifeq ($(OS_DIST),.el6)
   GTK_VERSION?=2
   FIRSTBOOT_MODULES_DIR?=$(PREFIX)/share/rhn/up2date_client/firstboot
   INSTALL_FIRSTBOOT?=true
   INSTALL_INITIAL_SETUP?=false
else ifeq ($(findstring SUSE,$(OS)),SUSE)
   GTK_VERSION?=2
   FIRSTBOOT_MODULES_DIR?=$(PREFIX)/share/rhn/up2date_client/firstboot
   INSTALL_FIRSTBOOT?=true
   INSTALL_INITIAL_SETUP?=false
else
   GTK_VERSION?=3
   FIRSTBOOT_MODULES_DIR?=$(PREFIX)/share/firstboot/modules
   INSTALL_FIRSTBOOT?=true
   INSTALL_INITIAL_SETUP?=true
endif

# always true until fedora is just dnf
INSTALL_YUM_PLUGINS ?= true
YUM_PLUGINS_SRC_DIR := src/plugins

# for fc22 or newer
INSTALL_DNF_PLUGINS ?= false
DNF_PLUGINS_SRC_DIR := src/plugins

INSTALL_ZYPPER_PLUGINS ?= false

# sets a version that is more or less latest tag plus commit sha
VERSION ?= $(shell git describe | awk ' { sub(/subscription-manager-/,"")};1' )

# inherit from env if set so rpm can override
CFLAGS ?= -g -Wall
LDFLAGS ?=

RHSMCERTD_CFLAGS = `pkg-config --cflags glib-2.0`
RHSMCERTD_LDFLAGS = `pkg-config --libs glib-2.0`
ICON_CFLAGS=`pkg-config --cflags "gtk+-$(GTK_VERSION).0 libnotify gconf-2.0 dbus-glib-1"`
ICON_LDFLAGS=`pkg-config --libs "gtk+-$(GTK_VERSION).0 libnotify gconf-2.0 dbus-glib-1"`

PYFILES := `find src/ test/ -name "*.py"`
BIN_FILES := bin/subscription-manager bin/subscription-manager-gui \
			 bin/rhn-migrate-classic-to-rhsm \
			 bin/rct \
			 bin/rhsm-debug
STYLEFILES=$(PYFILES) $(BIN_FILES)

.DEFAULT_GOAL := build

build: rhsmcertd rhsm-icon
# Install doesn't perform a build if it doesn't have too.  Best to clean out
# any cruft so developers don't end up install old builds.
	$(PYTHON) ./setup.py clean --all
	$(PYTHON) ./setup.py build --quiet --gtk-version=$(GTK_VERSION) --rpm-version=$(VERSION)

# we never "remake" this makefile, so add a target so
# we stop searching for implicit rules on how to remake it
Makefile: ;

.PHONY: clean
clean:
	rm -f *.pyc *.pyo *~ *.bak *.tar.gz
	rm -f bin/rhsmcertd
	rm -f bin/rhsm-icon
	$(PYTHON) ./setup.py clean --all
	rm -rf cover/ htmlcov/ docs/sphinx/_build/ build/ dist/

.PHONY: mkdir-bin
mkdir-bin:
	mkdir -p bin

rhsmcertd: mkdir-bin $(DAEMONS_SRC_DIR)/rhsmcertd.c
	$(CC) $(CFLAGS) $(RHSMCERTD_CFLAGS) -DLIBEXECDIR='"$(LIBEXEC_DIR)"' $(DAEMONS_SRC_DIR)/rhsmcertd.c -o bin/rhsmcertd $(LDFLAGS) $(RHSMCERTD_LDFLAGS)

rhsm-icon: mkdir-bin $(RHSM_ICON_SRC_DIR)/rhsm_icon.c
	$(CC) $(CFLAGS) $(ICON_CFLAGS) $(RHSM_ICON_SRC_DIR)/rhsm_icon.c -o bin/rhsm-icon $(LDFLAGS) $(ICON_LDFLAGS)

.PHONY: check-syntax
check-syntax:
	$(CC) -fsyntax-only $(CFLAGS) $(LDFLAGS) $(ICON_FLAGS) `find -name '*.c'`

dbus-common-install:
	install -d $(DESTDIR)/etc/dbus-1/system.d
	install -d $(DESTDIR)/$(INSTALL_DIR)/dbus-1/system-services
	install -d $(DESTDIR)/$(LIBEXEC_DIR)
	install -d $(DESTDIR)/etc/bash_completion.d

dbus-rhsmd-service-install: dbus-common-install
	install -m 644 etc-conf/dbus/system.d/com.redhat.SubscriptionManager.conf $(DESTDIR)/etc/dbus-1/system.d

dbus-facts-service-install: dbus-common-install
	install -m 644 etc-conf/dbus/system.d/com.redhat.RHSM1.Facts.conf $(DESTDIR)/etc/dbus-1/system.d

dbus-main-service-install: dbus-common-install
	install -m 644 etc-conf/dbus/system.d/com.redhat.RHSM1.conf $(DESTDIR)/etc/dbus-1/system.d

.PHONY: dbus-install
dbus-install: dbus-facts-service-install dbus-rhsmd-service-install dbus-main-service-install

.PHONY: install-conf
install-conf:
	install -d $(DESTDIR)/etc/{cron.daily,logrotate.d,pam.d,bash_completion.d,rhsm}
	install -d $(DESTDIR)/etc/rc.d/init.d
	install -d $(DESTDIR)/etc/init.d
	install -d $(DESTDIR)/etc/rhsm/facts
	install -d $(DESTDIR)/etc/security/console.apps
	install -m 644 etc-conf/rhsm.conf $(DESTDIR)/etc/rhsm/
	install -T etc-conf/logging.conf $(DESTDIR)/etc/rhsm/logging.conf
	install -m 644 etc-conf/logrotate.conf $(DESTDIR)/etc/logrotate.d/subscription-manager
	install -m 644 etc-conf/subscription-manager.completion.sh $(DESTDIR)/etc/bash_completion.d/subscription-manager
	install -m 644 etc-conf/rct.completion.sh $(DESTDIR)/etc/bash_completion.d/rct
	install -m 644 etc-conf/rhsm-debug.completion.sh $(DESTDIR)/etc/bash_completion.d/rhsm-debug
	install -m 644 etc-conf/rhn-migrate-classic-to-rhsm.completion.sh $(DESTDIR)/etc/bash_completion.d/rhn-migrate-classic-to-rhsm
	install -m 644 etc-conf/subscription-manager-gui.completion.sh $(DESTDIR)/etc/bash_completion.d/subscription-manager-gui
	install -m 644 etc-conf/rhsm-icon.completion.sh $(DESTDIR)/etc/bash_completion.d/rhsm-icon
	install -m 644 etc-conf/rhsmcertd.completion.sh $(DESTDIR)/etc/bash_completion.d/rhsmcertd
	install -d $(DESTDIR)/$(PREFIX)/share/appdata
	install -m 644 etc-conf/subscription-manager-gui.appdata.xml $(DESTDIR)/$(INSTALL_DIR)/appdata/subscription-manager-gui.appdata.xml
	install -d $(DESTDIR)/$(POLKIT_ACTIONS_INST_DIR)
	install -m 644 etc-conf/dbus/polkit/com.redhat.RHSM1.policy $(DESTDIR)/$(POLKIT_ACTIONS_INST_DIR)
	install -m 644 etc-conf/dbus/polkit/com.redhat.RHSM1.Facts.policy $(DESTDIR)/$(POLKIT_ACTIONS_INST_DIR)
	install -m 644 etc-conf/dbus/polkit/com.redhat.SubscriptionManager.policy $(DESTDIR)/$(POLKIT_ACTIONS_INST_DIR)

.PHONY: install-plugins
install-plugins:
	install -d $(DESTDIR)/$(RHSM_PLUGIN_DIR)
	install -d $(DESTDIR)/$(RHSM_PLUGIN_CONF_DIR)
	install -d $(DESTDIR)/etc/rhsm/ca
	install -m 644 -p etc-conf/redhat-entitlement-authority.pem $(DESTDIR)/etc/rhsm/ca/redhat-entitlement-authority.pem

	if [ "$(INSTALL_YUM_PLUGINS)" = "true" ] ; then \
		echo "Installing Yum plugins" ; \
		install -d $(DESTDIR)/etc/yum/pluginconf.d/ ; \
		install -d $(DESTDIR)/$(PREFIX)/lib/yum-plugins/ ; \
		install -m 644 -p src/plugins/*.py $(DESTDIR)/$(PREFIX)/lib/yum-plugins/ ; \
		install -m 644 etc-conf/plugin/*.conf $(DESTDIR)/etc/yum/pluginconf.d/ ; \
	fi;

	if [ "$(INSTALL_ZYPPER_PLUGINS)" = "true" ] ; then \
	  echo "Installing zypper plugins" ; \
		install -d $(DESTDIR)/etc/rhsm/zypper.repos.d ; \
		install -d $(DESTDIR)/$(PREFIX)/lib/zypp/plugins/services ; \
		install -d $(DESTDIR)/$(PREFIX)/lib/zypp/plugins/commit ; \
		install -m 755 -p src/zypper/services/* $(DESTDIR)/$(PREFIX)/lib/zypp/plugins/services ; \
		install -m 755 -p src/zypper/commit/* $(DESTDIR)/$(PREFIX)/lib/zypp/plugins/commit ; \
	fi;

	if [ "$(INSTALL_DNF_PLUGINS)" = "true" ] ; then \
		echo "Installing DNF plugins" ; \
		install -d $(DESTDIR)/$(PYTHON_SITELIB)/dnf-plugins/ ; \
		install -m 644 -p src/dnf-plugins/*.py $(DESTDIR)/$(PYTHON_SITELIB)/dnf-plugins/ ; \
	fi;

	# ostree stuff
	if [ "$(INSTALL_OSTREE_PLUGIN)" = "true" ] ; then \
		echo "Installing ostree plugins" ; \
		install -m 644 -p \
		$(CONTENT_PLUGINS_SRC_DIR)/ostree_content.OstreeContentPlugin.conf \
		$(DESTDIR)/$(RHSM_PLUGIN_CONF_DIR) ; \
		install -d $(DESTDIR)/$(PYTHON_INST_DIR)/plugin/ostree ; \
		install -m 644 -p $(SRC_DIR)/plugin/ostree/*.py $(DESTDIR)/$(PYTHON_INST_DIR)/plugin/ostree ; \
	fi;

	# container stuff
	install -m 644 -p \
		$(CONTENT_PLUGINS_SRC_DIR)/container_content.ContainerContentPlugin.conf \
		$(DESTDIR)/$(RHSM_PLUGIN_CONF_DIR)
	install -m 644 $(CONTENT_PLUGINS_SRC_DIR)/container_content.py $(DESTDIR)/$(RHSM_PLUGIN_DIR)

.PHONY: install-ga
ifeq ($(GTK_VERSION),2)
install-ga:
	$(info Using GTK $(GTK_VERSION))
	install -d $(DESTDIR)/$(PYTHON_INST_DIR)/ga_impls/ga_gtk2
	install -m 644 -p $(SRC_DIR)/ga_impls/__init__.py* $(DESTDIR)/$(PYTHON_INST_DIR)/ga_impls
	install -m 644 -p $(SRC_DIR)/ga_impls/ga_gtk2/*.py $(DESTDIR)/$(PYTHON_INST_DIR)/ga_impls/ga_gtk2
else
install-ga:
	$(info Using GTK $(GTK_VERSION))
	install -d $(DESTDIR)/$(PYTHON_INST_DIR)/ga_impls
	install -m 644 -p $(SRC_DIR)/ga_impls/__init__.py* $(DESTDIR)/$(PYTHON_INST_DIR)/ga_impls
	install -m 644 -p $(SRC_DIR)/ga_impls/ga_gtk3.py* $(DESTDIR)/$(PYTHON_INST_DIR)/ga_impls
endif

.PHONY: install-example-plugins
install-example-plugins: install-plugins
	install -m 644 -p example-plugins/*.py $(DESTDIR)/$(RHSM_PLUGIN_DIR)
	install -m 644 -p example-plugins/*.conf $(DESTDIR)/$(RHSM_PLUGIN_CONF_DIR)

.PHONY: install-firstboot
ifeq ($(INSTALL_FIRSTBOOT),true)
install-firstboot:
	$(info Installing firstboot to $(FIRSTBOOT_MODULES_DIR))
	install -d $(DESTDIR)/$(FIRSTBOOT_MODULES_DIR)
	install -m 644 $(SRC_DIR)/gui/firstboot/*.py* $(DESTDIR)/$(FIRSTBOOT_MODULES_DIR)
else
install-firstboot:
	# Override INSTALL_FIRSTBOOT variable on command line if needed
	$(info firstboot is not configured to be install)
endif

# initial-setup, as in the 'initial-setup' rpm that runs at first boot.
.PHONY: install-initial-setup
ifeq ($(INSTALL_INITIAL_SETUP),true)
install-initial-setup:
	$(info Installing initial-setup to $(INITIAL_SETUP_INST_DIR))
	install -m 644 $(CONTENT_PLUGINS_SRC_DIR)/ostree_content.py $(DESTDIR)/$(RHSM_PLUGIN_DIR)
	install -d $(DESTDIR)/$(ANACONDA_ADDON_INST_DIR)
	install -d $(DESTDIR)/$(INITIAL_SETUP_INST_DIR)/gui/spokes
	install -d $(DESTDIR)/$(INITIAL_SETUP_INST_DIR)/{categories,ks}
	install -m 644 -p $(ANACONDA_ADDON_MODULE_SRC_DIR)/*.py $(DESTDIR)/$(INITIAL_SETUP_INST_DIR)/
	install -m 644 -p $(ANACONDA_ADDON_MODULE_SRC_DIR)/gui/*.py $(DESTDIR)/$(INITIAL_SETUP_INST_DIR)/gui/
	install -m 644 -p $(ANACONDA_ADDON_MODULE_SRC_DIR)/categories/*.py $(DESTDIR)/$(INITIAL_SETUP_INST_DIR)/categories/
	install -m 644 -p $(ANACONDA_ADDON_MODULE_SRC_DIR)/gui/spokes/{*.py,*.ui} $(DESTDIR)/$(INITIAL_SETUP_INST_DIR)/gui/spokes/
	install -m 644 -p $(ANACONDA_ADDON_MODULE_SRC_DIR)/ks/*.py $(DESTDIR)/$(INITIAL_SETUP_INST_DIR)/ks/
else
install-initial-setup:
	# Set INSTALL_INITIAL_SETUP variable on command line if needed.
	$(info initial-setup is not configured to be installed)
endif

.PHONY: install-post-boot
install-post-boot: install-firstboot install-initial-setup

.PHONY: install-via-setup
install-via-setup:
	$(PYTHON) ./setup.py install --root $(DESTDIR) --gtk-version=$(GTK_VERSION) --rpm-version=$(VERSION) --with-systemd=$(WITH_SYSTEMD) --prefix=$(PREFIX)
	mkdir -p $(DESTDIR)/$(PREFIX)/sbin/
	mkdir -p $(DESTDIR)/$(LIBEXEC_DIR)/
	mv $(DESTDIR)/$(PREFIX)/bin/subscription-manager $(DESTDIR)/$(PREFIX)/sbin/
	mv $(DESTDIR)/$(PREFIX)/bin/subscription-manager-gui $(DESTDIR)/$(PREFIX)/sbin/
	mv $(DESTDIR)/$(PREFIX)/bin/rhn-migrate-classic-to-rhsm $(DESTDIR)/$(PREFIX)/sbin/
	mv $(DESTDIR)/$(PREFIX)/bin/rhsmcertd-worker $(DESTDIR)/$(LIBEXEC_DIR)/
	mv $(DESTDIR)/$(PREFIX)/bin/rhsm-service $(DESTDIR)/$(LIBEXEC_DIR)/
	mv $(DESTDIR)/$(PREFIX)/bin/rhsm-facts-service $(DESTDIR)/$(LIBEXEC_DIR)/
	mv $(DESTDIR)/$(PREFIX)/bin/rhsmd $(DESTDIR)/$(LIBEXEC_DIR)/

.PHONY: install
install: install-via-setup install-files

.PHONY: install-files
install-files: dbus-install install-conf install-plugins install-post-boot install-ga
	install -d $(DESTDIR)/var/log/rhsm
	install -d $(DESTDIR)/var/spool/rhsm/debug
	install -d $(DESTDIR)/var/run/rhsm
	install -d -m 750 $(DESTDIR)/var/lib/rhsm/{cache,facts,packages,repo_server_val}

	# Set up rhsmcertd daemon. If installing on Fedora or RHEL 7+
	# we prefer systemd over sysv as this is the new trend.
	if [ $(OS) = Fedora ] ; then \
		install -d $(DESTDIR)/$(PREFIX)/lib/tmpfiles.d; \
		install etc-conf/rhsmcertd.service $(DESTDIR)/$(SYSTEMD_INST_DIR); \
		install etc-conf/subscription-manager.conf.tmpfiles \
			$(DESTDIR)/$(PREFIX)/lib/tmpfiles.d/subscription-manager.conf; \
	elif [[ $(OS) == *"SUSE" ]]; then \
		if [ $(OS_VERSION) -lt 1315 ]; then \
			install etc-conf/rhsmcertd.init.d \
				$(DESTDIR)/etc/init.d/rhsmcertd; \
		else \
			install -d $(DESTDIR)/$(SYSTEMD_INST_DIR); \
			install -d $(DESTDIR)/$(PREFIX)/lib/tmpfiles.d; \
			install etc-conf/rhsmcertd.service $(DESTDIR)/$(SYSTEMD_INST_DIR); \
			install etc-conf/subscription-manager.conf.tmpfiles \
			$(DESTDIR)/$(PREFIX)/lib/tmpfiles.d/subscription-manager.conf; \
		fi; \
	else \
		if [ $(OS_VERSION) -lt 7 ]; then \
			install etc-conf/rhsmcertd.init.d \
				$(DESTDIR)/etc/rc.d/init.d/rhsmcertd; \
		else \
			install -d $(DESTDIR)/$(PREFIX)/lib/tmpfiles.d; \
			install etc-conf/rhsmcertd.service $(DESTDIR)/$(SYSTEMD_INST_DIR); \
			install etc-conf/subscription-manager.conf.tmpfiles \
				$(DESTDIR)/$(PREFIX)/lib/tmpfiles.d/subscription-manager.conf; \
		fi; \
	fi; \

	install -m 700 etc-conf/rhsmd.cron $(DESTDIR)/etc/cron.daily/rhsmd

	# SUSE Linux does not make use of consolehelper
	if [[ ! $(OS) == *"SUSE" ]]; then \
		ln -sf /usr/bin/consolehelper $(DESTDIR)/$(PREFIX)/bin/subscription-manager-gui; \
		ln -sf /usr/bin/consolehelper $(DESTDIR)/$(PREFIX)/bin/subscription-manager; \
		\
		install -m 644 etc-conf/subscription-manager-gui.pam $(DESTDIR)/etc/pam.d/subscription-manager-gui; \
		install -m 644 etc-conf/subscription-manager.pam $(DESTDIR)/etc/pam.d/subscription-manager; \
		\
		install -m 644 etc-conf/subscription-manager-gui.console $(DESTDIR)/etc/security/console.apps/subscription-manager-gui; \
		install -m 644 etc-conf/subscription-manager.console $(DESTDIR)/etc/security/console.apps/subscription-manager; \
	fi; \

	install -m 755 bin/rhsm-icon $(DESTDIR)/$(PREFIX)/bin/rhsm-icon
	install -m 755 bin/rhsmcertd $(DESTDIR)/$(PREFIX)/bin/rhsmcertd

.PHONY: check
check:
	$(PYTHON) setup.py -q nosetests -c playpen/noserc.dev

.PHONY: version_check
version_check:
# needs https://github.com/alikins/pyqver
	-@TMPFILE=`mktemp` || exit 1; \
	pyqver2.py -v -m 2.5  $(STYLEFILES) | tee $$TMPFILE; \
	! test -s $$TMPFILE

.PHONY: coverage
coverage:
ifdef ghprbPullId
	# Pull the PR id from the Jenkins environment and use it as a seed so that each PR
	# uses a consistant test ordering.
	$(PYTHON) ./setup.py -q nosetests --randomly-seed=$(ghprbPullId) -c playpen/noserc.ci
else
	$(PYTHON) ./setup.py -q nosetests -c playpen/noserc.ci
endif

.PHONY: docs
docs:
	$(PYTHON) setup.py build_sphinx

.PHONY: gettext
gettext:
	# Extract strings from our source files. any comments on the line above
	# the string marked for translation beginning with "translators" will be
	# included in the pot file.
	$(PYTHON) ./setup.py gettext

.PHONY: update-po
update-po:
	$(PYTHON) ./setup.py update_trans

.PHONY: uniq-po
uniq-po:
	$(PYTHON) ./setup.py uniq_trans

# just run a check to make sure these compile
.PHONY: polint
polint:
	$(PYTHON) ./setup.py gettext --lint

.PHONY: just-strings
just-strings:
	-@ scripts/just_strings.py po/keys.pot

.PHONY: zanata-pull
zanata-pull:
	pushd po && zanata pull --transdir . && popd

.PHONY: zanata-push
zanata-push:
	pushd po; \
	ls -al; \
	if [ -z $(shell find -name "*.pot" | grep -v keys.pot) ] ; then \
		zanata push ; \
	else 	\
		echo "po/ has more than one *.pot file, please clean up" ; \
	fi; \
	popd

# do all the zanata bits
.PHONY: zanata
zanata: gettext zanata-push zanata-pull update-po
	echo "# pofiles should be ready to commit and push"

# generate a en_US.po with long strings for testing
gen-test-long-po:
	-@ scripts/gen_test_en_po.py --long po/en_US.po

.PHONY: lint
lint:
	$(PYTHON) ./setup.py lint

.PHONY: flake8
flake8:
	$(PYTHON) ./setup.py flake8

.PHONY: rpmlint
rpmlint:
	$(PYTHON) ./setup.py lint_rpm

.PHONY: stylish
stylish: lint

.PHONY: install-pip-requirements
install-pip-requirements:
	@pip install -I -r test-requirements.txt

.PHONY: jenkins
jenkins: install-pip-requirements build stylish coverage

.PHONY: set-versions
# Empty task retained for legacy compatibility with CI environment
set-versions: ;
