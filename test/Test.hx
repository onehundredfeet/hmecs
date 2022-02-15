package;
import ecs.core.macro.Global;
import ecs.Workflow;
import ecs.View;
import ecs.Entity;

class X {
    public function new() { };
}

class Y {
    public function new() { };
}
class Z {
    public function new() { };
}

class Worlds extends ecs.System  {
    var x : View<X>;
    final TESTWORLDA : Int = 5;
}

class SystemX extends ecs.System {
    @:not(Y)
    var x:View<X>;
     
    var xz:View<X,Z>;
    var xy:View<X,Y,Z>;

    @:not(Y)
    @u inline function update(x:X) { 
        trace("SystemX|update");
    }
}
 
class SystemY extends ecs.System {
      
    @:worlds(Worlds.TESTWORLDA)
    @:u inline function updateA(y:Y) { 
        trace("SystemY|update");
    }   
}         
            
      
class K {
     public function new () {}
}
class Test {
    public final TESTWORLD = 5;
    public static function main() {
        setup();

        Workflow.addSystem(new SystemX());
        Workflow.addSystem(new SystemY());
 
        // only works with static views - factories don't work atm.
       //var factory = ecs.Workflow.createFactory(1, X, Y);
        //trace(factory);
 
        var e = new Entity();
        e.add( new K() );
        
        e.remove( K );

        //trace(e);

        Workflow.update(1.);

       
    }

    static function setup() {
        Global.setup();
    }
}