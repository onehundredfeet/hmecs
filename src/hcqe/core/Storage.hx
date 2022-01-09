package hcqe.core;

#if (hcqe_vector_container || false)
@:generic
class Storage<T> {


    var size:Int;
    var h:haxe.ds.Vector<T>;


    public function new() {
        init(64);
    }


    public inline function add(id:Int, c:T) {
        if (id >= size) {
            growTo(id);
        }
        h[id] = c;
    }

    public inline function get(id:Int):T {
        return id < size ? h[id] : null;
    }

    public inline function remove(id:Int) {
        if (id < size) {
            h[id] = null;
        }
    }

    public inline function exists(id:Int) {
        return id < size ? h[id] != null : false;
    }

    public inline function reset() {
        init(64);
    }


    inline  function init(size:Int) {
        this.size = size;
        this.h = new haxe.ds.Vector<T>(size);
    }

    inline  function growTo(id:Int) {
        var nsize = size;

        while (id >= nsize) {
            nsize *= 2;
        }

        var nh = new haxe.ds.Vector<T>(nsize);

        haxe.ds.Vector.blit(h, 0, nh, 0, size);

        this.h = nh;
        this.size = nsize;
    }


}

#elseif (hcqe_array_container || true)

@:generic
class Storage<T> {
    var  _array : Array<T>;

    public inline function new() {
        _array = new Array<T>();
    }

    public inline function getArray() : Array<T> {
        return _array;
    }

    public inline function add(id:Int, c:T) {
        _array[id] = c;
    }

    public inline function get(id:Int):T {
        return _array[id];
    }

    public inline function remove(id:Int) {
        _array[id] = null;
    }

    public inline function exists(id:Int) {
        return _array[id] != null;
    }

    public inline function reset() {
        _array.splice(0, _array.length);
    }


}

#else

@:forward(get, remove, exists)
@:generic
abstract Storage<T>(haxe.ds.IntMap<T>) {


    public inline function new() {
        this = new haxe.ds.IntMap<T>();
    }


    public inline function add(id:Int, c:T) {
        this.set(id, c);
    }

    public function reset() {
        // for (k in this.keys()) this.remove(k); // python "dictionary changed size during iteration"
        var i = @:privateAccess hcqe.Workflow.nextId;
        while (--i > -1) this.remove(i); 
    }

    public inline function getArray() : Array<T>{
        return null;
    }
}

#end
