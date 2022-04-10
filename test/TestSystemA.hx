package;

import TestComponents;

class TestSystemA extends ecs.System {
    @:not(Y)
    var x:View<X>;
     
    var xz:View<X,Z>;
    var xy:View<X,Y,Z>;


    @:added
    function added(ix:X, e:ecs.Entity) {
        trace ("Added TestSystemA X");
        e.add( TagA.VALID );
        e.remove(TagA);
    }

    @:removed
    function removed(ix:X) {

    }

    @:not(Y)
    @:u  function updateA(ix:X) { 
        trace("SystemA|updateA");
        
    }

    @:u  function updateB(ix:X, iy:Y) { 
        trace("SystemA|updateB");
    }

    @:u  function updateC(f : TagA, iy:Y) { 
        trace("SystemA|updateC");
         
        
    }

    function blah(ix:X) {

    }
} 
          
 