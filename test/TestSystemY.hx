package;

import TestComponents;

class TestSystemY extends ecs.System {
      
    @:worlds(TestWorlds.TESTWORLDA) 
    @:u  function updateA(y:Y) { 
        trace("SystemY|update");    
    }   
}         
   
   