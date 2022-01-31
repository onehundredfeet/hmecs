package ecs.core.macro;


#if macro
import haxe.macro.Printer;
import tink.core.Ref;
import ecs.core.macro.MacroTools.*;
import ecs.core.macro.ComponentBuilder.*;
import ecs.core.macro.ViewsOfComponentBuilder.*;
import haxe.macro.Expr;
import haxe.macro.Type.ClassField;
import haxe.macro.Type.ModuleType;

using ecs.core.macro.MacroTools;
using haxe.macro.ComplexTypeTools;
using haxe.macro.Context;
using Lambda;


class ViewBuilder {


    static var viewIndex = -1;
    static var viewTypeCache = new Map<String, haxe.macro.Type>();

    public static var viewIds = new Map<String, Int>();
    public static var viewNames = new Array<String>();

    public static var viewCache = new Map<String, { cls:ComplexType, components:Array<{ cls:ComplexType }> }>();


    public static function getView(components:Array<{ cls:ComplexType }>, worlds : Int):ComplexType {
        return createViewType(components, worlds).toComplexType();
    }

    public static function getViewName(components:Array<{ cls:ComplexType }>, worlds :Int) {
        return 'ViewOf_' + StringTools.hex(worlds, 8) + "_" + components.map(function(c) return c.cls).joinFullName('_');
    }

    static var callbackEstablished = false;

    static function afterTypingCallback(m:Array<ModuleType>) {
        #if false
//        trace('After typing callback : ${m.length}');

        trace ('Total Views ${viewNames.length}');
        for (n in viewNames) {
            trace('View ${n}');
        }
        #end
    }

    public static function build() {
        if (!callbackEstablished) {
            Context.onAfterTyping(afterTypingCallback);
            callbackEstablished = true;
        }

        var x = Context.getLocalType();
        
        //trace('Creating view for: ${x} -> ${x.getName()}');

        var worlds : Ref<Int> = 0xffffffff;
        var components = parseComponents(Context.getLocalType(), worlds);
        return createViewType(components, worlds.value);
    }


    static function parseComponents(type:haxe.macro.Type, worlds : tink.core.Ref<Int>) {
        return switch(type) {
            case TInst(_, params = [x = TType(_, _) | TAnonymous(_) | TFun(_, _)]) if (params.length == 1):
                parseComponents(x,worlds );

            case TType(_.get() => { type: x }, []):
                parseComponents(x,worlds);

            case TAnonymous(_.get() => p):
                p.fields
                    .map(function(f) return { cls: f.type.follow().toComplexType() });

            case TFun(args, ret):
                args
                    .map(function(a) return a.t.follow().toComplexType())
                    .concat([ ret.follow().toComplexType() ])
                    .filter(function(ct) {
                        return switch (ct) {
                            case (macro:StdTypes.Void): false;
                            default: true;
                        }
                    })
                    .map(function(ct) return { cls: ct });

            case TInst(c, types):
                types = types.filter(function(tt){
                    switch(tt) {
                        case TInst(t, params):
                            if (StringTools.startsWith(t.get().name, "SWorlds.")) {
                                worlds.value = MacroTools.stringToWorlds( t.get().name.substring(1));
                                return false;
                            }
                            return true;
                        default:
                            return true;
                    }
                    
                });
                
                types
                    .map(function(t) return t.follow().toComplexType())
                    .map(function(ct) return { cls: ct });

            case x: 
                Context.error('Unexpected Type Param: $x', Context.currentPos());
        }
    }


