package;

import TestComponents;


class TestSystemZ extends ecs.System {
    

    @:pool_rent
    function onRent() {

    }
    
    @:worlds(TestWorlds.TESTWORLDA) 
    @:u  function updateA(y:Y) { 
        trace("SystemY|update");    
         
        
    }   

     
}         
   
     