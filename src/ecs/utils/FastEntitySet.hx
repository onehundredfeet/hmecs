package ecs.utils;

class FastEntityArraySkippingIterator {
    var set:Array<Int>;
    var i:Int;
  
    public inline function new(set:Array<Int>) {
      this.set = set;
      i = 0;
      while (i < set.length && set[i] == -1) i++;
    }
  
    public inline function hasNext() {
      return i < set.length;
    }
  
    public inline function next() {
        var idx = i++;
        while (i < set.length && set[i] == -1) i++;
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
        _setArray[idx] = -1;
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
