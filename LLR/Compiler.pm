use LLR::Grammar;
use LLR::Actions;

proto toC($node) {*}

my %targets := nqp::hash(
    'C', &toC
);

class LLR::Compiler {
    has %!units;
    has @!units;

    method compile($file, :$code) {
        nqp::die("file '$file' already compiled")
            if %!units{$file};

        %!units{$file} := LLR::Grammar.parse(
            $code // slurp($file),
            actions => LLR::Actions
        ).ast;

        nqp::push(@!units, $file);

        self
    }

    method link(&emit, %args) {
        my %*CODEGEN_ARGS := %args;
        my $unit := LLR::Unit.new;

        for @!units {
            for %!units{$_}.ops {
                $unit.push($_)
            }
        }

        emit($unit)
    }

    method to($target, *%args) {
        self.link(%targets{$target}, %args)
    }
}

my %typemap := nqp::hash(
    'int8',  'MVMint8',
    'int16', 'MVMint16',
    'int32', 'MVMint32',
    'int64', 'MVMint64',
    'num32', 'MVMnum32',
    'num64', 'MVMnum64',
    'obj',   'MVMObject*',
    'str',   'MVMString*',
    'uint8',  'MVMuint8',
    'uint16', 'MVMuint16',
    'uint32', 'MVMuint32',
    'uint64', 'MVMuint64',
    'sint8',  'MVMint8',
    'sint16', 'MVMint16',
    'sint32', 'MVMint32',
    'sint64', 'MVMint64'
);

my %regmap := nqp::hash(
    'int64', 'i64',
    'uint64', 'ui64',
    'str', 's'
);

my %sizemap := nqp::hash(
    'int32', 4,
    'int64', 8,
    'uint32', 4
);

my %getmap := nqp::hash(
    'int64', 'I64',
    'uint32', 'UI32'
);

multi toC(LLR::RegisterRValue $val) {
    $val.cast ?? "({ %typemap{$val.type} })r_{ $val.name }"
              !! "r_{ $val.name }"
}

multi toC(LLR::RegisterLValue $val) {
    $val.cast ?? "*({ %typemap{$val.type} }*)r_{ $val.name }"
              !! "*r_{ $val.name }"
}

multi toC(LLR::LocalValue $val) {
    $val.cast ?? "({ %typemap{$val.type} })l_{ $val.name }"
              !! "l_{ $val.name }"
}

multi toC(LLR::ConstantValue $val) {
    "c_{ $val.name }"
}

multi toC(LLR::Assignment $assign) {
    "{ toC($assign.lhs) } = { toC($assign.rhs) }"
}

multi toC(LLR::ImmutableRegister $reg) {
    my $statement := "{ %typemap{$reg.type} } r_{ $reg.name } = "
        ~ "GET_REG(cur_op, $*CUR_OFFSET).{ %regmap{$reg.type} }";
    $*CUR_OFFSET := $*CUR_OFFSET + 2;
    $statement
}

multi toC(LLR::MutableRegister $reg) {
    my $statement := "{ %typemap{$reg.type} }* r_{ $reg.name } = "
        ~ "&GET_REG(cur_op, $*CUR_OFFSET).{ %regmap{$reg.type} }";
    $*CUR_OFFSET := $*CUR_OFFSET + 2;
    $statement
}

multi toC(LLR::Constant $const) {
    my $statement := "{ %typemap{$const.type} } c_{ $const.name } = "
        ~ "GET_{ %getmap{ $const.type} }(cur_op, $*CUR_OFFSET)";
    $*CUR_OFFSET := $*CUR_OFFSET + %sizemap{$const.type};
    $statement
}

multi toC(LLR::Local $loc) {
    "{ %typemap{$loc.type} } l_{ $loc.name }"
}

multi toC(LLR::UnaryExpression $expr) {
    "{ $expr.op }{ toC($expr.a) }"
}

multi toC(LLR::BinaryExpression $expr) {
    "({ toC($expr.a) } { $expr.op } { toC($expr.b) })"
}

multi toC(LLR::Op $op) {
    my @*LINES;
    my $*CUR_OFFSET := 0;
    nqp::push(@*LINES, "#define { nqp::uc($op.name) } \\");
    for $op.args { nqp::push(@*LINES, "    { toC($op.lookup($_)) }; \\") }
    for $op.locals { nqp::push(@*LINES, "    { toC($op.lookup($_)) }; \\") }
    for $op.code { nqp::push(@*LINES, "    { toC($_) }; \\") }
    nqp::push(@*LINES, "    cur_op += $*CUR_OFFSET; \\")
        if $*CUR_OFFSET;
    nqp::push(@*LINES, "    goto NEXT;\n");
    nqp::join("\n", @*LINES)
}

multi toC(LLR::Unit $unit) {
    my @blocks;
    for $unit.ops { nqp::push(@blocks, toC($_)) }
    nqp::join("\n", @blocks)
}

multi toC(LLR::Int $int) {
    "{ $int.value }"
}

multi toC(LLR::Intrinsic::VM::GCSync $sync) {
    'GC_SYNC_POINT(tc)'
}

multi toC(LLR::Intrinsic::VM::Branch $branch) {
    $*CUR_OFFSET := 0;
    "cur_op = bytecode_start + { toC($branch.args[0]) }"
}

multi toC(LLR::Builtin::Str::Graphs $graphs) {
    "NUM_GRAPHS({ toC($graphs.args[0]) })"
}

multi toC(LLR::Control::If $if) {
    my $offset := $*CUR_OFFSET;
    my $statement := "if ({ toC($if.condition) }) { toC($if.statement) }";
    if $*CUR_OFFSET == 0 {
        nqp::push(@*LINES, "    $statement; \\");
        $statement := "else cur_op += $offset";
    }
    $statement
}

multi toC(LLR::Control::Unless $un) {
    my $offset := $*CUR_OFFSET;
    my $statement := "if (!{ toC($un.condition) }) { toC($un.statement) }";
    if $*CUR_OFFSET == 0 {
        nqp::push(@*LINES, "    $statement; \\");
        $statement := "else cur_op += $offset";
    }
    $statement
}

multi toC($node) {
    nqp::die("FIXME: $node");
}

