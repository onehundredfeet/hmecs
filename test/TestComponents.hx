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
class TagA {
     function new () {}

    public var test = 0;

}

@:storage(TAG)
class TagB {
     function new () {}
    public var test = "hi";
}
