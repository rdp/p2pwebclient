# $Id: Makefile,v 1.1 2005/02/06 17:31:55 srhea Exp $

BAMBOO_HOME=../..
include $(BAMBOO_HOME)/src/bamboo/Makefile.include

all: SimpleStage.class md-tutorial.pdf md-tutorial.ps

clean:
	rm -f md-tutorial.aux md-tutorial.dvi md-tutorial.log \
		md-tutorial.pdf md-tutorial.ps *.class

%.pdf: %.ps
	ps2pdf -dCompatibilityLevel=1.3 $< $@

%.ps: %.dvi
	dvips -Ppdf -G0 -o $@ $<

%.dvi: %.tex
	latex $<

md-tutorial.dvi: SimpleStage.java

