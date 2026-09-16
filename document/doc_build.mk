# SPDX-FileCopyrightText: 2026 IObundle
#
# SPDX-License-Identifier: GPL-3.0-only

# This makefile segment is used at build-time in $(BUILD_DIR)/doc/Makefile

#Set ASICSYNTH to 1 to include an ASIC synthesis section
ASICSYNTH?=0

#include implementation results; requires EDA tools
#default is 0 as EDA tools may not be accessible
RESULTS ?= 1
#results for intel FPGA
INT_FAMILY ?=iob_cyclonev_gt_dk
#results for xilinx fpga
XIL_FAMILY ?=iob_aes_ku040_db_g

#build specification document signature
sd_signature.tex:
	@echo `tail -n 1 name.tex`-USG-`tail -n 1 $(NAME)_version.tex`-`tail -n 1 shortHash.tex` > $@

#build specification document type
sd.pdf: debug results figs sdtop.tex
	pdflatex -jobname sd sdtop.tex
	if [ -f *.bib ]; then bibtex sd; fi
	pdflatex -jobname sd sdtop.tex
	pdflatex -jobname sd sdtop.tex

#sd top file containing the definition of sections to include
sdtop.tex:
	make doctop DOC=sd

