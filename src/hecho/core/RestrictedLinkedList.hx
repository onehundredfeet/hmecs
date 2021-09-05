package hecho.core;

@:allow(hecho)
@:forward(head, tail, length, iterator, sort)
abstract RestrictedLinkedList<T>(hecho.utils.LinkedList<T>) to hecho.utils.LinkedList<T> {

    inline function new() this = new hecho.utils.LinkedList<T>();

    inline function add(item:T) this.add(item);
    inline function pop() return this.pop();
    inline function remove(item:T) return this.remove(item);
    inline function exists(item:T) return this.exists(item);

}
