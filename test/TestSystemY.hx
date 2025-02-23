package test;

import test.TestComponents;

class TestSystemY extends ecs.System {
      
    var viewY : ecs.View<Y>;

    public function ycount() {
        return viewY.entities.length;
    }
    @:u  function updateA(y:Y) { 
        trace("SystemY|update");    
        
    }   
}         
   
   