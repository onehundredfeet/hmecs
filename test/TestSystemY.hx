package;

import TestComponents;

class TestSystemY extends ecs.System {
      
    var viewY : ecs.View<Y>;

    public function ycount() {
        return viewY.entities.length;
    }
    @:worlds(TestWorlds.TESTWORLDA) 
    @:u  function updateA(y:Y) { 
        trace("SystemY|update");    
        
    }   
}         
   
   