#
# Copyright (c) 2001-2003 Regents of the University of California.
# All rights reserved.
#
# See the file LICENSE included in this distribution for details.
#

RELEASE_VER=1.0

BAMBOO_HOME = .
include src/bamboo/Makefile.include

all: sources

release: clean
	rm -f bamboo-$(RELEASE_VER).tgz
	cd .. && find bamboo/ -print | grep -v planetlab | grep -v CVS \
	| grep -v .cvsignore | grep -v .swp \
	| xargs tar czf bamboo/bamboo-$(RELEASE_VER).tgz

sources:
	$(MAKE) -C src/bamboo

clean:
	$(MAKE) -C src/bamboo clean
	$(MAKE) -C doc clean

docs:
	$(MAKE) -C src/bamboo docs

ostore-seda-emu.jar: 
	$(MAKE) -C lib ostore-seda-emu.jar
