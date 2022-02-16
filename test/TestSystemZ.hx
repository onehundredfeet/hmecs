package;

import TestComponents;

class TestSystemZ extends ecs.System {
      
    @:worlds(TestWorlds.TESTWORLDA) 
    @:u  function updateA(y:Y) { 
        trace("SystemY|update");    
         
        
    }   

     
}         
   
     