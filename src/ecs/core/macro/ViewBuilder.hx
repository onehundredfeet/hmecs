package ecs.core.macro;

#if macro
import haxe.macro.Printer;
import ecs.core.macro.MacroTools.*;
import ecs.core.macro.ComponentBuilder.*;
import ecs.core.macro.ViewsOfComponentBuilder.*;
import haxe.macro.Expr;
import haxe.macro.Type.ModuleType;
import ecs.core.macro.ViewSpec;

using ecs.core.macro.MacroTools;
using haxe.macro.ComplexTypeTools;
using haxe.macro.Context;
using Lambda;
using haxe.ds.ArraySort;
using tink.MacroApi;
using haxe.macro.PositionTools;

typedef ViewRec = {name:String, spec:ViewSpec, ct:ComplexType};

class ViewBuilder {
	static var viewIndex = -1;


	public static function getViewRec(vs:ViewSpec, pos:Position):ViewRec {
		//Context.warning('getting view rec for ${vs.name}', pos);
		if (vs == null) {
			Context.error('View spec is null', pos);
			throw "null view spec";
		}
		createViewType(vs, pos);
		return {name: vs.name.toLowerCase(), ct: vs.typePath().asComplexType(), spec: vs};
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

	public static function build():haxe.macro.Type {
		if (!callbackEstablished) {
			Context.onAfterTyping(afterTypingCallback);
			callbackEstablished = true;
		}
		var t = Context.getLocalType().follow();
		var vs =  ViewSpec.fromViewType(t);

		return createViewType(vs, Context.currentPos());
	}

	public static function createViewType(vi:ViewSpec, pos:Position):haxe.macro.Type {
		try {

			var viewClsName = vi.name;
			var worlds = vi.worlds;
			var components = vi.includes;
			var ct = vi.typePath().asComplexType();
			//Context.warning('Looking up type for ${ct.toString()}', pos);
			var viewType = ct.toTypeOrNull(pos);

			if (viewType == null) {
				// first time call in current build
				var index = ++viewIndex;

				//Context.warning('uncached ${viewClsName}', pos);
				try {
					// type was not cached in previous build
					// trace('creating view type ${viewClsName}');

					var viewTypePath = tpath([], viewClsName, []);
					//var viewComplexType = TPath(viewTypePath);

					// signals
					var signalTypeParamComplexType = TFunction([macro:ecs.Entity].concat(components.map(function(c) return c.ct)), macro:Void);
					var signalTypePath = tpath(['ecs', 'utils'], 'Signal', [TPType(signalTypeParamComplexType)]);

					// signal args for dispatch() call
					var signalArgs = [macro id].concat(components.map(function(c) return getLookup(c.ct, macro id)));

					// component related views
					var addViewToViewsOfComponent = components.map(function(c) {
						var viewsOfComponentName = getViewsOfComponent(c.ct).toString();
						if (viewsOfComponentName == null) {
							Context.reportError('Couldn\'t get view of component ${viewsOfComponentName}', pos);
						} else {
							//Context.warning('viewsOfComponentName ${viewsOfComponentName}', pos);
						}
						var typeIdent = viewsOfComponentName.asTypeIdent(pos);
						return macro @:privateAccess $typeIdent.inst().addRelatedView(this);
					});

					// type def
					var def:TypeDefinition = macro class $viewClsName extends ecs.core.AbstractView {
						static var instance = new $viewTypePath();

						@:keep inline public static function inst():$ct {
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
						def.fields.push(ffun([AOverride, APublic], 'isMatchedByTypes', [arg('world', macro:Int), arg('names', macro:Array<String>)],
							macro:Bool, body, Context.currentPos()));
						var xx = ffun([AOverride, APublic], 'isMatchedByTypes', [arg('world', macro:Int), arg('names', macro:Array<String>)], macro:Bool,
							body, Context.currentPos());

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

					def.defineTypeSafe(ViewSpec.VIEW_NAMESPACE);

					#if false
					trace('ViewType: ${def.name}');
					var p = new Printer();
					trace(p.printTypeDefinition(def));
					#end
					viewType = ct.toTypeOrNull( pos );
					// trace('created view type ${viewClsName}!!');
				} catch (err) {
					Context.error('Compile error ${err}', pos);
				}

				// caching current build
			} else {
				//Context.warning('re-using cached type ${viewClsName}', pos);
			}
			return viewType;
		} catch (e) {
			Context.error('Could not build view type ${vi.name}', pos);
			throw 'Could not build view type ${vi.name}';
		}
	}
}
#end
