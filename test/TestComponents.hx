package test;

@:storage(FAST)
class X {
    public var a : Float;
    public inline function new() { };
   
}

@:storage(FLAT)
class F {
    public var a : Float = 0.0;
    public inline function new() { };
    public inline function copy( from : F ) {
        this.a = from.a;
    }
}

@:storage(FLAT)
@:struct
class FS {
    public var a : Float= 0.0;
    public inline function new() { };
    public inline function copy( from : FS ) {
        this.a = from.a;
    }
}


@:storage(COMPACT)
class Y {
    public var b : Float;
    public function new() { };
}
@:storage(COMPACT)
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
