#
# Makefile
#   Linux Health Checker top-level Makefile
#
# Copyright IBM Corp. 2012
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
# Contributors: See file CONTRIBUTORS which is part of this package
#
# Targets:
#   all:        Build components
#   install:    Install files
#   uninstall:  Remove installed files
#   rpms:       Create source and noarch RPM file
#   tar:	Create tar archive with lnxhc sources
#
# Variables:
#   DESTDIR:    Specify alternate install root
#   VERSION:    Specify tool version (e.g. "1.0")
#   RELEASE:    Specify tool release (e.g. "1")
#

# Variables
VERSION		:= $(shell $(CURDIR)/genvcl.sh -v)
RELEASE		:= $(shell $(CURDIR)/genvcl.sh -r)

# Helpers
SHELL		:= /bin/bash
MKTEMP		:= /bin/mktemp
ECHO		:= /bin/echo
CP		:= /bin/cp
MV		:= /bin/mv
RM		:= /bin/rm
RMDIR		:= /bin/rmdir
MKDIR		:= /bin/mkdir
TAR		:= /bin/tar
INSTALL		:= /usr/bin/install
MAKE		:= /usr/bin/make
RPMBUILD	:= /usr/bin/rpmbuild
FIXPATH		:= $(CURDIR)/fixpaths.sh
FIXVERS		:= $(CURDIR)/fixvers.sh
GENVCL		:= $(CURDIR)/genvcl.sh

# Directories
prefix		:= /usr
exec_prefix	:= $(prefix)
datarootdir	:= $(prefix)/share

confdir		:= /etc
bindir		:= $(exec_prefix)/bin
libdir		:= $(exec_prefix)/lib/lnxhc
DOCDIR		:= $(datarootdir)/doc/lnxhc-$(VERSION)
docdir		:= $(DOCDIR)
mandir		:= $(datarootdir)/man
man1dir		:= $(mandir)/man1
man5dir		:= $(mandir)/man5
man7dir		:= $(mandir)/man7

sysvardir	:= $(libdir)/sysvar
pmdir		:= $(libdir)/LNXHC
pmcheckdir	:= $(libdir)/LNXHC/Check
pmconsumerdir	:= $(libdir)/LNXHC/Consumer
checkdir	:= $(libdir)/checks
consdir		:= $(libdir)/consumers
profiledir	:= $(libdir)/profiles
pydir		:= $(libdir)/python
pycheckdir	:= $(libdir)/python/check
exampledir	:= $(docdir)/examples
dbdir1		:= $(libdir)
dbdir2		:= /usr/local/lib/lnxhc

