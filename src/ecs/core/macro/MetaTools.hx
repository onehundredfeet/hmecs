package ecs.core.macro;

#if macro
import haxe.macro.Expr;
using Lambda;

final SKIP_META = ['skip'];
final PRINT_META = ['print'];
final AD_META = ['added', 'ad', 'a', ':added', ':ad', ':a'];
final RM_META = ['removed', 'rm', 'r', ':removed', ':rm', ':r'];
final UPD_META = ['update', 'up', 'u', ':update', ':up', ':u'];
final PARALLEL_META = [':parallel', 'parallel', 'p', ':p'];
final FORK_META = [':fork', 'fork', 'f', ':f'];
final JOIN_META = [':join', 'join', 'j', ":j"];
final VIEW_FUNC_META = UPD_META.concat(AD_META).concat(RM_META);

function matchField(metas:Array<String>, field:Field) {
	return field.meta.exists(function(me) {
		return metas.exists(function(name) return me.name == name);
	});
}

function containsMeta(field:Field, metas:Array<String>) {
	return field.meta.exists(function(me) {
		return metas.exists(function(name) return me.name == name);
	});
}

function notSkipped(field:Field) {
	return !MetaTools.containsMeta(field, MetaTools.SKIP_META);
}
#end
