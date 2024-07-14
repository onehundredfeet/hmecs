package ecs;

import ecs.core.ISystem;

/**
 * SystemList  
 * 
 * List of Systems. Can be used for better update control:  
 * ```
 *   var physics = new SystemList();
 *   physics.add(new MovementSystem());
 *   physics.add(new CollisionResolveSystem());
 *   Workflow.add(physics);
 * ```
 * 
 * @author https://github.com/deepcake
 */
class SystemList implements ISystem {


    #if ecs_profiling
    var __updateTime__ = .0;
    #end


    var name:String;

    var systems = new Array<ISystem>();

    var activated = false;


    public function new(name = 'list') {
        this.name = name;
    }

    @:noCompletion final public function __activate__() {
        if (!activated) {
            activated = true;
            for (s in systems) {
                s.__activate__();
            }
        }
    }

    @:noCompletion final public function __deactivate__() {
        if (activated) {
            activated = false;
            for (s in systems) {
                s.__deactivate__();
            }
        }
    }

    final  public function forceUpdate( dt : Float ) : Void {
        __update__(dt);
    }

    @:noCompletion final public function __update__(dt:Float) {
        #if ecs_profiling
        var __timestamp__ = haxe.Timer.stamp();
        #end

        for (s in systems) {
            s.__update__(dt);
        }

        #if ecs_profiling
        __updateTime__ = (haxe.Timer.stamp() - __timestamp__) * 1000.;
        #end
    }

    public function isActive():Bool {
        return activated;
    }

    public function info(indent = '    ', level = 0):String {
        var span = StringTools.rpad('', indent, indent.length * level);

        var ret = '$span$name';

        #if ecs_profiling
        ret += ' : $__updateTime__ ms';
        #end

        if (systems.length > 0) {
            for (s in systems) {
                ret += '\n${ s.info(indent, level + 1) }';
            }
        }

        return ret;
    }


    public function add(s:ISystem):SystemList {
        if (!exists(s)) {
            systems.push(s);
            if (activated) {
                s.__activate__();
            }
        }
        return this;
    }

    public function remove(s:ISystem):SystemList {
        if (exists(s)) {
            systems.remove(s);
            if (activated) {
                s.__deactivate__();
            }
        }
        return this;
    }

    public function removeAll():SystemList {
        if (activated) {
            for (s in systems)
                s.__deactivate__();
        }
        systems = [];
        return this;
    }

    public function exists(s:ISystem):Bool {
        return systems.contains(s);
    }

    @:generic
    public function getOp<T>(c : Class<T>) : T {
        for (x in systems) {
            if (Std.isOfType(x, c)) {
                return cast x;
            }
        }
        return null;
    }

    public function toString():String return 'SystemList';


}
