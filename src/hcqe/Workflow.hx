package hcqe;

#if macro
import haxe.macro.Expr;
using hcqe.core.macro.ComponentBuilder;
using hcqe.core.macro.ViewsOfComponentBuilder;
using hcqe.core.macro.MacroTools;
using haxe.macro.Context;
using Lambda;
using haxe.macro.ComplexTypeTools;
using haxe.macro.Context;
using haxe.macro.Expr;
using haxe.macro.TypeTools;
import haxe.macro.Expr.ComplexType;
using hcqe.core.macro.MacroTools;
using haxe.macro.Context;
#end

import hcqe.Entity.Status;
import hcqe.core.AbstractView;
import hcqe.core.ICleanableComponentContainer;
import hcqe.core.ISystem;
import hcqe.core.RestrictedLinkedList;


/**
 *  Workflow  
 * 
 * @author https://github.com/deepcake
 */
class Workflow {


    @:allow(hcqe.Entity) static inline final INVALID_ID = 0;


    static var nextId = INVALID_ID + 1;

    static var idPool = new Array<Int>();

    static var statuses = new Array<Status>();

    static var worldFlags = new Array<Int>();

    // all of every defined component container
    static var definedContainers = new Array<ICleanableComponentContainer>();
    // all of every defined view
    static var definedViews = new Array<AbstractView>();

    static var _singleton : Entity;

    static var _worldSingletons : Array<Entity> = [];

    public static function singleton() {
        if (_singleton.isValid()) {
            return _singleton;
        }
        _singleton = new Entity();
        return _singleton;
    }
    /**
     * All active entities
     */
    public static var entities(default, null) = new RestrictedLinkedList<Entity>();
    /**
     * All active views
     */
    public static var views(default, null) = new RestrictedLinkedList<AbstractView>();

    /**
     * All systems that will be called when `update()` is called
     */
    public static var systems(default, null) = new RestrictedLinkedList<ISystem>();


    #if echoes_profiling
    static var updateTime = .0;
    #end


    /**
     * Returns the workflow statistics:  
     * _( systems count ) { views count } [ entities count | entity cache size ]_  
     * With `echoes_profiling` flag additionaly returns:  
     * _( system name ) : time for update ms_  
     * _{ view name } [ collected entities count ]_  
     * @return String
     */
    public static function info():String {
        var ret = '# ( ${systems.length} ) { ${views.length} } [ ${entities.length} | ${idPool.length} ]'; // TODO version or something

        #if echoes_profiling
        ret += ' : $updateTime ms'; // total
        for (s in systems) {
            ret += '\n${ s.info('    ', 1) }';
        }
        for (v in views) {
            ret += '\n    {$v} [${ v.entities.length }]';
        }
        #end

        return ret;
    }


    /**
     * Update 
     * @param dt deltatime
     */
    public static function update(dt:Float) {
        #if echoes_profiling
        var timestamp = Date.now().getTime();
        #end

        for (s in systems) {

            s.__update__(dt);

        }

        #if echoes_profiling
        updateTime = Std.int(Date.now().getTime() - timestamp);
        #end
    }


    /**
     * Removes all views, systems and entities from the workflow, and resets the id sequence 
     */
    public static function reset() {
        for (e in entities) {
            e.destroy();
        }
        for (s in systems) {
            removeSystem(s);
        }
        for (v in definedViews) {
            v.reset();
        }
        for (c in definedContainers) {
            c.reset();
        }

        idPool.splice(0, idPool.length);
        statuses.splice(0, statuses.length);
        worldFlags.splice(0, worldFlags.length);

        nextId = INVALID_ID + 1;
    }


    // System

    /**
     * Adds the system to the workflow
     * @param s `System` instance
     */
    public static function addSystem(s:ISystem) {
        if (!hasSystem(s)) {
            systems.add(s);
            s.__activate__();
        }
    }

    /**
     * Removes the system from the workflow
     * @param s `System` instance
     */
    public static function removeSystem(s:ISystem) {
        if (hasSystem(s)) {
            s.__deactivate__();
            systems.remove(s);
        }
    }

    /**
     * Returns `true` if the system is added to the workflow, otherwise returns `false`  
     * @param s `System` instance
     * @return `Bool`
     */
    public static function hasSystem(s:ISystem):Bool {
        return systems.exists(s);
    }


    // Entity

    @:allow(hcqe.Entity) static function id(immediate:Bool, worlds:Int):Int {
        var id = idPool.pop();

        if (id == null) {
            id = nextId++;
        }

        if (immediate) {
            statuses[id] = Active;
            entities.add(id);
        } else {
            statuses[id] = Inactive;
        }
        worldFlags[id] = worlds;
        return id;
    }

    public static function worlds(id:Int) {
        if (status(id) == Active) {
            return worldFlags[id];
        }
        return 0;
    }

    public static function worldEntity( idx : Int ) {
        if (!_worldSingletons[idx].isValid()) {
            _worldSingletons[idx] = new Entity();
        }
       
        return _worldSingletons[idx];
    }
/*
    macro function getContainer( containerName : String ) {
        var containerName = (c.typeof().follow().toComplexType()).getComponentContainer().followName();
        return macro @:privateAccess $i{ containerName }.inst();
    }


  /**
     * Creates a new archetype that makes entities
     * @param components comma separated list of components of `Any` type
     * @return `Entity`
     */
   

   
     #if macro
     static function exprOfClassToTypeName( e : ExprOf<Class<Any>>)  {
         return e.parseClassName().getType().follow().toComplexType().typeFullName();
     }
     static function exprOfClassToTypePath( e : ExprOf<Class<Any>>) : TypePath{
        var x  =  e.parseClassName().getType().toComplexType().followComplexType();
        //trace("tpath: " + x);
        switch(x) {
            case TPath(p): return p;
            default:
        }
        return null;
    }
     
