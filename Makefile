all:
	ocamlbuild -use-ocamlfind -package graphics game.native
	mv game.native fling
clean:
	ocamlbuild -clean
