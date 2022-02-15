package ecs.core.macro;

#if macro
import ecs.core.macro.MetaTools;
import ecs.core.macro.MacroTools.*;
import ecs.core.macro.ViewBuilder;
import ecs.core.macro.ComponentBuilder.*;
import haxe.macro.Expr;
import haxe.macro.Printer;
import ecs.core.macro.ViewSpec;

using haxe.macro.ComplexTypeTools;
using haxe.macro.TypeTools;
using haxe.macro.Context;
using ecs.core.macro.MacroTools;
using tink.MacroApi;
using StringTools;
using Lambda;

typedef UpdateRec = {
	name:String,
	rawargs:Array<FunctionArg>,
	meta:haxe.ds.Map<String, Array<Array<Expr>>>,
	args:Array<Expr>,
	view:ViewRec,
	viewargs:Array<FunctionArg>,
	type:MetaFuncType
};

enum ParallelType {
	PUnknown;
	PFull;
	PHalf;
	PDouble;
	PCount(n:Int);
}

@:enum abstract MetaFuncType(Int) {
	var SINGLE_CALL = 1;
	var VIEW_ITER = 2;
	var ENTITY_ITER = 3;
}

class SystemBuilder {
	public static var systemIndex = -1;

	static var _printer = new Printer();

	static function metaFuncArgToComponentDef(a:FunctionArg) {
		return switch (a.type.followComplexType()) {
			case macro: StdTypes.Float
			:null;
			case macro: StdTypes.Int
			:null;
			case macro: ecs.Entity
			:null;
			default:
				var mm = a.meta.toMap();
				mm.exists(":local") ? null : {cls: a.type.followComplexType()};
		}
	}

	static function notNull<T>(e:Null<T>)
		return e != null;

	// @meta f(a:T1, b:T2, deltatime:Float) --> a, b, __dt__
	static function metaFuncArgToCallArg(a:FunctionArg) {
		return switch (a.type.followComplexType()) {
			case macro: StdTypes.Float
			:macro __dt__;
			case macro: StdTypes.Int
			:macro __entity__;
			case macro: ecs.Entity
			:macro __entity__;
			default: macro $i{a.name};
		}
	}

