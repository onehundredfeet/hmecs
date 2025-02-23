package ecs.utils;

class FastEntityArraySkippingIterator {
    var set:Array<Entity>;
    var i:Int;
  
    public inline function new(set:Array<Entity>) {
      this.set = set;
      i = 0;
      while (i < set.length && set[i] == ecs.Entity.INVALID_ENTITY) i++;
    }
  
    public inline function hasNext() {
      return i < set.length;
    }
  
    public inline function next() {
        var idx = i++;
        while (i < set.length && set[i] == ecs.Entity.INVALID_ENTITY) i++;
        return set[idx];
    }
  }


class FastEntitySet {
    public function new() {
    }
    var _setMap = new Map<Entity, Int>();
    var _setArray = new Array<Entity>();
    var _freeList = new Array<Int>();
    var _count = 0;

    public inline function add(value:Entity) {
        var idx = 0;
        if (_freeList.length > 0) {
            idx = _freeList.pop();
        } else {
            idx = _setArray.length;
            _setArray.push(value);
        }
        // var idx = _freeList.length > 0 ? _freeList.pop() : _setArray.length;
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
        _setArray[idx] = ecs.Entity.INVALID_ENTITY;
        _freeList.push(idx);
        _count--;
        return true;
    }

    public inline function removeAll() {
        _setMap.clear();
        _setArray.resize(0);
        _freeList.resize(0);
        _count = 0;
    }

    public inline function iterator():Iterator<Entity> {
        return new FastEntityArraySkippingIterator(_setArray);
    }

    public var length(get, null):Int;

    public inline function get_length() : Int {
        return _count;
    }
}

@:forward(length, iterator, exists)
abstract ReadOnlyFastEntitySet(ecs.utils.FastEntitySet) from ecs.utils.FastEntitySet{

}
