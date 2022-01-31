package;
import ecs.Workflow;
import ecs.View;

class X {
    public function new() { };
}

class Y {
    public function new() { };
}

class SystemX extends ecs.System {
    final TESTWORLDA : Int = 5;
    var x:View<X>;
    var xy:View<X, Y>;
}




class SystemY extends ecs.System {
    
    @:worlds(SystemX.TESTWORLDA)
    @u inline function update(y:Y) { 
        trace("SystemY|update");
    }
    @u inline function updatexy(x:X, y:Y, dt:Float) { 
        trace("SystemY|updatexydt");

    }
}


class Test {
    public final TESTWORLD = 5;
    public static function main() {

        Workflow.addSystem(new SystemX());
        Workflow.addSystem(new SystemY());

        // only works with static views
        var factory = ecs.Workflow.createFactory(1, X, Y);
        trace(factory);

        var e = factory();

        trace(e);

        Workflow.update(1.);

    }
}