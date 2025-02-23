package ecs.core;

import ecs.World;

#if hl
typedef WorldVector = hl.NativeArray<World>;

@:generic
typedef GenericVector<T> = hl.NativeArray<T>;

#else
typedef WorldVector = haxe.ds.Vector<World>;

@:generic
typedef GenericVector<T> = haxe.ds.Vector<T>;

#end

#if ecs_max_entities
#if hl
@:generic
typedef EntityVector<T> = hl.NativeArray<T>;

#else
@:generic
typedef EntityVector<T> = haxe.ds.Vector<T>;


#end

#end
