use LLR::AST;

grammar LLR::Grammar {
    token TOP { <.nl>? <op>+ %% <.nl>+ }

    token op {
        :my $*SCOPE := LLR::Op.new;
        :s op <name> <signature> <block>
    }

    token signature {
        :my $*IN_SIGNATURE := 1;
        :s '(' ~ ')' <operand>* % <.comma>
    }

    proto token operand {*}
    token operand:sym<%> { :s <type><modeflag> <sym><name><typeflag>? }
    token operand:sym<$> { :s <type> <sym><name><typeflag>? }

    token modeflag { ':' <( <[rw]> }
    token typeflag { ':' <( <[us]> }

    token block {
        :my $*OUTER := $*SCOPE;
        :s '{' ~ '}' [ <.nl>* <statement>* %% <.nl>+ ]
    }

    proto token statement {*}

    token statement:sym<intrinsic> { <intrinsic> }

    token statement:sym<define> {
        :s <type><typeflag>? <lname> '=' <expression>
    }

    token statement:sym<assign> {
        :s <var> '=' <expression>
    }

    token statement:sym<if> {
        :my $*SCOPE := LLR::Control::If.new;
        :s <sym> <term> <statement>
    }

    token statement:sym<unless> {
        :my $*SCOPE := LLR::Control::Unless.new;
        :s <sym> <term> <statement>
    }

    proto token intrinsic {*}
    token intrinsic:sym<vm::gcsync> { :s <sym> '(' ')' }
    token intrinsic:sym<vm::branch> { :s <sym> '(' <var> ')' }

    proto token var {*}
    token var:sym<%> { <sym> <name> <typeflag>? }
    token var:sym<$> { <sym> <name> <typeflag>? }
    token var:sym<loc> { <lname> <typeflag>? }

    proto token expression {*}
    token expression:sym<binary> { :s <term> <infix> <term> }
    token expression:sym<unary> { :s <prefix> <term> }
    token expression:sym<nullary> { :s <term> }

    token prefix { <[!-]> }
    token infix { <[+\-*/%^]> | '<<' | '>>' | '||' | '==' }

    proto token term {*}
    token term:sym<var> { <var> }
    token term:sym<parcel> { :s '(' ~ ')' <expression> }
    token term:sym<int> { <[+-]>? \d+ }
    token term:sym<builtin> { <builtin> }

    proto token builtin {*}
    token builtin:sym<str::graphs> { :s <sym> '(' <var> ')' }

    token keyword { [ if | unless | <type> ] <?ws> }
    token type { int8 | int16 | int32 | int64 | num32 | num64 | obj | str }
    token name { \w+ }
    token lname { <!keyword> <[\w]-[\d]> \w* }
    token comma { :s ',' \n? }
    token nl { :s \n || ';' }
    token ws { <!ww> \h* || \h+ }
}
