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
import ecs.core.macro.ViewSpec;

using ecs.core.macro.MacroTools;
using haxe.macro.ComplexTypeTools;
using haxe.macro.Context;
using Lambda;
using haxe.ds.ArraySort;
using tink.MacroApi;

typedef ViewRec = { name:String, spec:ViewSpec, ct:ComplexType };


class ViewBuilder {
	static var viewIndex = -1;
	static var viewTypeCache = new Map<String, haxe.macro.Type>();

	public static var viewIds = new Map<String, Int>();
	public static var viewNames = new Array<String>();

	public static var viewCache = new Map<String, ViewRec>();

    public static function getViewRec( vs : ViewSpec ): ViewRec  {
        if (vs == null) throw "null view spec";
        if (viewCache.exists(vs.name)){
            return viewCache.get( vs.name );
        }
        createViewType(vs);
        return viewCache.get( vs.name );
    }
	public static function getViewType(vi : ViewSpec):ComplexType {
		return createViewType(vi).toComplexType();
	}

	public static function getViewName(components:Array<{cls:ComplexType}>, excludes:Array<{cls:ComplexType}>, worlds:Int) {
		return 'ViewOf_'
			+ StringTools.hex(worlds, 8)
			+ "_"
			+ components.map(function(c) return c.cls).joinFullName('_')
			+ "_"
			+ excludes.map(function(c) return c.cls).joinFullName('_');
	}

	static var callbackEstablished = false;

	static function afterTypingCallback(m:Array<ModuleType>) {
		#if false
		//        trace('After typing callback : ${m.length}');

		trace('Total Views ${viewNames.length}');
		var p = new Printer();
		for (n in viewCache) {
			trace('View ${n.name} | ${n.spec.name}');
			var t = Context.getType(n.spec.name);
			
		}
		#end
	}

	public static function build() : haxe.macro.Type {
		
		if (!callbackEstablished) {
			Context.onAfterTyping(afterTypingCallback);
			callbackEstablished = true;
		}

		//var x = Context.getLocalType();

        
		// trace('Creating view for: ${x} -> ${x.getName()}');

//		var worlds:Ref<Int> = 0xffffffff;
//		var components = parseComponents(Context.getLocalType(), worlds);

        var vs = ViewSpec.fromViewType( Context.getLocalType() );
		
        if (viewCache.exists(vs.name)){
            try {
                var t = Context.resolveType(viewCache.get(vs.name).ct, Context.currentPos());
                return t;
            } catch(e) {
            }
        }

        return createViewType( vs );
}
    
    



