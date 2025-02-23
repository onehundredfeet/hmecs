package test;

import ecs.core.macro.Global;
import ecs.Workflow;
import ecs.View;
import ecs.Entity;
import test.TestComponents;
import test.TestWorlds;
import test.TestSystemY;
import test.TestSystemZ;
import test.TestSystemA;


class Test {
    public static final TESTWORLD = 0;


    public static function main() {
        #if !macro ecsSetup(); #end
        var world = Workflow.world(TESTWORLD);
        var ysystem = new TestSystemY(world);
        world.addSystem(ysystem);
        world.addSystem(new TestSystemZ(world));
        world.addSystem(new TestSystemA(world));
  
        // only works with static views - factories don't work atm.
       //var factory = ecs.Workflow.createFactory(1, X, Y);
        //trace(factory);
  
        var e = world.newEntity();
        var e2 = world.newEntity();
//        e.add( new K() );
        e.add( new F() );
        e.add( new FS() );
        e.remove( K );

        var xxx = new X();
        var fff = new F();
                
//        e.add( TagA.VALID );
//        e.add( TagB.VALID );
        e.add( TagA );
        trace( 'e.TagA is ${e.get(TagA)} has ${e.has(TagA)}');
        e.add( TagB );
        trace( 'e.TagA is ${e.get(TagA)} has ${e.has(TagA)}');
        e.remove(TagA);
        trace( 'e.TagA is ${e.get(TagA)} has ${e.has(TagA)}');
        e.add(TagA);
//        e.remove(TagB);
        e.add( xxx );
        e.add( new Y() );
        trace('y view count ${ysystem.ycount()}');
        trace( 'e.TagA is ${e.get(TagA)}');
        trace( 'e.TagA.test is ${e.get(TagA).test}');
        e.get(TagA).test = 1;
        trace( 'e.TagA.test is ${e.get(TagA).test}');
        e2.add( TagA );
        trace( 'e2.TagA.test is ${e.get(TagA).test}');
        
        trace ('E has tag a ${e.has(TagA)} b ${e.has(TagB)} a.test is ${e.get(TagA).test}');
        trace ('E has tag Y ${e.has(Y)}');
        trace('PRE SHELVE y view count ${ysystem.ycount()}');
        e.shelve(Y);
        trace('POST SHELVE y view count ${ysystem.ycount()}');
        trace ('E has tag Y ${e.has(Y)}');
        e.unshelve(Y);
        trace('POST UNSHELVE y view count ${ysystem.ycount()}');
        trace ('E has tag Y ${e.has(Y)}');
//        xxx.a;
        
        world.update(1.);
 
          
    }
    static function ecsSetup() {
        Global.setup();
    }
} 