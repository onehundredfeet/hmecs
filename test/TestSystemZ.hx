package test;

import test.TestComponents;


class TestSystemZ extends ecs.System {
    

    @:pool_rent
    function onRent() {

    }
    
    @:u  function updateA(y:Y) { 
        trace("SystemY|update");    
         
        
    }   

     
}         
   
     