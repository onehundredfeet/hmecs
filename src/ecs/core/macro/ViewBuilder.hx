package ecs.core.macro;

#if macro
import haxe.macro.Printer;
import ecs.core.macro.MacroTools.*;
import ecs.core.macro.ComponentBuilder.*;
import ecs.core.macro.ViewsOfComponentBuilder.*;
import haxe.macro.Expr;
import haxe.macro.Type.ModuleType;
import ecs.core.macro.ViewSpec;
import ecs.utils.Const;
import ecs.utils.Signal;

using ecs.core.macro.MacroTools;
using haxe.macro.ComplexTypeTools;
using haxe.macro.Context;
using Lambda;
using haxe.ds.ArraySort;
using tink.MacroApi;
using haxe.macro.PositionTools;

typedef ViewRec = {name:String, spec:ViewSpec, ct:ComplexType};

class ViewBuilder {
	@:persistent static var _views = new Map<String, ViewSpec>();
	@:persistent static var _typeDefs = new Map<String, TypeDefinition>();
	static var _callback = false;

	static var _resolving : String = null;

	/*
	public static function createAllViewType() {
		trace('building types');
		for(vsi in _views.keyValueIterator()) {
			try {
				var x = Context.getType(vsi.key);
			}
			catch(e:Dynamic) {
				trace('could not find type ${vsi.key}');
				if (Std.isOfType(e,String)) {
					var x = createViewTypeDef(vsi.value, Context.currentPos());
				}
			}
		}
	}
	

	static function generateViewTypes(name:String):TypeDefinition {

		return null;
		// createViewType(vs, pos);
		if (name.indexOf("ecs.view.") == 0) {

			if (_views.exists( name)) {
				var vi = _views.get(name);
				trace('Looking for type ${name}');

				var x = createViewTypeDef(vi, Context.currentPos());

				//Context.defineType(x);

				_typeDefs.set(name, x);
				return x;
			}
		}
		
		return null;
	}
*/
	public static function getViewRec(vs:ViewSpec, pos:Position):ViewRec {
		if (vs == null) {
			Context.error('View spec is null', pos);
			throw "null view spec";
		}

		if (_callback == false) {
			//Context.onTypeNotFound(generateViewTypes);

			_callback = true;
		}

		_views.set( vs.typePath(), vs );
		createViewType(vs, Context.currentPos());
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
		return null;
		if (!callbackEstablished) {
			Context.onAfterTyping(afterTypingCallback);
			callbackEstablished = true;
		}
		var pos = Context.currentPos();

		var t = Context.getLocalType().follow();
		var vs = ViewSpec.fromViewType(t, pos);

		return createViewType(vs, Context.currentPos());
	}


	public static function createViewTypeDef(vi:ViewSpec, pos:Position):TypeDefinition {
		if (vi == null) {
			Context.error("View spec can not be null", pos);
			return null;
		}
		var viewClsName = vi.name;
		var worlds = vi.worlds;
		var components = vi.includes;
		var ct = vi.typePath().asComplexType();

		// first time call in current build

		// Context.warning('uncached ${viewClsName}', pos);
		// type was not cached in previous build
		// trace('creating view type ${viewClsName}');

		var viewTypePath = tpath([], viewClsName, []);
		// var viewComplexType = TPath(viewTypePath);

		// signals
		var signalTypeParamComplexType = TFunction([macro:ecs.Entity].concat(components.map(function(c) return c.ct)), macro:Void);
		var signalTypePath = tpath(['ecs', 'utils'], 'Signal', [TPType(signalTypeParamComplexType)]);
    
		//trace( 'path ${signalTypePath}');

		// signal args for dispatch() call
		var signalArgs = [macro id].concat(components.map(function(c) return getLookup(c.ct, macro id, pos)));

		// component related views
		var addViewToViewsOfComponent = components.map(function(c) {
			var viewsOfComponentName = getViewsOfComponent(c.ct, pos).toString();
			if (viewsOfComponentName == null) {
				Context.error('Couldn\'t get view of component ${viewsOfComponentName}', pos);
			} else {
				// Context.warning('viewsOfComponentName ${viewsOfComponentName}', pos);
			}
			var typeIdent = viewsOfComponentName.asTypeIdent(pos);
			return macro @:privateAccess $typeIdent.inst().addRelatedView(this);
		});

		//Context.warning('Defining view type ${vi.typePath()}', pos);
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
			var funcCallArgs = [macro __entity__].concat(components.map(function(c) return getComponentContainerInfo(c.ct, pos).getGetExpr(macro __entity__, true)));
			var body = macro {
				for (__entity__ in entities) {
					f($a{funcCallArgs});
				}
			}
			def.fields.push(ffun([APublic, AInline], 'iter', [arg('f', funcComplexType)], macro:Void, macro $body, Context.currentPos()));
		}

		// isMatched
		{
			var checksIncludes = components.map(function(c) return getComponentContainerInfo(c.ct, pos).getExistsExpr(macro id));
			var checksExcludes = vi.excludes.map(function(c) return macro !${getComponentContainerInfo(c.ct, pos).getExistsExpr(macro id)});
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
			def.fields.push(ffun([AOverride, APublic], 'isMatchedByTypes', [arg('world', macro:Int), arg('names', macro:Array<String>)], macro:Bool, body,
				Context.currentPos()));
			var xx = ffun([AOverride, APublic], 'isMatchedByTypes', [arg('world', macro:Int), arg('names', macro:Array<String>)], macro:Bool, body,
				Context.currentPos());

			var pp = new Printer();
			// trace('isMatchedByTypes : ${pp.printField(xx)}');
		}

		// toString
		{
			var componentNames = components.map(function(c) return c.ct.typeValidShortName(pos)).join(', ');
			var body = macro return $v{componentNames};
			def.fields.push(ffun([AOverride, APublic], 'toString', null, macro:String, body, Context.currentPos()));
		}

		def.meta.push({name: ":ecs_view", pos: Context.currentPos()});
		def.pack = ViewSpec.VIEW_NAMESPACE.split(".");

		#if false
		trace('ViewType: ${def.name}');
		var p = new Printer();
		trace(p.printTypeDefinition(def));
		#end

		return def;
	}

	public static function createViewType(vi:ViewSpec, pos:Position):haxe.macro.Type {
		if (vi == null) {
			Context.error("View spec can not be null", pos);
			return null;
		}
		var viewClsName = vi.name;
		var worlds = vi.worlds;
		var components = vi.includes;
		var ct = vi.typePath().asComplexType();

		var viewType = ct.toTypeOrNull(pos); // This crushes the autocomplete

		if (viewType == null) {
			var def = createViewTypeDef(vi, pos);
			def.defineTypeSafe(ViewSpec.VIEW_NAMESPACE, Const.ROOT_MODULE);

			#if false
			trace('ViewType: ${def.name}');
			var p = new Printer();
			trace(p.printTypeDefinition(def));
			#end
			viewType = ct.toTypeOrNull(pos);
			// trace('created view type ${viewClsName}!!');

			// caching current build
		}

		return viewType;
	}
}
#end
