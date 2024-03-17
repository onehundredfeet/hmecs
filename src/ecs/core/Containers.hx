package ecs.core;


#if ecs_max_entities
#if hl
@:generic
typedef EntityVector<T> = hl.NativeArray<T>;
#else
@:generic
typedef EntityVector<T> = haxe.ds.Vector<T>;
#end
#end