# Base files
binfiles	:= $(wildcard bin/*)
man1files	:= $(wildcard man/*.1)
man5files	:= $(wildcard man/*.5)
man7files	:= $(wildcard man/*.7)
conffiles	:= lnxhcrc
tmplfiles	:= $(wildcard lib/template_*)
dtdfiles	:= $(wildcard lib/*.dtd)
sysvarfiles	:= $(wildcard lib/sysvar/*)
pmfiles		:= $(wildcard lib/LNXHC/*.pm)
pmcheckfiles	:= $(wildcard lib/LNXHC/Check/*.pm)
pmconsumerfiles := $(wildcard lib/LNXHC/Consumer/*.pm)
pycheckfiles	:= $(wildcard lib/python/check/*)
examples	:= $(wildcard examples/*)
docfiles	:= CHANGES CONTRIBUTING CONTRIBUTORS README epl-v10.html

# Files and directories that are installed using lnxhc
checkdirs	:= $(wildcard checks/*)
consdirs	:= $(wildcard consumers/*)
profilefiles	:= $(wildcard profiles/*)

# List of --install <dir> arguments for all check directories
checkinstallarg	:= $(checkdirs:%=--install %)
# List of --install <dir> arguments for all consumer directories
consinstallarg	:= $(consdirs:%=--install %)
# List of --import <file> arguments for all profile files
profileinstallarg := $(profilefiles:%=--import %)

# List of check directories containing a Makefile
checkbuilddirs	:= $(patsubst %/Makefile,%,$(wildcard checks/*/Makefile))
# List of consumer directories containing a Makefile
consbuilddirs	:= $(patsubst %/Makefile,%,$(wildcard consumers/*/Makefile))

# File permissions
dirmode		:= 0755
binmode		:= 0755
noexecmode	:= 0644


# Macros

# $1=list of source paths, $2=target directory, output=commands to remove
# all target paths
uninstall	= test -z "$(1)" || $(RM) -rf $(addprefix $(2)/,$(notdir $(1)))


# Rules
all: build

build: buildchecks buildconsumers

buildcheckstats:
	if [ -z "$(checkbuilddirs)" ] ; then \
		$(ECHO) "No check requires compilation" ; \
	fi

buildchecks: buildcheckstats $(checkbuilddirs)

buildconsstats:
	if [ -z "$(consbuilddirs)" ] ; then \
		$(ECHO) "No consumer requires compilation" ; \
	fi

buildconsumers: buildconsstats $(consbuilddirs)

$(checkbuilddirs) $(consbuilddirs):
	$(ECHO) "  MAKE  $@"
	$(MAKE) --quiet --directory $@

install: installdirs installbase installchecks installconsumers installprofiles

uninstall: uninstallprofiles uninstallconsumers uninstallchecks uninstallbase \
	   uninstalldirs

installdirs:
	$(INSTALL) -d -m $(dirmode) $(DESTDIR)$(confdir) $(DESTDIR)$(bindir) \
			$(DESTDIR)$(libdir) $(DESTDIR)$(man1dir) \
			$(DESTDIR)$(man5dir) $(DESTDIR)$(man7dir) \
			$(DESTDIR)$(sysvardir) $(DESTDIR)$(pmdir) \
			$(DESTDIR)$(checkdir) $(DESTDIR)$(consdir) \
			$(DESTDIR)$(profiledir) $(DESTDIR)$(dbdir1) \
			$(DESTDIR)$(dbdir2) $(DESTDIR)$(pmcheckdir)  \
			$(DESTDIR)$(pmconsumerdir) $(DESTDIR)$(pydir) \
			$(DESTDIR)$(pycheckdir) $(DESTDIR)$(exampledir)

uninstalldirs:
	$(RMDIR) $(DESTDIR)$(sysvardir) $(DESTDIR)$(pmcheckdir) \
		 $(DESTDIR)$(pmconsumerdir) $(DESTDIR)$(pmdir) \
		 $(DESTDIR)$(checkdir) $(DESTDIR)$(consdir) \
		 $(DESTDIR)$(profiledir) $(DESTDIR)$(pycheckdir) \
		 $(DESTDIR)$(pydir) $(DESTDIR)$(libdir) \
		 $(DESTDIR)$(dbdir2) $(DESTDIR)$(exampledir) \
		 $(DESTDIR)$(docdir)

installbase: installdirs
	$(INSTALL) -m $(binmode) $(binfiles) $(DESTDIR)$(bindir)
	$(INSTALL) -m $(noexecmode) $(man1files) $(DESTDIR)$(man1dir)
	$(INSTALL) -m $(noexecmode) $(man5files) $(DESTDIR)$(man5dir)
	$(INSTALL) -m $(noexecmode) $(man7files) $(DESTDIR)$(man7dir)
	$(INSTALL) -m $(noexecmode) $(conffiles) $(DESTDIR)$(confdir)
	$(INSTALL) -m $(noexecmode) $(tmplfiles) $(DESTDIR)$(libdir)
	$(INSTALL) -m $(noexecmode) $(dtdfiles) $(DESTDIR)$(libdir)
	$(INSTALL) -m $(binmode) $(sysvarfiles) $(DESTDIR)$(sysvardir)
	$(INSTALL) -m $(noexecmode) $(pmfiles) $(DESTDIR)$(pmdir)
	$(INSTALL) -m $(noexecmode) $(pmcheckfiles) $(DESTDIR)$(pmcheckdir)
	$(INSTALL) -m $(noexecmode) $(pmconsumerfiles) $(DESTDIR)$(pmconsumerdir)
	$(INSTALL) -m $(noexecmode) $(pycheckfiles) $(DESTDIR)$(pycheckdir)
	$(INSTALL) -m $(noexecmode) $(docfiles) $(DESTDIR)$(docdir)
	$(CP) -rp $(examples) $(DESTDIR)$(exampledir)
	for FILE in $(notdir $(binfiles)) ; do \
		$(FIXPATH) "$(DESTDIR)/$(bindir)/$${FILE}" "$(libdir)" \
			   "$(dbdir1)" "$(dbdir2)" ; \
	done
	for FILE in $(notdir $(conffiles)) ; do \
		$(FIXPATH) "$(DESTDIR)/$(confdir)/$${FILE}" "$(libdir)" \
			   "$(dbdir1)" "$(dbdir2)" ; \
	done

uninstallbase:
	$(call uninstall,$(binfiles),$(DESTDIR)$(bindir))
	$(call uninstall,$(man1files),$(DESTDIR)$(man1dir))
	$(call uninstall,$(man5files),$(DESTDIR)$(man5dir))
	$(call uninstall,$(man7files),$(DESTDIR)$(man7dir))
	$(call uninstall,$(conffiles),$(DESTDIR)$(confdir))
	$(call uninstall,$(tmplfiles),$(DESTDIR)$(libdir))
	$(call uninstall,$(dtdfiles),$(DESTDIR)$(libdir))
	$(call uninstall,$(sysvarfiles),$(DESTDIR)$(sysvardir))
	$(call uninstall,$(pmcheckfiles),$(DESTDIR)$(pmcheckdir))
	$(call uninstall,$(pmconsumerfiles),$(DESTDIR)$(pmconsumerdir))
	$(call uninstall,$(pmfiles),$(DESTDIR)$(pmdir))
	$(call uninstall,$(pycheckfiles),$(DESTDIR)$(pycheckdir))
	$(call uninstall,$(examples),$(DESTDIR)$(exampledir))
	$(call uninstall,$(docfiles),$(DESTDIR)$(docdir))

installchecks: installbase
	if [ -z "$(checkdirs)" ] ; then \
		echo "No checks to install" ; \
	else \
	set -e ; \
	USERDIR=$$($(MKTEMP) -d) ; \
	$(ECHO) "db_path=\"$(DESTDIR)$(libdir)\"" > $${USERDIR}/lnxhcrc ; \
	$(ECHO) "db_caching=0" >> $${USERDIR}/lnxhcrc ; \
	LNXHC_LIBDIR="$(DESTDIR)$(libdir)" $(DESTDIR)$(bindir)/lnxhc check \
		--user-dir $${USERDIR} --system $(checkinstallarg) ; \
	$(RM) -f $${USERDIR}/lnxhcrc ; \
	$(RMDIR) $${USERDIR} ; \
	fi

uninstallchecks:
	$(call uninstall,$(checkdirs),$(DESTDIR)$(libdir)/checks)

installconsumers: installbase
	if [ -z "$(consdirs)" ] ; then \
		echo "No consumers to install" ; \
	else \
	set -e ; \
	USERDIR=$$($(MKTEMP) -d) ; \
	$(ECHO) "db_path=\"$(DESTDIR)$(libdir)\"" > $${USERDIR}/lnxhcrc ; \
	$(ECHO) "db_caching=0" >> $${USERDIR}/lnxhcrc ; \
	LNXHC_LIBDIR="$(DESTDIR)$(libdir)" $(DESTDIR)$(bindir)/lnxhc consumer \
		--user-dir $${USERDIR} --system $(consinstallarg) ; \
	$(RM) -f $${USERDIR}/lnxhcrc ; \
	$(RMDIR) $${USERDIR} ; \
	fi

uninstallconsumers:
	$(call uninstall,$(consdirs),$(DESTDIR)$(libdir)/consumers)

installprofiles: installbase
	if [ -z "$(profilefiles)" ] ; then \
		echo "No profiles to install" ; \
	else \
	set -e ; \
	USERDIR=$$($(MKTEMP) -d) ; \
	$(ECHO) "db_path=\"$(DESTDIR)$(libdir)\"" > $${USERDIR}/lnxhcrc ; \
	$(ECHO) "db_caching=0" >> $${USERDIR}/lnxhcrc ; \
	LNXHC_LIBDIR="$(DESTDIR)$(libdir)" $(DESTDIR)$(bindir)/lnxhc profile \
		--user-dir $${USERDIR} --system $(profileinstallarg) ; \
	$(RM) -f $${USERDIR}/lnxhcrc ; \
	$(RMDIR) $${USERDIR} ; \
	fi

uninstallprofiles:
	$(call uninstall,$(profilefiles),$(DESTDIR)$(libdir)/profiles)

lnxhc-$(VERSION).tar.gz:
	set -e ; \
	LNXHCDIR=$$($(MKTEMP) -d) ; \
	$(CP) -daP "$(CURDIR)" "$${LNXHCDIR}/lnxhc-$(VERSION)" ; \
	$(FIXVERS) "$(VERSION)" "$(RELEASE)" "$${LNXHCDIR}/lnxhc-$(VERSION)" ; \
	if test -d .git; then \
		$(GENVCL) -s -d $${LNXHCDIR}/lnxhc-$(VERSION) ; \
		$(GENVCL) -c -d $${LNXHCDIR}/lnxhc-$(VERSION) ; \
		$(GENVCL) -p -d $${LNXHCDIR}/lnxhc-$(VERSION) ; \
	fi ; \
	$(TAR) cfz "lnxhc-$(VERSION).tar.gz" -C "$${LNXHCDIR}" \
		    --exclude=".git" "lnxhc-$(VERSION)" ; \
	$(RM) -rf $${LNXHCDIR}/lnxhc-$(VERSION) ; \
	$(RMDIR) $${LNXHCDIR}

tar: clean lnxhc-$(VERSION).tar.gz

rpms: lnxhc-$(VERSION).tar.gz
	set -e ; set -x ; \
	RPMDIR=$$($(MKTEMP) -d) ; \
	$(MKDIR) "$${RPMDIR}/BUILD" "$${RPMDIR}/RPMS" "$${RPMDIR}/SOURCES" \
	      "$${RPMDIR}/SPECS" "$${RPMDIR}/SRPMS" ; \
	$(CP) "lnxhc-$(VERSION).tar.gz" "$${RPMDIR}/SOURCES" ; \
	$(TAR) xfz "$${RPMDIR}/SOURCES/lnxhc-$(VERSION).tar.gz" \
	       -C "$${RPMDIR}/SPECS" --strip-components 1 \
	       "lnxhc-$(VERSION)/lnxhc.spec" ; \
	$(RPMBUILD) --define '_topdir '"$${RPMDIR}" -ba \
		    "$${RPMDIR}/SPECS/lnxhc.spec" ; \
	$(MV) "$${RPMDIR}/RPMS/noarch/lnxhc-$(VERSION)-$(RELEASE).noarch.rpm" . ; \
	$(MV) "$${RPMDIR}/SRPMS/lnxhc-$(VERSION)-$(RELEASE).src.rpm" . ; \
	$(RM) -rf "$${RPMDIR}"

clean:
	$(RM) -f *.tar.gz *.rpm

.PHONY: all build buildchecks buildcheckstats buildconsumers buildconsstats \
	install installdirs installbase installchecks installconsumers \
	installprofiles $(checkbuilddirs) $(consbuilddirs) uninstall \
	uninstalldirs uninstallbase uninstallchecks uninstallconsumers \
	uninstallprofiles lnxhc-$(VERSION).tar.gz tar rpms clean
