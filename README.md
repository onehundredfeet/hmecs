# hmecs (Haxe Macro Entity Component System)

Super lightweight Entity Component System framework for Haxe. 
Initially created to learn the power of macros. 
Focused to be simple and fast. 
Inspired by other haxe ECS frameworks, especially [EDGE](https://github.com/fponticelli/edge), [ECX](https://github.com/eliasku/ecx), [ESKIMO](https://github.com/PDeveloper/eskimo) and [Ash-Haxe](https://github.com/nadako/Ash-Haxe)
Extended to ecs - For performance improvements with struct only types

#### Acknowledgement by onehundredfeet
The original vision by [deepcake](https://github.com/deepcake/echo) was fantastic.  A macro driven ECS that was aimed at ease of use and performance. It had a few drawbacks I wanted to fix. 

## News
* Version 1.0 has been tagged.  
* Version 1.5 is coming
 - Working branch you can check out if you want
 - Breaking changes so be careful, entities can only belong to one world
 - (Done) Adds World objects that contain all the entities, systems, views and components for a world
 - Systems can't intermingle functions that apply to different worlds
 - (In Progress) Threading - Automatic threading with meta data

## Details

#### Challenges & Solutions
- It had a single world.  This is fine for most applications, but world partitions are sometimes necessary, especially in multiplayer games. (Solved with world flags feature)
- Allocated objects are manually pooled (Solved pool builder feature)
- Singleton components are not natively supported (Solved - Two different features)
- Ability to customize the storage type per component (Solved with @:storage feature)
- The performance at scale with lots of views makes adding and removing entities expensive. I plan on adding a factory system to speed the creation of entities. (1st pass done - Needs a revision)
- Struct types in Haxe are still allocated individually.  This makes streamlined processing difficult.  For large element counts, you are constantly cache missing.  
- Parallelism wasn't natively supported (First pass design complete)

### Supported Platforms
I have tested it on the following platforms

- Hashlink
- HXCPP
- JS
- HXCS - Warning - while it will not cause any obvious issues, using structs as components will potentially cause issues when trying to write to them as they are passed by value.

### Overview
 * Component is an instance of `T:Any` class. For each class `T` will be generated a global component container, where instance of `T` is a value and `Entity` is a key. 
 * `Entity` in that case is just an abstract over the `Int`, but with the ability to work with it as with a set of components like in other regular ECS frameworks. 
 * `View<T1, T2, TN>` is a collection of entities containing all components of the required types `T1, T2, TN`. Views are placed in Systems. 
 * `System` is a place for processing a certain set of data represented by views. 
 * To organize systems in phases can be used the `SystemList`. 
* `World` is a binding mechanism to allow views and systems to opperate on a subset of entities. A View (and a function in a System) can be associated with any number of Worlds.  When an Entity is created, it can be associated with any number of worlds.  At the moment, there is a maximum of 32 worlds.  Views will only include Entities that are associated with `ANY` of the worlds it can view. `NOTE: Worlds will be deprecated in favour of a new tag system`
* `Pool` a pool is a static container that can be used to speed up allocations using a rent/retire paradigm. Call a static rent to get a new instance and then retire on that instance to return it to the pool
* `Workflow` a global class used to access common features such as a singleton
* `Tag` is class with the @:storage(TAG) metadata that changes the behaviour from being specified as an instance to added as a type. A flag set keeps track of which entities are tagged, makeing storing many tags compact and fast.  When specified in a function, a single static instance of the class will be passed in to all calls, regardless of which entity is passed in.

## WARNING & INSTRUCTIONS
### Due to the heavily macro based approach of the system, there are some nuances that require some concessions.

1. To get all the features working, you will need to create a very lean, or even proxy, main file and use it as your entry point when compiling.

```haxe
import your.MainClass;

class ProxyMain {
  public static function main() {
    MainClass.main();
  }
}
```

2. You will need to add a call to initialize a variety of late binding mechanisms.

```haxe
import your.MainClass;

class ProxyMain {
  public static function main() {
    #if !macro
  	ecs.core.macro.Global.setup();  // macro to generate all the global calls and then hook them up at runtime
    #end
    MainClass.main();
  }
}
```

## Usage

### Component Storage
Each component type can have its own storage specification.  They are specified using the @:storage metadata on the component type.  You can use abstract types to wrap basic types to apply the metadata.

#### @:storage(FAST)
This is the default. It is an array the length of the total number of entities. Any entities with the component will have a non-zero allocated object in the array corresponding to the entity id.  Obviously this can waste a lot of memory if overused with a large number of entities.

#### @:storage(COMPACT)
This is the typical secondary value.  It specifies an IntMap to be used for the storage backend.  This will slightly increase the lookup time for get, but it will significantly reduce the amount of memory required.

#### @:storage(FLAG)
This is says that this type is a bit flag on the flags storage for the entity.  It takes a single bit per entity, much smaller than using an array.  It is slightly slower than the fast storage but not by much.

A side benefit is that a single instance of the tagged class is available in views that require this flag.

#### @:storage(SINGLETON)
There can only be one instance of this class and only one entity can own it. It is very limited, but very fast and uses little memory.

## Examples
```haxe
import ecs.SystemList;
import ecs.Workflow;
import ecs.Entity;


// Can use vanilla classes with no annotation
class MediumComponent {

}

// Can use vanilla abstracts to create a new component type
abstract AbstractComponent(MediumComponent) from MediumComponent to MediumComponent {

}

// Abstracts allow adding multiple components of the same underlying type to an entity 
// When using abstracts, be careful not to assume the underlaying type when adding 
@:forward
abstract Name(String) from String to String {
  public function new(name:String) this = name;
}

// 0 is assumed to mean 'empty' with Int abstracts. This may mean that with some cases it is not possible to use this approach.
abstract IDComponent(Int) from Int to Int {

}


@:storage(FAST) // Sepcifies the flavour of storage to use. FAST is the default. Uses more memory (Array Storage)
#if !macro @:build(ecs.core.macro.PoolBuilder.arrayPool()) #end // Implicitly adds rent & retire
//@:no_autoretire  // turns off automatically using the attached pool.  Unless this is added, the ECS will automatically return the object to the pool on being removed from the entity
class SmallComponent {
    var value = 0;

    function new(v : Int) {
      value = v;
    }

    @:pool_factory  // optional: overrides the default 'new', not necessary if you provide a parameterless constructor
    static function factory() : SmallComponent{
      return new SmallComponent(5);  
    }

    @:pool_retire  // optional: callback when retiring
    function onRetire() {

    }

    @:pool_retire  // optional: callback when retiring
    function onRetireE(e : Entity) {

    }


    // Implicitly added by the pool builder
    // static function rent() : SmallComponent 
    // function retire()

}

@:storage(COMPACT) // Uses less memory, but operations are slightly slower than fast (Map storage)
class HeavyComponent {
  public function new(){}

  @:ecs_remove
    function onRemove() {
      // Custom logic when a component is removed from an entity
    }
}

@:storage(SINGLETON)  // Simply specifies the storage capacity, does not affect the behaviour
class SingletonComponent {
  public function new(){}
}

// This 'marks' entities with this component type, but will providethe same single static instance value as a parameter in updates
// Specifies a type that is added as a type, not a value
@:storage(TAG) // Uses very little memory and is fast to look up (Bitfield)
class TagYouIt {
   TagYouIt() {} // requires a constructor with no parameters, public or private

  public var example = "it";
}

@:shelvable // PLANNED: Adds extra storage and behaviour to allow this component to be shelved.  Has a small performance impact on some actions.
// At the moment all components are shelvable.
class Position {
  public var x : Float;
  public var y : Float
  public function new( x : Float, y : Float) {
    this.x = x;
    this.y = y;
  }
}
//
// Example program
//
class Example {
  final FIELDS = 1;
  final FOREST = 2;
  final WORLDS_FIELDS = 1 << FIELDS;
  final WORLDS_FOREST = 1 << FOREST;

  static function main() {
    ecsSetup(); // Called to initialize the system

    var physics = new SystemList()
      .add(new Movement())
      .add(new CollisionResolver());

    Workflow.addSystem(physics);
    Workflow.addSystem(new Render()); // or just add systems directly

    var john = createRabbit(0, 0, 1, 1, 'John', WORLDS_FIELDS); // Only in the forest
    var jack = createRabbit(5, 5, 1, 1, 'Jack', WORLDS_FIELDS | WORLDS_FOREST); // In both worlds

    trace(jack.exists(Position)); // true
    trace(jack.get(Position).x); // 5
    jack.remove(Position); // oh no!
    jack.add(new Position(1, 1)); // okay
    jack.add(TagYouIt); // Jack is now tagged

    //
    // Shelving - Retaining reference to component, but officially detatching it from the entity
    // Can only hold ONE component at a time. 
    // Do not add a new component when there is already one shelved, the result is undefined.
    jack.shelve(Position); // Retains the component in storage, but removes it from being attached to the entity
    trace(jack.exists(Position)); // false
    jack.unshelve(Position): // Re-attaches the corresponding shelved component.  
    trace(jack.exists(Position)); // true

    // THIS IS TWO FEATURES 
    // - the singleton() entity on workflow is a global entity across all worlds & systems.
    // - the SingletonComponent is a component where only one instance will ever exist and must only ever be added to one entity
    Workflow.singleton().add( new SingletonComponent() ); // Only one can be added globally at any one time

    // also somewhere should be Workflow.update call on every tick
    Workflow.update(1.0);

    // You can manually call the systems lists if you wish to give more granular control.
    physics.forceUpdate(1.0);
  }

  static function createTree(x:Float, y:Float) {
    return new Entity()   // Trees are present in all worlds
      .add(new Position(x, y))
      .add(new Sprite('assets/tree.png'))
      .add(new MediumComponent(1))
      .add(new HeavyComponent());
  }
  static function createRabbit(x:Float, y:Float, vx:Float, vy:Float, name:Name, worlds:Int) {
    var pos = new Position(x, y);
    var vel = new Velocity(vx, vy);
    var spr = new Sprite('assets/rabbit.png');
    return new Entity(worlds).add(pos, vel, spr, name, SmallComponent.rent()); // rabbits can be in world specified
  }
}


class Movement extends ecs.System {
  // @update-functions will be called for every entity that contains all the defined components;
  // All args are interpreted as components, except Float (reserved for delta time) and Int/Entity;
  @:update function updateBody(pos:Position, vel:Velocity, dt:Float, entity:Entity) {
    pos.x += vel.x * dt;
    pos.y += vel.y * dt;
  }


  //Can narrow the scope of the update to only entities that are present in a world set
  @:worlds(WORLDS_FOREST) // These are bit flags.  The string is evaulate as an expression
  @update function inForest(name:Name) {
    trace('${name} is in the forest'); // Will display Jack
  }

  //Can narrow the scope of the update to only entities that have the tag TagYouIt
  @update function isIt(name:Name, tag:TagYouIt) {
    trace('${name} is ${tag.example}'); // Will display Jack is it
  }

  // Worlds can be strings or constant string expressions if using compiler only @:
  @:worlds(WORLDS_FIELDS) // These are bit flags.  The string is evaulate as an expression
  @:update function inFields(name:Name) {
    trace('${name} is in the fields'); // Will display Jack & John
  }

  // If @update-functions are defined without components, 
  // they are called only once per system's update;
  @:update function traceHello(dt:Float) {
    trace('Hello!');
  }
  // The execution order of @update-functions is the same as the definition order, 
  // so you can perform some preparations before or after iterating over entities;
  @:update function traceWorld() {
    trace('World!');
  }
}

class NamePrinter extends ecs.System {
  // All of necessary for meta-functions views will be defined and initialized under the hood, 
  // but it is also possible to define the View manually (initialization is still not required) 
  // for additional features such as counting and sorting entities;
  // Note: Does not support @:worlds 
  var named:View<Name>;

  @:update function sortAndPrint() {
    named.entities.sort((e1, e2) -> e1.get(Name) < e2.get(Name) ? -1 : 1);
    // using Lambda
    named.entities.iter(e -> trace(e.get(Name)));
  }
}

class Render extends ecs.System {
  var scene:DisplayObjectContainer;
  // There are @a, @u and @r shortcuts for @added, @update and @removed metas;
  // @added/@removed-functions are callbacks that are called when an entity is added/removed from the view;
  @:a function onEntityWithSpriteAndPositionAdded(spr:Sprite, pos:Position) {
    scene.addChild(spr);
  }
  // Even if callback was triggered by destroying the entity, 
  // @removed-function will be called before this happens, 
  // so access to the component will be still exists;
  @:r function onEntityWithSpriteAndPositionRemoved(spr:Sprite, pos:Position, e:Entity) {
    scene.removeChild(spr); // spr is still not a null
    trace('Oh My God! They removed ${ e.exists(Name) ? e.get(Name) : "Unknown Sprite" }!');
  }

  //PLANNED PARALLEL API NOT IMPLEMENTED YET
  @:parallel(FULL) // | @:p(FULL) - Valid values FULL | DOUBLE | HALF | # - Will create threads to call this function in parallel according to the number specifed in the parameters.  Will collect all threads before continuing.
  @:bucket(5) // | @:b(5) Specifies the parallel bucketing size valid values MAX | # - Max will take total / threads
  @:fork(SPRITE_UPDATE) // - Named synchronization - Will split off this update in another thread and continue processing other updates, can be combined with @:parallel
  @:u inline function updateSpritePosition(spr:Sprite, pos:Position) {
    spr.x = pos.x;
    spr.y = pos.y;
  }

  // PARALLEL API NOT IMPLEMENTED YET
  @:join(SPRITE_UPDATE) // - Will wait until the corresponding fork is completed before running this function
  @:u inline function afterSpritePositionsUpdated() {
    // rendering, etc
  }
}

function ecsSetup() {
	ecs.core.macro.Global.setup();  // macro to generate all the global calls and then hook them up at runtime
}


```

#### Also
There is also exists a few additional compiler flags:
 * `-D ecs_profiling` - collecting some more info in `Workflow.info()` method for debug purposes
 * `-D ecs_report` - traces a short report of built components and views

### Install
```haxelib git ecs https://github.com/onehundredfeet/ecs.git```
