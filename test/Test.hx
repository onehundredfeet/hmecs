package;
import hcqe.Workflow;
import hcqe.View;

class X {
    public function new() { };
}

class Y {
    public function new() { };
}

class SystemX extends hcqe.System {
    var x:View<X>;
    var xy:View<X, Y>;
}

class SystemY extends hcqe.System {
    @u inline function update(y:Y) { 
        trace("SystemY|update");
    }
    @u inline function updatexy(x:X, y:Y, dt:Float) { 
        trace("SystemY|updatexydt");

    }
}


class Test {
    public static function main() {

        Workflow.addSystem(new SystemX());
        Workflow.addSystem(new SystemY());

        // only works with static views
        var factory = hcqe.Workflow.createFactory(1, X, Y);
        trace(factory);

        var e = factory();

        trace(e);

        Workflow.update(1.);

    }
}