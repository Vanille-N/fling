all:
	./.chctrls check || echo "Could not set controls"
	ocamlbuild -use-ocamlfind -package graphics game.native
	mv game.native fling

clean:
	ocamlbuild -clean

reset:
	ocamlbuild -clean
	rm .ctrlset &>/dev/null
