grammar JIT::Grammar {
    token TOP { <.nl>? <op>+ %% <.nl>+ }

    token op {
        :my @*SIGNATURE := [];
        :my %*SCOPE := nqp::hash();
        :my @*CODE := [];
        :s op <name> <signature> <attribute>? <block>
    }

    token signature {
        :s '(' ~ ')' <decl>* % <.comma>
    }

    token decl { :s <type><attribute>? <var> }

    proto token var {*}
    token var:sym<%> { <sym> <name> <attribute>? }
    token var:sym<$> { <sym> <name> <attribute>? }

    token block {
        :s '{' ~ '}' [ <.nl>? <expression>* %% <.nl> ]
    }

    token expression { :s <term>+ % [ <infix> ] }

    proto token term {*}
    token term:sym<var> { <var> }
    token term:sym<parcel> {
        :s '(' ~ ')' <expression>
    }

    proto token infix {*}
    token infix:sym<=> { <sym> }
    token infix:sym<+> { <sym> }
    token infix:sym</> { <sym> }

    token type { int8 | int16 | int32 | int64 | num32 | num64 | obj | str }
    token name { \w+ }
    token attribute { ':' <( \w+ }
    token comma { :s ',' \n? }
    token nl { :s \n || ';' }
    token ws { <!ww> \h* || \h+ }
}

class JIT::Ops::Dump::C {
    my %types := nqp::hash(
        'int8',  'MVMint8',
        'int16', 'MVMint16',
        'int32', 'MVMint32',
        'int64', 'MVMint64',
        'num32', 'MVMnum32',
        'num64', 'MVMnum64',
        'obj',   'MVMObject*',
        'str',   'MVMString*'
    );

    my %utypes := nqp::hash(
        'int8',  'MVMuint8',
        'int16', 'MVMuint16',
        'int32', 'MVMuint32',
        'int64', 'MVMuint64'
    );

    my %reg_members := nqp::hash(
        'int8',  'i8',
        'int16', 'i16',
        'int32', 'i32',
        'int64', 'i64',
        'num32', 'n32',
        'num64', 'n64',
        'obj',   'o',
        'str',   's'
    );

    sub gen($node) {
        if $node<node> eq 'var' {
            my $decl := %*SCOPE{$node<name>};
            nqp::die('TODO') unless $decl;

            if $decl<mode> eq 'r' {
                return ($node<attribute> eq 'u' ?? "({ %utypes{$decl<type>} })" !! '') ~ $decl<name>;
            }
            elsif $decl<mode> eq 'w' {
                return '*' ~ ($node<attribute> eq 'u' ?? "({ %utypes{$decl<type>} }*)" !! '') ~ $decl<name>;
            }
        }
        elsif $node<node> eq 'parcel' {
            return "({ nqp::join(' ', $node<code>) })";
        }
        else { nqp::die('TODO') }
    }

    method op($/) {
        say("#define { nqp::uc($<name>) } \\");
        my $offset := 0;
        for @*SIGNATURE {
            if $_<mode> eq 'r' {
                say("    { %types{$_<type>} } { $_<name> } = GET_REG(cur_op, $offset).{ %reg_members{$_<type>} }; \\");
                $offset := $offset + 2;
            }
            elsif $_<mode> eq 'w' {
                say("    { %types{$_<type>} }* { $_<name> } = &GET_REG(cur_op, $offset).{ %reg_members{$_<type>} }; \\");
                $offset := $offset + 2;
            }
            else { nqp::die('TODO') }
        }

        for @*CODE {
            say("    $_; \\");
        }

        say("    cur_op += $offset; \\") if $offset;
        say($<attribute> eq 'branch' ?? '' !! "    goto NEXT;\n");
    }

    method signature($/) {
        for $<decl> {
            my $decl := $_.ast;
            nqp::push(@*SIGNATURE, $decl);
            %*SCOPE{$decl<name>} := $decl;
        }
    }

    method decl($/) {
        my $var := $<var>.ast;

        if $var<attribute> {
            nqp::die('illegal attribute');
        }

        my $attribute := ~($<attribute> // '');
        $var<type> := ~$<type>;

        if $var<sigil> eq '%' {
            if $attribute eq 'r' || $attribute eq 'w' {
                $var<mode> := $<attribute>;
                make $var;
            }
            else { nqp::die('TODO') }
        }
        elsif $var<sigil> eq '$' { nqp::die('TODO') }
    }

    method var:sym<%>($/) {
        make nqp::hash(
            'node', 'var',
            'sigil', ~$<sym>,
            'name', ~$<name>,
            'attribute', ~($<attribute> // '')
        )
    }

    method var:sym<$>($/) {
        make nqp::hash(
            'node', 'var',
            'sigil', ~$<sym>,
            'name', ~$<name>,
            'attribute', ~($<attribute> // '')
        )
    }

    method block($/) {
        for $<expression> {
            nqp::push(@*CODE, nqp::join(' ', $_.ast))
        }
    }

    method expression($/) {
        my @code := [ gen($<term>[0].ast) ];
        my $i := 1;
        while $i < nqp::elems($<term>) {
            nqp::push(@code, ~$<infix>[$i - 1]);
            nqp::push(@code, gen($<term>[$i].ast));
            $i := $i + 1;
        }
        make @code;
    }

    method term:sym<var>($/) { make $<var>.ast }

    method term:sym<parcel>($/) {
        make nqp::hash(
            'node', 'parcel',
            'code', $<expression>.ast
        )
    }
}

#JIT::Grammar.HOW.trace-on(JIT::Grammar);

my $test := '
op no_op() {}

op add_i(int64:w %r0, int64:r %r1, int64:r %r2) {
    %r0 = %r1 + %r2
}

op div_u(int64:w %r0, int64:r %r1, int64:r %r2) {
    %r0:u = %r1:u / %r2:u
}
';

JIT::Grammar.parse($test, :actions(JIT::Ops::Dump::C.new));
