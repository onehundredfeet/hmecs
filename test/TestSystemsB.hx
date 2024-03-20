package test;

import test.TestComponents;

class TestSystemsB extends ecs.System {
//    @:not(Y)
//    var x:View<X>;
     
  //  var xz:View<X,Z>;
    //var xy:View<X,Y,Z>;

    @:not(Y)
    @:u  function updateA(ix:X) { 
        trace("SystemX|update");
        
    }

    @:u  function updateB(ix:X, iy:Y) { 
        trace("SystemX|update");
        
         
        
        
    }

    @:u  function updateC(iy:Y) { 
        trace("SystemX|update");
         
        
    }

    function blah(ix:X) {

    }
} 
          
