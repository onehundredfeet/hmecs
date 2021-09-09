package hcqe.core;

@:allow(hcqe)
@:forward(head, tail, length, iterator, sort)
abstract RestrictedLinkedList<T>(hcqe.utils.LinkedList<T>) to hcqe.utils.LinkedList<T> {

    inline function new() this = new hcqe.utils.LinkedList<T>();

    inline function add(item:T) this.add(item);
    inline function pop() return this.pop();
    inline function remove(item:T) return this.remove(item);
    inline function exists(item:T) return this.exists(item);

}
