package test;

import ecs.SystemList;
import ecs.Workflow;
import ecs.Entity;
import ecs.World;


// Can use vanilla classes with no annotation
class MediumComponent {
    public function new(i : Int) {}

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

// Change: There will be one of these PER WORLD
@:storage(SINGLETON)  // Simply specifies the storage capacity, does not affect the behaviour
class SingletonComponent {
  public function new(){}
}

// This 'marks' entities with this component type, but will providethe same single static instance value as a parameter in updates
// Specifies a type that is added as a type, not a value
@:storage(TAG) // Uses very little memory and is fast to look up (Bitfield). Can specify the max number of tags using -D ecs_max_tags=64
class TagYouIt {
   public function new() {} // requires a constructor with no parameters, public or private

  public var example = "it";
}

//@:shelvable // enabled by default ATM - Adds extra storage and behaviour to allow this component to be shelved.  Has a small performance impact on some actions.
class Position {
  public var x : Float;
  public var y : Float;
  public function new( x : Float, y : Float) {
    this.x = x;
    this.y = y;
  }
}

class Velocity {
    public var x : Float;
    public var y : Float;
    public function new( x : Float, y : Float) {
      this.x = x;
      this.y = y;
    }
  }

class Sprite {
    public var path : String;
    public var x : Float;
    public var y : Float;
    public function new(path : String) {
        this.path = path;
    }
}

class DisplayObjectContainer {
    public function addChild(spr : Sprite) {
        trace('Added sprite ${spr.path}');
    }
    public function removeChild(spr : Sprite) {
        trace('Removed sprite ${spr.path}');
    }
}

//
// Example program
//
class TestReadMe {
  final FIELDS = 1;
  final FOREST = 2;
  static final WORLDS_FIELDS = 0;
  static final WORLDS_FOREST = 1; // requires  -D ecs_max_worlds=2 or greater

  static function main() {
    ecsSetup(); // Called to initialize the system

    var worldFields = Workflow.world( WORLDS_FIELDS );
    var worldForest = Workflow.world( WORLDS_FOREST );

    var fieldPhysics = new SystemList()
      .add(new MovementSystem(worldFields))
      .add(new CollisionSystem(worldFields));

    worldFields.addSystem(fieldPhysics);
    worldFields.addSystem(new RenderSystem(worldFields)); // or just add systems directly

    worldForest.addSystem(new MovementSystem(worldForest)); // a little awkward at the moment, but once I get an answer to multiple templates I 
    worldForest.addSystem(new CollisionSystem(worldForest));

    var john = createRabbit(0, 0, 1, 1, 'John', worldFields);
    var jack = createRabbit(5, 5, 1, 1, 'Jack', worldForest);

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
    jack.unshelve(Position); // Re-attaches the corresponding shelved component.  
    trace(jack.exists(Position)); // true

    // THIS IS TWO FEATURES 
    // - the singleton() entity on workflow is a global entity across all worlds & systems.
    // - the SingletonComponent is a component where only one instance will ever exist and must only ever be added to one entity
    worldFields.self.add( new SingletonComponent() ); // Only one can be added globally at any one time

    // also somewhere should be World.update call on every tick
    worldFields.update(1.0);
    worldForest.update(1.0);
  }

  static function createTree(x:Float, y:Float, world:World) {
    return world.newEntity() 
      .add(new Position(x, y))
      .add(new Sprite('assets/tree.png'))
      .add(new MediumComponent(1))
      .add(new HeavyComponent());
  }
  static function createRabbit(x:Float, y:Float, vx:Float, vy:Float, name:Name, world:World) {
    var pos = new Position(x, y);
    var vel = new Velocity(vx, vy);
    var spr = new Sprite('assets/rabbit.png');
    return world.newEntity().add(pos, vel, spr, name, SmallComponent.rent()); // rabbits can be in world specified
  }
}


class MovementSystem extends ecs.System {
  // @update-functions will be called for every entity that contains all the defined components;
  // All args are interpreted as components, except Float (reserved for delta time) and Int/Entity;
  @:update function updateBody(pos:Position, vel:Velocity, dt:Float, entity:Entity) {
    pos.x += vel.x * dt;
    pos.y += vel.y * dt;
  }


  //Can narrow the scope of the update to only entities that are present in a world set
  @update function inForest(name:Name) {
    trace('${name} is in the forest'); // Will display Jack
  }

  //Can narrow the scope of the update to only entities that have the tag TagYouIt
  @update function isIt(name:Name, tag:TagYouIt) {
    trace('${name} is ${tag.example}'); // Will display Jack is it
  }

  // Worlds can be strings or constant string expressions if using compiler only @:
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

class CollisionSystem extends ecs.System {
  @:update function resolveCollision(pos:Position, entity:Entity) {
    // some collision logic
  }
}


class NamePrinter extends ecs.System {
  // All of necessary for meta-functions views will be defined and initialized under the hood, 
  // but it is also possible to define the View manually (initialization is still not required) 
  // for additional features such as counting and sorting entities;
  // Note: Does not support @:worlds 
  var named:View<Name>;

  @:update function sortAndPrint() {
    for (e in named.entities) {
      trace(e.get(Name));
    }
  }
}

class RenderSystem extends ecs.System {
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

