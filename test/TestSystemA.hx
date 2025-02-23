package test;

import test.TestComponents;

class TestSystemA extends ecs.System {
    @:not(Y)
    var x:View<X>;
     
    var xz:View<X,Z>;
    var xy:View<X,Y,Z>;

    @:added
    function addedF(f : F, e : ecs.Entity) {
        trace('Added TestSystemA F wid : ${e.worldId()}');
    }

    @:added
    function added(ix:X, e:ecs.Entity) {
        trace ("Added TestSystemA X");
    }

    @:removed
    function removed(ix:X) {

    }

    @:update function updateF(f: F ) {
//        trace("SystemA|updateF");
    }

    @:not(Y)
    @:u  function updateA(ix:X) { 
        trace("SystemA|updateA");
        
    }

    @:u  function updateB(ix:X, iy:Y) { 
        trace("SystemA|updateB");
    }

    @:u  function updateC(f : TagA, iy:Y) { 
        trace('SystemA|updateC tag ${f.test}');
         
        
    }

    function blah(ix:X) {

    }
} 
          
 