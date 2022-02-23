package;

@:storage(FAST)
class X {
    public var a : Float;
    public function new() { };
}

@:storage(COMPACT)
class Y {
    public var b : Float;
    public function new() { };
}
class Z {
    public function new() { };
}

class K {
    public function new () {}
} 

@:storage(TAG)
@:enum abstract TestTag(Int) from Int to Int {
    var INVALID = 0;
    var VALID = 1;
}
