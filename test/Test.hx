package;
import ecs.core.macro.Global;
import ecs.Workflow;
import ecs.View;

class X {
    public function new() { };
}

class Y {
    public function new() { };
}
class Z {
    public function new() { };
}


class SystemX extends ecs.System {
    final TESTWORLDA : Int = 5;

    @:not(Y)
    var x:View<X>;
    
    var xz:View<X,Z>;
    var xy:View<X, Y,Z>;

    @:not(Y)
    @u inline function update(x:X) { 
        trace("SystemX|update");
    }
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

class K {

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
        
        e.remove( K );

        trace(e);

        Workflow.update(1.);

        Global.setup();
    }
}