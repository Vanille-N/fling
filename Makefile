all:
	./.chctrls check || echo "Could not set controls"
	ocamlbuild -use-ocamlfind -package graphics,unix game.native
	mv game.native fling

clean:
	ocamlbuild -clean
	rm .ctrlset &>/dev/null
	rm *.tar.gz &>/dev/null

ARCHIVE="NVILLANI-Fling"
MAINDIR="VILLANI_NEVEN"
SUBDIR="fling"

tar:
	rm ${ARCHIVE}.tar.gz &>/dev/null || echo ""
	rm ${ARCHIVE}.tar &>/dev/null || echo ""
	tar cf ${ARCHIVE}.tar \
		--transform "s,^,${MAINDIR}/${SUBDIR}/," \
		Makefile *.ml *.mli .chctrls .data fling.odocl
	tar -uf ${ARCHIVE}.tar \
		--transform "s,^,${MAINDIR}/," \
		README.md
	gzip ${ARCHIVE}.tar

doc:
	ocamlbuild fling.docdir/index.html
	xdg-open fling.docdir/index.html &

run:
	make
	./fling
