use LLR::AST;

class LLR::Actions {
    method TOP($/) {
        my $unit := LLR::Unit.new;
        for $<op> { $unit.push($_.ast) }
        make $unit;
    }

    method op($/) {
        $*SCOPE.set-name(~$<name>);
        make $*SCOPE;
    }

    method operand:sym<%>($/) {
        my $name := ~$<name>;
        my $basetype := ~$<type>;
        my $prefix := ~$<typeflag>;
        my $type := $prefix ~ $basetype;
        my $mode := ~$<modeflag>;

        my $class;
        if $mode eq 'r' { $class := LLR::ImmutableRegister }
        elsif $mode eq 'w' { $class := LLR::MutableRegister }

        $*SCOPE.declare($class.new(:$name, :$type, :$basetype));
    }

    method operand:sym<$>($/) {
        my $name := ~$<name>;
        my $basetype := ~$<type>;
        my $prefix := ~$<typeflag>;
        my $type := $prefix ~ $basetype;

        $*SCOPE.declare(LLR::Constant.new(:$name, :$type, :$basetype));
    }

    method statement:sym<assign>($/) {
        $*SCOPE.push(LLR::Assignment.new(
            lhs => $<var>.ast,
            rhs => $<expression>.ast
        ));
    }

    method statement:sym<define>($/) {
        my $name := ~$<lname>;
        my $basetype := ~$<type>;
        my $prefix := ~$<typeflag>;
        my $type := $prefix ~ $basetype;

        my $loc := $*SCOPE.declare(LLR::Local.new(:$name, :$type, :$basetype));
        $*SCOPE.push(LLR::Assignment.new(
            lhs => $loc.value,
            rhs => $<expression>.ast
        ));
    }

    method statement:sym<if>($/) {
        $*SCOPE.set-condition($<term>.ast);
        $*OUTER.push($*SCOPE);
    }

    method statement:sym<unless>($/) {
        $*SCOPE.set-condition($<term>.ast);
        $*OUTER.push($*SCOPE);
    }

    method statement:sym<intrinsic>($/) {
        $*SCOPE.push($<intrinsic>.ast);
    }

    method intrinsic:sym<vm::gcsync>($/) {
        make LLR::Intrinsic::VM::GCSync.new();
    }

    method intrinsic:sym<vm::branch>($/) {
        make LLR::Intrinsic::VM::Branch.new(args => [ $<var>.ast ]);
    }

    method builtin:sym<str::graphs>($/) {
        make LLR::Builtin::Str::Graphs.new(args => [ $<var>.ast ]);
    }

    method var:sym<%>($/) {
        make $*SCOPE.lookup(~$<name>).value(~$<typeflag>);
    }

    method var:sym<$>($/) {
        make $*SCOPE.lookup(~$<name>).value(~$<typeflag>);
    }

    method var:sym<loc>($/) {
        make $*SCOPE.lookup(~$<lname>).value(~$<typeflag>);
    }

    method expression:sym<binary>($/) {
        make LLR::BinaryExpression.new(
            op => ~$<infix>,
            a => $<term>[0].ast,
            b => $<term>[1].ast
        );
    }

    method expression:sym<unary>($/) {
        make LLR::UnaryExpression.new(
            op => ~$<prefix>,
            a => $<term>.ast
        );
    }

    method expression:sym<nullary>($/) {
        make $<term>.ast;
    }

    method term:sym<var>($/) { make $<var>.ast }
    method term:sym<parcel>($/) { make $<expression>.ast }
    method term:sym<int>($/) { make LLR::Int.new(value => +$/) }
    method term:sym<builtin>($/) { make $<builtin>.ast }
}
