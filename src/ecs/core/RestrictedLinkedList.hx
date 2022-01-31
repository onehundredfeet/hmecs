package ecs.core;

@:allow(ecs)
@:forward(head, tail, length, iterator, sort)
abstract RestrictedLinkedList<T>(ecs.utils.LinkedList<T>) to ecs.utils.LinkedList<T> {

    inline function new() this = new ecs.utils.LinkedList<T>();

    inline function add(item:T) this.add(item);
    inline function pop() return this.pop();
    inline function remove(item:T) return this.remove(item);
    inline function exists(item:T) return this.exists(item);

}
