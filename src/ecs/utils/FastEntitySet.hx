package ecs.utils;

@:generic
class FastEntitySet {
    public function new() {
    }
    var _setMap = new Map<Entity, Int>();
    var _setArray = new Array<Entity>();
    var _freeList = new Array<Int>();
    var _count = 0;

    public inline function add(value:Entity) {
        var idx = _freeList.length > 0 ? _freeList.pop() : _setArray.length;
        _setArray[idx] = value;
        _setMap.set(value, idx);
        _count++;
    }

    public inline function exists(value:Entity) : Bool {
        return _setMap.exists(value);
    }

    public inline function remove(value:Entity) : Bool{
        var idx = _setMap.get(value);
        if (idx == null) return false;
        _setMap.remove(value);
        _freeList.push(idx);
        _count--;
        return true;
    }

    public function removeAll() {
        _setMap.clear();
        _setArray.resize(0);
        _freeList.resize(0);
        _count = 0;
    }

    public inline function iterator():Iterator<Entity> {
        var x = _setMap.keys();
        return x;
    }

    public var length(get, null):Int;

    public inline function get_length() : Int {
        return _count;
    }
}