#
# Copyright (c) 2001-2003 Regents of the University of California.
# All rights reserved.
#
# See the file LICENSE included in this distribution for details.
#

HTML = \
	index.html \
        faq.html \
        people.html \
	pubs.html \
	users-guide.html \

INSTALL = \
	f230-rhea.pdf \
        oh-test.png \
        ohchat-0.02.tar.gz \
        ohchat-0.03.tar.gz \
        opendht-logo.png \
	opendht-logo-black.png \
        openhash-iptps2004.pdf \
        powered_by_pl.gif \
	redir++-0.3.tar.gz \
	redirapp-0.0.1.tar.gz \
        turnon.png \
        ../../src/bamboo/dht/gateway_prot.x \
        ../../src/bamboo/dht/gateway_test.c \
        ../../src/bamboo/dht/put.py \
	../../src/bamboo/dht/get.py \
	../../src/bamboo/dht/rm.py \
	../../src/bamboo/dht/find-gateway.py

all: $(HTML)

install:
	cp $(HTML) $(INSTALL) /home/bkarp/public_html

clean:
	rm -f *.html

%.html: %.content genpage.pl
	./genpage.pl $< > $@

