package ecs.core;

class Parameters {
#if ecs_max_entities
static macro function getMaxEntitiesExpr() {
    var x= Std.parseInt(haxe.macro.Context.definedValue("ecs_max_entities"));
    return macro $v{x};
}

static inline function getMaxEntities() : Int {
    #if macro return 0; #else return getMaxEntitiesExpr(); #end
}

public static inline final MAX_ENTITIES = getMaxEntities();
#end


#if ecs_max_worlds
static macro function getMaxWorldsExpr() {
    var x= Std.parseInt(haxe.macro.Context.definedValue("ecs_max_worlds"));
    return macro $v{x};
}
static inline function getMaxWorlds() : Int {
    #if macro return 1; #else return getMaxWorldsExpr(); #end
}
public static inline final MAX_WORLDS = getMaxWorlds();
#else
public static inline final MAX_WORLDS = 1;
#end


#if ecs_world_bits
static macro function getWorldBitsExpr() {
    var x= Std.parseInt(haxe.macro.Context.definedValue("ecs_world_bits"));
    return macro $v{x};
}
static inline function getWorldBits() : Int {
    #if macro return 1; #else return getWorldBitsExpr(); #end
}
public static inline final WORLD_BITS = getWorldBits();
#else
public static inline final WORLD_BITS = 4;
#end

#if ecs_generation_bits
static macro function getGenerationBitsExpr() {
    var x= Std.parseInt(haxe.macro.Context.definedValue("ecs_generation_bits"));
    return macro $v{x};
}
static inline function getGenerationBits() : Int {
    #if macro return 1; #else return getGenerationBitsExpr(); #end
}
public static inline final GENERATION_BITS = getGenerationBits();
#else
public static inline final GENERATION_BITS = 4;
#end

#if ecs_max_flags
static macro function getMaxFlagsExpr() {
    var x= Std.parseInt(haxe.macro.Context.definedValue("ecs_max_flags"));

    return macro $v{x};
}
#end

static inline function getMaxFlags() {
    #if ecs_max_flags
    return getMaxFlagsExpr();
    #else
    return 32;
    #end
}

public static inline final MAX_TAGS = getMaxFlags();

}