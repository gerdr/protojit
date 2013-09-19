test: LLR/Compiler.pir
	nqp test.nqp

clean:
	rm -f LLR/*.pir

LLR/Compiler.pir: LLR/Grammar.pir LLR/Actions.pir
LLR/Grammar.pir LLR/Actions.pir: LLR/AST.pir

%.pir: %.pm
	nqp --target=pir $< > $@.tmp
	mv $@.tmp $@
