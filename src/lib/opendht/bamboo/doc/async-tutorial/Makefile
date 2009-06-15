# $Id: Makefile,v 1.1 2005/02/16 07:38:04 srhea Exp $

BAMBOO_HOME=../..
include $(BAMBOO_HOME)/src/bamboo/Makefile.include

TARGET=async-tutorial
SOURCES=$(wildcard *.java)
OBJECTS=$(SOURCES:.java=.class)

all: $(OBJECTS) $(TARGET).pdf $(TARGET).ps

clean:
	rm -f $(TARGET).aux $(TARGET).dvi $(TARGET).log \
		$(TARGET).pdf $(TARGET).ps *.class

%.pdf: %.ps
	ps2pdf -dCompatibilityLevel=1.3 $< $@

%.ps: %.dvi
	dvips -Ppdf -G0 -o $@ $<

%.dvi: %.tex
	latex $<

$(TARGET).dvi: $(SOURCES)

