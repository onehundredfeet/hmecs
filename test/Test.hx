package;

import ecs.core.macro.Global;
import ecs.Workflow;
import ecs.View;
import ecs.Entity;
import TestComponents;
import TestWorlds;
import TestSystemY;
import TestSystemZ;
import TestSystemA;


class Test {
    public final TESTWORLD = 5;
    public static function main() {
        #if !macro ecsSetup(); #end
        Workflow.addSystem(new TestSystemY());
        Workflow.addSystem(new TestSystemZ());
        Workflow.addSystem(new TestSystemA());
  
        // only works with static views - factories don't work atm.
       //var factory = ecs.Workflow.createFactory(1, X, Y);
        //trace(factory);
  
        var e = new Entity();
        var e2 = new Entity();
        e.add( new K() );
        
        e.remove( K );

        var xxx = new X();
                
//        e.add( TagA.VALID );
//        e.add( TagB.VALID );
        e.add( TagA );
        e.add( TagB );
//        e.remove(TagB);
        e.add( xxx );
        e.add( new Y() );
        trace( 'e.TagA.test is ${e.get(TagA).test}');
        e.get(TagA).test = 1;
        trace( 'e.TagA.test is ${e.get(TagA).test}');
        e2.add( TagA );
        trace( 'e2.TagA.test is ${e.get(TagA).test}');
        
        trace ('E has tag a ${e.has(TagA)} b ${e.has(TagB)} a.test is ${e.get(TagA).test}');
//        xxx.a;
        
        Workflow.update(1.);
 
          
    }
    static function ecsSetup() {
        Global.setup();
    }
} 