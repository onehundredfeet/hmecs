package;

import TestComponents;

class TestSystemA extends ecs.System {
    @:not(Y)
    var x:View<X>;
     
    var xz:View<X,Z>;
    var xy:View<X,Y,Z>;


    @:added
    function added(ix:X, e:ecs.Entity) {
        e.add( TestTag.VALID );
        e.remove(TestTag);
    }

    @:removed
    function removed(ix:X) {

    }

    @:not(Y)
    @:u  function updateA(ix:X) { 
        trace("SystemX|update");
        
    }

    @:u  function updateB(ix:X, iy:Y) { 
        trace("SystemX|update");
    }

    @:u  function updateC(f : TestTag, iy:Y) { 
        trace("SystemX|update");
         
        
    }

    function blah(ix:X) {

    }
} 
          
 