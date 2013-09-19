use LLR::Compiler;

say(LLR::Compiler.new.compile('ops.def').to('C'));
