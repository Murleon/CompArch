YAS=./tools/yas
HCL2D=./tools/hcl2d
DC=dmd
DFLAGS=-O
DOT=dot

all:
	(cd tools; make all)

.SUFFIXES: .ys .yo
.ys.yo:
	$(YAS) $*.ys

.SUFFIXES: .hcl .exe
.hcl.exe:
	$(HCL2D) $*.hcl
	$(DC) $(DFLAGS) $*_hcl.d -of$*.exe

.SUFFIXES: .dot .png
.dot.png: 
	$(DOT) -Tpng $*.dot > $*.png

clean:
	(cd tools; make clean)
	rm -f *.exe *.o *.obj *~ core.* *_hcl.d *_hcl.dot *_hcl.png