    public static function createViewType(components:Array<{ cls:ComplexType }>, worlds = 0xffffffff) {
        var viewClsName = getViewName(components, worlds);
        var viewType = viewTypeCache.get(viewClsName);

        if (viewType == null) { 
            // first time call in current build

            var index = ++viewIndex;

            try viewType = Context.getType(viewClsName) catch (err:String) {
                // type was not cached in previous build

                var viewTypePath = tpath([], viewClsName, []);
                var viewComplexType = TPath(viewTypePath);

                // signals
                var signalTypeParamComplexType = TFunction([ macro:ecs.Entity ].concat(components.map(function(c) return c.cls)), macro:Void);
                var signalTypePath = tpath(['ecs', 'utils'], 'Signal', [ TPType(signalTypeParamComplexType) ]);

                // signal args for dispatch() call
                var signalArgs = [ macro id ].concat(components.map(function(c) return getLookup(c.cls, macro id )));

                // component related views
                var addViewToViewsOfComponent = components.map(function(c) {
                    var viewsOfComponentName = getViewsOfComponent(c.cls).followName();
                    return macro @:privateAccess $i{ viewsOfComponentName }.inst().addRelatedView(this);
                });

                // type def
                var def:TypeDefinition = macro class $viewClsName extends ecs.core.AbstractView {

                    static var instance = new $viewTypePath();

                    @:keep inline public static function inst():$viewComplexType {
                        return instance;
                    }

                    // instance

                    public var onAdded(default, null) = new $signalTypePath();
                    public var onRemoved(default, null) = new $signalTypePath();

                    function new() {
                        @:privateAccess ecs.Workflow.definedViews.push(this);
                        $b{ addViewToViewsOfComponent }
                    }

                    override function dispatchAddedCallback(id:Int) {
                        onAdded.dispatch($a{ signalArgs });
                    }

                    override function dispatchRemovedCallback(id:Int) {
                        onRemoved.dispatch($a{ signalArgs });
                    }

                    override function reset() {
                        super.reset();
                        onAdded.removeAll();
                        onRemoved.removeAll();
                    }

                }

                //var iteratorTypePath = getViewIterator(components).tp();
                //def.fields.push(ffun([], [APublic, AInline], 'iterator', null, null, macro return new $iteratorTypePath(this.echoes, this.entities.iterator()), Context.currentPos()));

                // iter
                {
                    var funcComplexType = TFunction([ macro:ecs.Entity ].concat(components.map(function(c) return c.cls)), macro:Void);
                    var funcCallArgs = [ macro __entity__ ].concat(components.map(function(c) return getComponentContainerInfo(c.cls).getGetExpr(macro __entity__)));
                    var body = macro {
                        for (__entity__ in entities) {
                            f($a{ funcCallArgs });
                        }
                    }
                    def.fields.push(ffun([APublic, AInline], 'iter', [arg('f', funcComplexType)], macro:Void, macro $body, Context.currentPos()));
                }

                // isMatched
                {
                    var checks = components.map(function(c) return getComponentContainerInfo(c.cls).getExistsExpr( macro id));
                    var cond = checks.slice(1).fold(function(check1, check2) return macro $check1 && $check2, checks[0]);
                    var body;
                    if (worlds != 0xffffffff) {
                        var worldVal : Expr = { expr : EConst(CInt('${worlds}')), pos: Context.currentPos()};
                        var entityWorld = macro ecs.Workflow.worlds(id);
                        body = macro return (($entityWorld & $worldVal) == 0) ? false : $cond;
                    } else {
                        body = macro return $cond;
                    }
                    def.fields.push(ffun([AOverride], 'isMatched', [arg('id', macro:Int)], macro:Bool, body, Context.currentPos()));
                }

                 // isMatchedByTypes
                 {
                    var classNames = components.map(function(c) return  {expr: EConst(CString(c.cls.typeFullName())),  pos:Context.currentPos()});       
                    var checks = classNames.map(function(c) return macro names.contains( $c ));
                    var cond = checks.slice(1).fold(function(check1, check2) return macro $check1 && $check2, checks[0]);
                    var body;
                    if (worlds != 0xffffffff) {
                        var worldVal : Expr = { expr : EConst(CInt('${worlds}')), pos: Context.currentPos()};
                        var entityWorld = macro world;
                        body = macro return (($entityWorld & $worldVal) == 0) ? false : $cond;
                    } else {
                        body = macro return $cond;
                    }
                    var show = macro trace("names " + names);
                    body = {expr :EBlock([ body]), pos: Context.currentPos()};
                    def.fields.push(ffun([ AOverride, APublic], 'isMatchedByTypes', [arg('world', macro:Int), arg('names', macro:Array<String>)], macro:Bool, body, Context.currentPos()));
                    var xx = ffun([ AOverride, APublic], 'isMatchedByTypes', [arg('world', macro:Int), arg('names', macro:Array<String>)], macro:Bool, body, Context.currentPos());

                    var pp = new Printer();
                    //trace('isMatchedByTypes : ${pp.printField(xx)}');
                }

                // toString
                {
                    var componentNames = components.map(function(c) return c.cls.typeValidShortName()).join(', ');
                    var body = macro return $v{ componentNames };
                    def.fields.push(ffun([AOverride, APublic], 'toString', null, macro:String, body, Context.currentPos()));
                }

                Context.defineType(def);

                viewType = viewComplexType.toType();
            }

            // caching current build
            viewTypeCache.set(viewClsName, viewType);
            viewCache.set(viewClsName, { cls: viewType.toComplexType(), components: components });

            viewIds[viewClsName] = index;
            viewNames.push(viewClsName);
        }

        return viewType;
    }


}
#end