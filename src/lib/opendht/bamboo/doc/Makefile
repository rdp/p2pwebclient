#
# Copyright (c) 2001-2003 Regents of the University of California.
# All rights reserved.
#
# See the file LICENSE included in this distribution for details.
#

HTML = \
	index.html \
	docs.html \
	license.html \
	download.html \
	faq.html \
	pubs.html \
	contact.html \
	contrib.html \
	users-guide.html \
	programmers-guide.html \
	tutorial.html \
	news.html \
	search.html

DST = /home/srhea/public_html/bamboo

all: subdirs $(HTML)

subdirs:
	$(MAKE) -C md-tutorial
	$(MAKE) -C async-tutorial

clean:
	rm -f *.html
	$(MAKE) -C javadoc clean

install:
	rsync -e ssh -avl \
	    $(HTML) \
	    bamboo-logo.png \
	    bamboo-vis.png \
	    dht.cfg gateway.cfg second.cfg vis.cfg \
	    srhea@srhea.net:public_html/bamboo/
	rsync -e ssh -avl \
	    md-tutorial/md-tutorial.pdf \
	    md-tutorial/*.java \
	    srhea@srhea.net:public_html/bamboo/md-tutorial/
	rsync -e ssh -avl \
	    async-tutorial/async-tutorial.pdf \
	    async-tutorial/*.java \
	    srhea@srhea.net:public_html/bamboo/async-tutorial/


index.html: introduction.content genpage.pl
	./genpage.pl Introduction $< > $@

news.html: news.content genpage.pl
	./genpage.pl "News" $< > $@

download.html: download.content genpage.pl
	./genpage.pl "Download" $< > $@

tutorial.html: tutorial.content genpage.pl
	./genpage.pl "Tutorial" $< > $@

license.html: license.content genpage.pl
	./genpage.pl "License" $< > $@

docs.html: docs.content genpage.pl
	./genpage.pl "Documentation" $< > $@

search.html: search.content genpage.pl
	./genpage.pl "Search" $< > $@

faq.html: faq.content genpage.pl
	./genpage.pl "Frequently Asked Questions" $< > $@

pubs.html: pubs.content genpage.pl
	./genpage.pl "Publications" $< > $@

contact.html: contact.content genpage.pl
	./genpage.pl "Contact Us" $< > $@

contrib.html: contrib.content genpage.pl
	./genpage.pl "Contributors" $< > $@

users-guide.html: users-guide.content genpage.pl
	./genpage.pl "User's Guide" $< > $@

programmers-guide.html: programmers-guide.content genpage.pl
	./genpage.pl "Programmer's Guide" $< > $@