	static function metaFuncArgIsEntity(a:FunctionArg) {
		return switch (a.type.followComplexType()) {
			case macro: StdTypes.Int
			,
		macro:ecs.Entity:true;
		default:
			false;
	}
}

static function refComponentDefToFuncArg(cls:ComplexType, args:Array<FunctionArg>) {
	var copmonentClsName = cls.followName();
	var a = args.find(function(a) return a.type.followName() == copmonentClsName);
	if (a != null) {
		return arg(a.name, a.type);
	} else {
		return arg(cls.typeFullName().toLowerCase(), cls);
	}
}

static function procMetaFunc(field:Field):UpdateRec {
	// Context.warning('processing meta for ${field.name}', field.pos);
	return switch (field.kind) {
		case FFun(func): {
				// Context.warning('Found function meta for ${field.name}', field.pos);
				var funcName = field.name;
				var funcCallArgs = func.args.map(metaFuncArgToCallArg).filter(notNull);
				var components = func.args.map(metaFuncArgToComponentDef).filter(notNull);
				var worlds = metaFieldToWorlds(field);

				if (components.length > 0) {
					// Context.warning('Found components ${components.length}', field.pos);

					// view iterate

					var vi = ViewSpec.fromField(field, func);
					// Context.warning('View Spec from field ${vi.name}', field.pos);
					var vr = ViewBuilder.getViewRec(vi, field.pos);
					if (vr == null) {
						Context.warning('View Rec is null', field.pos);
						return null;
					}
					// Context.warning('View Rec from field ${vr.name}', field.pos);

					var viewArgs = [arg('__entity__', macro:ecs.Entity)].concat(vi.includes.map((x) -> refComponentDefToFuncArg(x.ct, func.args)));

					// Context.warning('View args from field ${viewArgs}', field.pos);
					{
						name: funcName,
						rawargs: func.args,
						meta: field.meta.toMap(),
						args: funcCallArgs,
						view: vr,
						viewargs: viewArgs,
						type: VIEW_ITER
					};
				} else {
					// Context.warning('No components', field.pos);
					if (func.args.exists(metaFuncArgIsEntity)) {
						// every entity iterate
						Context.warning("Are you sure you want to iterate over all the entities? If not, you should add some components or remove the Entity / Int argument",
							field.pos);

						{
							name: funcName,
							rawargs: func.args,
							meta: field.meta.toMap(),
							args: funcCallArgs,
							view: null,
							viewargs: null,
							type: ENTITY_ITER
						};
					} else {
						// single call
						{
							name: funcName,
							rawargs: func.args,
							meta: field.meta.toMap(),
							args: funcCallArgs,
							view: null,
							viewargs: null,
							type: SINGLE_CALL
						};
					}
				}
			}
		default:
			null;
	}
}

public static function build(debug:Bool = false) {
	var fields = Context.getBuildFields();
	var ct = Context.getLocalType().toComplexType();
	// trace('Building ${ct.toString()}');

	// define new() if not exists (just for comfort)
	if (!fields.exists(function(f) return f.name == 'new')) {
		fields.push(ffun([APublic], 'new', null, null, null, Context.currentPos()));
	}
	
	var index = ++systemIndex;

	// prevent wrong override
	for (field in fields) {
		switch (field.kind) {
			case FFun(func):
				switch (field.name) {
					case '__update__':
						Context.error('Do not override the `__update__` function! Use `@:update` meta instead! More info at README example', field.pos);
					case '__activate__':
						Context.error('Do not override the `__activate__` function! `onactivate` can be overridden instead!', field.pos);
					case '__deactivate__':
						Context.error('Do not override the `__deactivate__` function! `ondeactivate` can be overridden instead!', field.pos);
					default:
				}
			default:
		}
	}

	var definedViews = new Array<{view:ViewRec, varname:String}>();
	// find and init manually defined views
	fields.filter(MetaTools.notSkipped).iter(function(field) {
		switch (field.kind) {
			// defined var only
			case FVar(clsCT, _) if (clsCT != null):
				{
					switch (clsCT) {
						case TPath(path):
							if (path.name == "View") {
								var components = [];

								for (p in path.params) {
									switch (p) {
										case TPType(tpt): {
												components.push(tpt.followComplexType());
											}
										case TPExpr(e): throw "unsupported";
									}
								}

								var vs = ViewSpec.fromComponents(components);
								var vr = ViewBuilder.getViewRec(vs, field.pos);

								if (vr != null) {
									if (definedViews.find(function(v) return v.view.spec.name == vr.spec.name) == null) {
										// init
										var x = vr.spec.typePath().asTypeIdent(Context.currentPos());
										field.kind = FVar(vr.ct, macro $x.inst());
										definedViews.push({view: vr, varname: field.name});
									}
								} else {
									Context.warning('View Rec is null', field.pos);
								}
							}
						default:
					}
				}
			default:
		}
	});
	
	// find and init meta defined views
	fields.filter(MetaTools.notSkipped).filter((x) -> MetaTools.containsMeta(x, MetaTools.VIEW_FUNC_META)).iter(function(field) {
		switch (field.kind) {
			case FFun(func):
				{
					var components = func.args.map(metaFuncArgToComponentDef).filter(notNull);
					var worlds = metaFieldToWorlds(field);

					if (components != null && components.length > 0) {
						var vs = ViewSpec.fromField(field, func);
						if (vs != null) {
							
							var view = definedViews.find(function(v) return v.view.spec.name == vs.name);

							if (view == null || view.varname != vs.name.toLowerCase()) {
								var vr = ViewBuilder.getViewRec(vs, field.pos);

								if (vr != null) {
									definedViews.push({view: vr, varname: vs.name.toLowerCase()});
									var tp = vs.typePath().asTypeIdent(Context.currentPos());
									fields.push(fvar([], [], vs.name.toLowerCase(), vr.ct, macro $tp.inst(), Context.currentPos()));
								} else {
									Context.warning('Something in denmark2 ${view}', Context.currentPos());
								}
								
							} else {
								Context.warning('Something in denmark ${view}', Context.currentPos());
							}
						}
					}
				}
			default:
		}
	});

	var ufuncs = fields.filter(MetaTools.notSkipped)
		.filter((x) -> return MetaTools.containsMeta(x, MetaTools.UPD_META))
		.map(procMetaFunc)
		.filter(notNull);
	var afuncs = fields.filter(MetaTools.notSkipped)
		.filter(MetaTools.containsMeta.bind(_, MetaTools.AD_META))
		.map(procMetaFunc)
		.filter(notNull);
	var rfuncs = fields.filter(MetaTools.notSkipped)
		.filter(MetaTools.containsMeta.bind(_, MetaTools.RM_META))
		.map(procMetaFunc)
		.filter(notNull);
	var listeners = afuncs.concat(rfuncs);

	// define signal listener wrappers
	listeners.iter(function(f) {
		fields.push(fvar([], [], '__${f.name}_listener__', TFunction(f.viewargs.map(function(a) return a.type), macro:Void), null, Context.currentPos()));
	});

	var uexprs = []
	#if echoes_profiling.concat
	([macro var __timestamp__ = Date.now().getTime()])
	#end
	.concat(ufuncs.map(function(f) {
		return switch (f.type) {
			case SINGLE_CALL: {
					macro $i{f.name}($a{f.args});
				}
			case VIEW_ITER: {
					var maxParallel = PUnknown;
					if (f.meta.exists(":parallel")) {
						// TODO - Make it run in parallel :)
						var pm = f.meta[":parallel"][0]; // only pay attention to the first one
						if (pm.length > 0) {
							var pstr = pm[0].getStringValue();
							if (pstr != null) {
								maxParallel = switch (pstr.toUpperCase()) {
									case "FULL": PFull;
									case "HALF": PHalf;
									case "DOUBLE": PDouble;
									default: PUnknown;
								}
							}

							if (maxParallel == PUnknown) {
								maxParallel = PCount(pm[0].getNumericValue(1, pm[0].pos));
							}
						}
					}

					var callTypeMap = new Map<String, Expr>();
					var callNameMap = new Map<String, Expr>();
					callTypeMap["Float".asComplexType().followComplexType().typeFullName()] = macro __dt__;
					callTypeMap["ecs.Entity".asComplexType().followComplexType().typeFullName()] = macro __entity__;
					for (c in f.view.spec.includes) {
						var ct = c.ct.typeFullName();
						var info = getComponentContainerInfo(c.ct);
						callTypeMap[ct] = info.getGetExpr(macro __entity__, info.fullName + "_inst");
					}

					var cache = f.view.spec.includes.map(function(c) {
						var info = getComponentContainerInfo(c.ct);
						return info.getCacheExpr(info.fullName + "_inst");
					});

					for (a in f.rawargs) {
						var am = a.meta.toMap();
						var local = am.get(":local");
						if (local != null && local.length > 0 && local[0].length > 0) {
							callNameMap[a.name] = macro $i{"__l_" + a.name};
							cache.push(("__l_" + a.name).define(local[0][0]));
						}
					}

					var remappedArgs = f.rawargs.map((x) -> {
						var ctn = x.type.followComplexType().typeFullName();
						if (callNameMap.exists(x.name)) {
							return callNameMap[x.name];
						}
						if (callTypeMap.exists(ctn)) {
							return callTypeMap[ctn];
						}

						throw 'No experession for type ${ctn}';
					});

					var loop = macro for (__entity__ in $i{f.view.name}.entities) {
						$i{'${f.name}'}($a{remappedArgs});
					}

					cache.concat([loop]).toBlock();
				}
			case ENTITY_ITER: {
					macro for (__entity__ in ecs.Workflow.entities) {
						$i{f.name}($a{f.args});
					}
				}
		}
	}))
	#if echoes_profiling.concat ([macro this.__updateTime__ = Std.int(Date.now().getTime() - __timestamp__)]) #end;

	var aexpr = macro if (!activated)
		$b{
			[].concat([macro activated = true])
			.concat( // init signal listener wrappers
				listeners.map(function(f) {
					// DCE is eliminating this on 'full'
					var fwrapper = {
						expr: EFunction(FunctionKind.FAnonymous, {args: f.viewargs, ret: macro:Void, expr: macro $i{f.name}($a{f.args})}),
						pos: Context.currentPos()
					};
					return macro $i{'__${f.name}_listener__'} = $fwrapper;
				}))
			.concat( // activate views
				definedViews.map(function(v) {
					return macro $i{v.varname}.activate();
				}))
			.concat( // add added-listeners
				afuncs.map(function(f) {
					return macro $i{f.view.name}.onAdded.add($i{'__${f.name}_listener__'});
				}))
			.concat( // add removed-listeners
				rfuncs.map(function(f) {
					return macro $i{f.view.name}.onRemoved.add($i{'__${f.name}_listener__'});
				}))
			.concat( // call added-listeners
				afuncs.map(function(f) {
					return macro $i{f.view.name}.iter($i{'__${f.name}_listener__'});
				}))
			.concat([macro onactivate()])};

	var dexpr = macro if (activated)
		$b{
			[].concat([macro activated = false, macro ondeactivate()])
			.concat( // deactivate views
				definedViews.map(function(v) {
					return macro $i{v.varname}.deactivate();
				}))
			.concat( // remove added-listeners
				afuncs.map(function(f) {
					return macro $i{f.view.name}.onAdded.remove($i{'__${f.name}_listener__'});
				}))
			.concat( // remove removed-listeners
				rfuncs.map(function(f) {
					return macro $i{f.view.name}.onRemoved.remove($i{'__${f.name}_listener__'});
				}))
			.concat( // null signal wrappers
				listeners.map(function(f) {
					return macro $i{'__${f.name}_listener__'} = null;
				}))};

	if (uexprs.length > 0) {
		fields.push(ffun([APublic, AOverride], '__update__', [arg('__dt__', macro:Float)], null, macro $b{uexprs}, Context.currentPos()));
	}

	fields.push(ffun([APublic, AOverride], '__activate__', [], null, macro {$aexpr;}, Context.currentPos()));
	fields.push(ffun([APublic, AOverride], '__deactivate__', [], null, macro {$dexpr;}, Context.currentPos()));

	// toString
	fields.push(ffun([AOverride, APublic], 'toString', null, macro:String, macro return $v{ct.followName()}, Context.currentPos()));

	var clsType = Context.getLocalClass().get();

	if (debug || MetaTools.PRINT_META.exists(function(m) return clsType.meta.has(m))) {
		switch (Context.getLocalType().toComplexType()) {
			case TPath(p):
				{
					var td:TypeDefinition = {
						pack: p.pack,
						name: p.name,
						pos: clsType.pos,
						kind: TDClass(tpath("ecs", "System")),
						fields: fields
					}
					trace(new Printer().printTypeDefinition(td));
				}
			default:
				{
					Context.warning("Fail @print", clsType.pos);
				}
		}
	}
	#if false
	if (Context.getLocalType().toComplex().toString() == "Test.SystemY") {
		trace('Type: ${Context.getLocalType().toComplex().toString()}');
		for (f in fields) {
			trace(_printer.printField(f));
		}
	}
	#end

	return fields;
}
}
#end
