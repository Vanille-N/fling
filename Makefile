all:
	./.chctrls check || echo "Could not set controls"
	ocamlbuild -use-ocamlfind -package graphics,unix game.native
	mv game.native fling

clean:
	ocamlbuild -clean
	rm .ctrlset &>/dev/null
	rm *.tar.gz &>/dev/null

tar:
	tar czf NEVEN_VILLANI-Fling.tar.gz --transform 's,^,NEVEN_VILLANI-Fling/,' \
		Makefile *.ml *.mli *.md .chctrls .data fling.odocl

doc:
	ocamlbuild fling.docdir/index.html
	xdg-open fling.docdir/index.html &

run:
	make
	./fling
