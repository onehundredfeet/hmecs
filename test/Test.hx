package;
import ecs.core.macro.Global;
import ecs.Workflow;
import ecs.View;
import ecs.Entity;
import TestComponents;
import TestWorlds;
import TestSystems;
import TestSystemY;



class Test {
    public final TESTWORLD = 5;
    public static function main() {
        #if !macro ecsSetup(); #end
        Workflow.addSystem(new SystemX());
        Workflow.addSystem(new TestSystemY());
 
        // only works with static views - factories don't work atm.
       //var factory = ecs.Workflow.createFactory(1, X, Y);
        //trace(factory);
  
        //var e = new Entity();
        //e.add( new K() );
        
        //e.remove( K );

        var xxx = new X();
                
        xxx.a;

        Workflow.update(1.);
 
         
    }
    static function ecsSetup() {
        Global.setup();
    }
} 