	public static function createViewType(vi : ViewSpec) : haxe.macro.Type{
		try {
		var viewClsName = vi.name;
        var worlds = vi.worlds;
        var components = vi.includes;
		var viewType = viewTypeCache.get(viewClsName);

		if (viewType == null) {
			// first time call in current build

			var index = ++viewIndex;

			try
				viewType = Context.getType(viewClsName)
			catch (err) {
				// type was not cached in previous build

				var viewTypePath = tpath([], viewClsName, []);
				var viewComplexType = TPath(viewTypePath);

				// signals
				var signalTypeParamComplexType = TFunction([macro:ecs.Entity].concat(components.map(function(c) return c.ct)), macro:Void);
				var signalTypePath = tpath(['ecs', 'utils'], 'Signal', [TPType(signalTypeParamComplexType)]);

				// signal args for dispatch() call
				var signalArgs = [macro id].concat(components.map(function(c) return getLookup(c.ct, macro id)));

				// component related views
				var addViewToViewsOfComponent = components.map(function(c) {
					var viewsOfComponentName = getViewsOfComponent(c.ct).followName();
					return macro @:privateAccess $i{viewsOfComponentName}.inst().addRelatedView(this);
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
						$b{addViewToViewsOfComponent}
					}

					override function dispatchAddedCallback(id:Int) {
						onAdded.dispatch($a{signalArgs});
					}

					override function dispatchRemovedCallback(id:Int) {
						onRemoved.dispatch($a{signalArgs});
					}

					override function reset() {
						super.reset();
						onAdded.removeAll();
						onRemoved.removeAll();
					}
				}

				// var iteratorTypePath = getViewIterator(components).tp();
				// def.fields.push(ffun([], [APublic, AInline], 'iterator', null, null, macro return new $iteratorTypePath(this.echoes, this.entities.iterator()), Context.currentPos()));

				// iter
				{
					var funcComplexType = TFunction([macro:ecs.Entity].concat(components.map(function(c) return c.ct)), macro:Void);
					var funcCallArgs = [macro __entity__].concat(components.map(function(c) return getComponentContainerInfo(c.ct)
						.getGetExpr(macro __entity__)));
					var body = macro {
						for (__entity__ in entities) {
							f($a{funcCallArgs});
						}
					}
					def.fields.push(ffun([APublic, AInline], 'iter', [arg('f', funcComplexType)], macro:Void, macro $body, Context.currentPos()));
				}

				// isMatched
				{
					var checksIncludes = components.map(function(c) return getComponentContainerInfo(c.ct).getExistsExpr(macro id));
					var checksExcludes = vi.excludes.map(function(c) return macro !${getComponentContainerInfo(c.ct).getExistsExpr(macro id)});
					var totalChecks = checksIncludes.concat(checksExcludes);

					var cond = totalChecks.slice(1).fold(function(check1, check2) return macro $check1 && $check2, totalChecks[0]);
					var body;
					if (worlds != 0xffffffff) {
						var worldVal:Expr = {expr: EConst(CInt('${worlds}')), pos: Context.currentPos()};
						var entityWorld = macro ecs.Workflow.worlds(id);
						body = macro return (($entityWorld & $worldVal) == 0) ? false : $cond;
					} else {
						body = macro return $cond;
					}
					def.fields.push(ffun([AOverride], 'isMatched', [arg('id', macro:Int)], macro:Bool, body, Context.currentPos()));
				}

				// isMatchedByTypes
				{
					var checksIncludes = vi.includes.map(function(c) return macro names.contains(${c.name.toExpr()}));
                    var checksExcludes = vi.excludes.map(function(c) return macro !names.contains(${c.name.toExpr()}));
					var totalChecks = checksIncludes.concat(checksExcludes);

					var cond = totalChecks.slice(1).fold(function(check1, check2) return macro $check1 && $check2, totalChecks[0]);
					var body;
					if (worlds != 0xffffffff) {
						var worldVal:Expr = {expr: EConst(CInt('${worlds}')), pos: Context.currentPos()};
						var entityWorld = macro world;
						body = macro return (($entityWorld & $worldVal) == 0) ? false : $cond;
					} else {
						body = macro return $cond;
					}
					var show = macro trace("names " + names);
					body = {expr: EBlock([body]), pos: Context.currentPos()};
					def.fields.push(ffun([AOverride, APublic], 'isMatchedByTypes', [arg('world', macro:Int), arg('names', macro:Array<String>)], macro:Bool,
						body, Context.currentPos()));
					var xx = ffun([AOverride, APublic], 'isMatchedByTypes', [arg('world', macro:Int), arg('names', macro:Array<String>)], macro:Bool, body,
						Context.currentPos());

					var pp = new Printer();
					// trace('isMatchedByTypes : ${pp.printField(xx)}');
				}

				// toString
				{
					var componentNames = components.map(function(c) return c.ct.typeValidShortName()).join(', ');
					var body = macro return $v{componentNames};
					def.fields.push(ffun([AOverride, APublic], 'toString', null, macro:String, body, Context.currentPos()));
				}

				def.meta.push({name: ":ecs_view", pos: Context.currentPos()});
				Context.defineType(def);

				#if false
				trace('ViewType: ${def.name}');
				var p = new Printer();
				trace(p.printTypeDefinition(def));
				#end
				viewType = viewComplexType.toType().sure();

			}

			// caching current build
			viewTypeCache.set(viewClsName, viewType);
			viewCache.set(viewClsName, {name: vi.name.toLowerCase(), ct: viewType.toComplexType(), spec: vi});

			viewIds[viewClsName] = index;
			viewNames.push(viewClsName);
		}

		return viewType;
		}
		catch(e) {
			Context.reportError('Could not build view type ${vi.name}', Context.currentPos());
			return null;
		}
	}
}
#end
