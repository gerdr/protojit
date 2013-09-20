proto valueof($var) {*}

my class Variable {
    has $!name;
    has $!type;
    has $!basetype;

    method name() { $!name }
    method type() { $!type }

    method value($prefix = '') {
        my $var := self;
        my $type := $prefix ?? $prefix ~ $!basetype !! $!type;
        valueof(self).new(:$var, :$type)
    }
}

my class Value {
    has $!var;
    has $!type;

    method name() { $!var.name }
    method type() { $!type }
    method cast() { $!type ne $!var.type }
}

class LLR::ImmutableRegister is Variable {}
class LLR::MutableRegister is Variable {}
class LLR::Constant is Variable {}
class LLR::Local is Variable {}

class LLR::RegisterRValue is Value {}
class LLR::RegisterLValue is Value {}
class LLR::ConstantValue is Value {}
class LLR::LocalValue is Value {}

multi valueof(LLR::ImmutableRegister $var) { LLR::RegisterRValue }
multi valueof(LLR::MutableRegister $var) { LLR::RegisterLValue }
multi valueof(LLR::Constant $var) { LLR::ConstantValue }
multi valueof(LLR::Local $var) { LLR::LocalValue }

class LLR::Int {
    has $!value;

    method value() { $!value }
}

class LLR::Assignment {
    has $!lhs;
    has $!rhs;

    method lhs() { $!lhs }
    method rhs() { $!rhs }
}

my class Intrinsic {
    has @!args;

    method args() { @!args }
}

class LLR::Intrinsic::GCSync is Intrinsic {}
class LLR::Intrinsic::Branch is Intrinsic {}

class LLR::UnaryExpression {
    has $!op;
    has $!a;

    method op() { $!op }
    method a() { $!a }
}

class LLR::BinaryExpression {
    has $!op;
    has $!a;
    has $!b;

    method op() { $!op }
    method a() { $!a }
    method b() { $!b }
}

class LLR::Op {
    has $!name;
    has @!args;
    has @!regs;
    has @!consts;
    has @!locals;
    has @!code;
    has %!vars;

    method name() { $!name }
    method args() { @!args }
    method regs() { @!regs }
    method consts() { @!consts }
    method locals() { @!locals }
    method code() { @!code }

    method set-name($name) { $!name := $name }

    method do-declare($var) {
        my $name := $var.name;
        nqp::die("redeclaration of $name") if %!vars{$name};
        nqp::push(@!args, $name) if $*IN_SIGNATURE;
        %!vars{$name} := $var;
        $var
    }

    proto method declare($var) {*}

    multi method declare(LLR::ImmutableRegister $reg) {
        nqp::push(@!regs, $reg.name);
        self.do-declare($reg)
    }

    multi method declare(LLR::MutableRegister $reg) {
        nqp::push(@!regs, $reg.name);
        self.do-declare($reg)
    }

    multi method declare(LLR::Constant $const) {
        nqp::push(@!consts, $const.name);
        self.do-declare($const)
    }

    multi method declare(LLR::Local $loc) {
        nqp::push(@!locals, $loc.name);
        self.do-declare($loc)
    }

    method lookup($name) {
        %!vars{$name} // nqp::die("$name not found")
    }

    method push($statement) {
        nqp::push(@!code, $statement);
        $statement
    }
}

class LLR::Unit {
    has @!ops;

    method ops() { @!ops }

    proto method push($node) {*}
    multi method push(LLR::Op $op) { nqp::push(@!ops, $op) }
}
