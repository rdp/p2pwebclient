#
# Copyright (c) 2001-2003 Regents of the University of California.
# All rights reserved.
#
# See the file LICENSE included in this distribution for details.
#

BAMBOO_HOME=../..
CLASSPATH:=$(CLASSPATH):$(BAMBOO_HOME)/lib/diva-26Sep02.jar
include $(BAMBOO_HOME)/src/bamboo/Makefile.include

PACKAGES:=$(shell find $(BAMBOO_HOME)/src/bamboo/* -type d -and -not -name CVS)
PACKAGES:=$(subst $(BAMBOO_HOME)/src/,,$(PACKAGES))
PACKAGES:=$(subst /,.,$(PACKAGES))

# The bamboo.patchwork directory shouldn't be around anymore.
PACKAGES:=$(subst bamboo.patchwork,,$(PACKAGES))

ifndef SEDAHOME
SEDAHOME=$(wildcard $(HOME)/seda/src)
endif
ifneq ($(SEDAHOME),)
CLASSPATH:=$(CLASSPATH):$(SEDAHOME)
else
# The bamboo.network directory needs seda.sandStorm.lib.aSocket to build, but
# it's not included in ../lib/ostore-seda-emu.jar.
PACKAGES:=$(subst bamboo.network,,$(PACKAGES))
endif

SEDA_URL:=-link http://www.eecs.harvard.edu/~mdw/proj/seda/javadoc

ifndef OSTORE_URL
OSTORE_URL=$(wildcard $(HOME)/oceanstore/pond/ostore/doc/package-list)
endif
ifneq ($(OSTORE_URL),)
OSTORE_URL:=$(subst /package-list,,$(OSTORE_URL))
OSTORE_URL:=-link file:$(OSTORE_URL)
endif

JAVA14_DOCS_URL:=-link http://java.sun.com/j2se/1.4.1/docs/api

JAVADOC:=$(JAVAHOME)/bin/javadoc

docs:
	CLASSPATH="$(CLASSPATH)" $(JAVADOC) -source 1.4 \
	$(JAVA14_DOCS_URL) \
	$(SEDA_URL) \
	$(OSTORE_URL) \
	-windowtitle "Bamboo Javadocs" -author -version \
	$(PACKAGES)

clean:
	cat .cvsignore | xargs rm -rf

