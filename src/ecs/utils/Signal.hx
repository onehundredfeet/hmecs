package ecs.utils;
#if false
import ecs.utils.FastEntitySet;
import ecs.utils.FastHashableSet;

#if macro
import haxe.macro.Expr;
#end

/**
 * ...
 * @author https://github.com/deepcake
 */
@:forward(length, remove, add, removeAll, iterator)
@:generic
abstract Signal<T : IHashable>(FastHashableSet<T>) {


    public inline function new() this = new FastHashableSet<T>();


    public inline function has(listener:T):Bool {
        return this.exists(listener);
    }


    public inline function size() {
        return this.length;
    }

    macro public function dispatch(self:Expr, args:Array<Expr>) {
        return macro {
            for (listener in $self) {
                listener($a{args});
            }
        }
    }


}

#end