     /*
     static function exprOfClassToTypePath( e : ExprOf<Class<Any>>) : TPath {
        var x =  e.parseClassName().getType().follow().toComplexType();
        trace("tpath: " + x);
        return x;
    }
    */
    // var allocation = components.map(function(c) return  {expr: ENew(exprOfClassToTypePath(c)),  pos:Context.currentPos()});
     #end
    
/*
     macro public static function addNoViews(self:Expr, components:Array<ExprOf<Any>>):ExprOf<hcqe.Entity> {
        if (components.length == 0) {
            Context.error('Required one or more Components', Context.currentPos());
        }

       
        var body = []
            .concat(
                addComponentsToContainersExprs
            )
            
            .concat([ 
                macro return __entity__ 
            ]);

        var ret = macro #if (haxe_ver >= 4) inline #end ( function(__entity__:hcqe.Entity) $b{body} )($self);

        return ret;
    }
*/
     macro public static function createFactory( worlds : ExprOf<Any>, components:Array<ExprOf<Class<Any>>>) { //:ExprOf<hcqe.Factory> {
        if (components.length == 0) {
            Context.error('Required one or more Components', Context.currentPos());
        }

        //var pp = new haxe.macro.Printer();
        var classNames = components.map(function(c) return  {expr: EConst(CString(exprOfClassToTypeName(c))),  pos:Context.currentPos()});
       var allocation = components.map(function(c) return {expr: ENew(exprOfClassToTypePath(c), []),  pos:Context.currentPos()} );

       var addComponentsToContainersExprs = components.map(function(c) {
          // trace("parsetname|" + c.parseClassName().getType().toComplexType());
           var containerName = (c.parseClassName().getType().follow().toComplexType()).getComponentContainer().followName();
           var alloc = {expr: ENew(exprOfClassToTypePath(c), []), pos:Context.currentPos()};
           return macro @:privateAccess $i{ containerName }.inst().add(__entity__, $alloc);
       });

       //trace(pp.printExprs(allocation, "\n"));

        var body = []
        .concat([ 
            macro var _views : Array<hcqe.core.AbstractView> = []
        ])
        .concat([ 
           // macro trace("Tracing against " + hcqe.Workflow.views.length)
        ])
        .concat([ 
            macro 
            for (v in hcqe.Workflow.views) {
                if (@:privateAccess  v.isMatchedByTypes( $worlds, $a{classNames})) {
                    _views.push( v );
                }
            }
        ])
        .concat([ 
            macro return function( ) {
                var __entity__ = new hcqe.Entity($worlds);
//                hcqe.Workflow.addNoViews(e, $a{allocation});
                $b{addComponentsToContainersExprs};

                //trace("adding to views " + _views.length);
                for(v in _views) {
                    //trace("adding to view ");
                    @:privateAccess v.addMatchedNew(__entity__ );
                }
                return __entity__;
            }
        ])
        ;

        var ret = macro inline ( function() $b{body} )();

        //trace(pp.printExpr(ret));
        return ret;

        #if false
        .concat(
            addComponentsToContainersExprs
        )
        var addComponentsToContainersExprs = components
            .map(function(c) {
                var containerName = (c.typeof().follow().toComplexType()).getComponentContainer().followName();
                return macro @:privateAccess $i{ containerName }.inst();
            });

      
      
        return macro "";
        #end
    }  
    #if factories
#end

    @:allow(hcqe.Entity) static inline function setWorlds(id:Int,flags:Int) {
        if (status(id) == Active) {
            remove(id);
            worldFlags[id] = flags;
            add(id);
        }
        return 0;
    }
    @:allow(hcqe.Entity) static inline function joinWorld(id:Int, idx:Int) {
        if (status(id) == Active) {
            remove(id);
            worldFlags[id] = worldFlags[id] | (1 << idx);
            add(id);
        }
    }

    @:allow(hcqe.Entity) static inline function leaveWorld(id:Int, idx:Int) {
        if (status(id) == Active) {
            remove(id);
            worldFlags[id] = worldFlags[id] & ~(1 << idx);
            add(id);
        }
    }
    @:allow(hcqe.Entity) static inline function cache(id:Int) {
        // Active or Inactive
        if (status(id) < Cached) {
            removeAllComponentsOf(id);
            entities.remove(id);
            idPool.push(id);
            statuses[id] = Cached;
        }
    }

    @:allow(hcqe.Entity) static inline function add(id:Int) {
        if (status(id) == Inactive) {
            statuses[id] = Active;
            entities.add(id);
            for (v in views) v.addIfMatched(id);
        }
    }

    @:allow(hcqe.Entity) static inline function remove(id:Int) {
        if (status(id) == Active) {
            for (v in views) v.removeIfExists(id);
            entities.remove(id);
            statuses[id] = Inactive;
        }
    }

    @:allow(hcqe.Entity) static inline function status(id:Int):Status {
        if (id <= Workflow.INVALID_ID) return Status.Invalid;
        return statuses[id];
    }

    @:allow(hcqe.Entity) static inline function removeAllComponentsOf(id:Int) {
        if (status(id) == Active) {
            for (v in views) {
                v.removeIfExists(id);
            }
        }
        for (c in definedContainers) {
            c.remove(id);
        }
    }

    @:allow(hcqe.Entity) static inline function printAllComponentsOf(id:Int):String {
        var ret = '#$id:';
        for (c in definedContainers) {
            if (c.exists(id)) {
                ret += '${ c.print(id) },';
            }
        }
        return ret.substr(0, ret.length - 1);
    }



}
