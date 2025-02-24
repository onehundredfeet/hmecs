package test;

import ecs.core.macro.Global;
import ecs.Workflow;
import ecs.View;
import ecs.Entity;
import test.TestComponents;
import test.TestWorlds;
import test.TestSystemY;
import test.TestSystemZ;
import test.TestSystemA;
import test.TestMacros;
import ecs.core.Parameters;

class Test {
	public static final TESTWORLD_A = 0;
	public static final TESTWORLD_B = 1;


	static function intToBinary(value:Int, bits:Int = 32):String {
        var result = "b";
        for (i in 0...bits) {
            // Extract the bit at position (bits - 1 - i)
            var bit = (value >>> (bits - 1 - i)) & 1;
            result += bit;
        }
        return result;
    }

	static function testPacking() {

		trace('PACKING WORLD: wb ${Parameters.WORLD_BITS}[${@:privateAccess Entity.WORLD_COUNT}] ws ${@:privateAccess Entity.WORLD_SHIFT} wrm ${intToBinary(@:privateAccess  Entity.WORLD_RIGHT_MASK)} wlm ${intToBinary(@:privateAccess Entity.WORLD_LEFT_MASK)}');
		trace('PACKING GENERATION: gb ${Parameters.GENERATION_BITS}[${@:privateAccess Entity.GENERATION_COUNT}] gs ${@:privateAccess Entity.GENERATION_SHIFT} grm ${intToBinary(@:privateAccess Entity.GENERATION_RIGHT_MASK)} glm ${intToBinary(@:privateAccess Entity.GENERATION_LEFT_MASK)}');
		trace('PACKING ID: ib ${@:privateAccess Entity.ID_BITS}[${@:privateAccess Entity.ID_COUNT}] ${intToBinary(@:privateAccess Entity.ID_MASK)} ');	
	}
	public static function main() {
		#if !macro ecsSetup(); #end

		testPacking();

		var worldA = Workflow.world(TESTWORLD_A);
		var worldB = Workflow.world(TESTWORLD_B);

		var ysystem = new TestSystemY(worldA);
		worldA.addSystem(ysystem);
		var waz : TestSystemZ = worldA.addSystem();
		worldA.addSystem(new TestSystemA(worldA));

		worldB.addSystem(new TestSystemY(worldB));
		worldB.addSystem(new TestSystemZ(worldB));
		worldB.addSystem(new TestSystemA(worldB));

		// var Inactive = 0;
		// var Active = 1;
		// var Cached = 2;
		// var Invalid = 3;

		// add many entities with a constant specifying the number of entities
		final n = 10000;
		var entities = new Array<Entity>();
		entities.resize(n);
		entities.resize(0);
		
		var t0 = haxe.Timer.stamp();
		for (i in 0...n) {
			var e = i % 2 == 0 ? worldA.newEntity() : worldB.newEntity();
			if (!e.valid) {
				trace('Failed to create entity');
			}
			entities.push(e);
			if (e.status() != Status.Active) {
				trace('Failed to create entity');
			}
		}

		var d0 = haxe.Timer.stamp() - t0;
		trace('Create ${n} entities in ${d0 * 1000} ms (${d0 * 1000 * 1000 / n} us per entity)');

		// remove every third one
		for (i in 0...n) {
			if (i % 3 == 0) {
				var e = entities[i];
				e.destroy();
				if (e.valid) {
					trace('Failed to destroy entity');
				}
				if (e.status() != Status.Cached) {
					trace('Failed to destroy entity');
				}
			}
		}

        // replace every third one with new entities
        for (i in 0...n) {
            if (i % 3 == 0) {
                var e = worldA.newEntity();
                entities[i] = e;
                if (e.status() != Status.Active) {
                    trace('Failed to create entity');
                }
            }
        }

		for (i in 0...n) {
			var e = entities[i];
			e.add(new F());
			if (i % 3 == 0) {
				e.add(new FS());
			}
			if (i % 5 == 0) {
				e.add(TagA);
			}
			if (i % 7 == 0) {
				e.add(TagB);
			}
		}

		var e = worldA.newEntity();
		var e2 = worldA.newEntity();
		//        e.add( new K() );
		e.add(new F());
		e.add(new FS());
		e.remove(K);

		var xxx = new X();
		var fff = new F();

		e.add(TagA);
		trace('e.TagA is ${e.get(TagA)} has ${e.has(TagA)}');
		e.add(TagB);
		trace('e.TagA is ${e.get(TagA)} has ${e.has(TagA)}');
		e.remove(TagA);
		trace('e.TagA is ${e.get(TagA)} has ${e.has(TagA)}');
		e.add(TagA);
		//        e.remove(TagB);
		e.add(xxx);
		e.add(new Y());
		e2.add(new Y());
		trace('y view count ${ysystem.ycount()}');
		trace('e.TagA is ${e.get(TagA)}');
		trace('e.TagA.test is ${e.get(TagA).test}');
		e.get(TagA).test = 1;
		trace('e.TagA.test is ${e.get(TagA).test}');
		e2.add(TagA);
		trace('e2.TagA.test is ${e.get(TagA).test}');

		trace('E has tag a ${e.has(TagA)} b ${e.has(TagB)} a.test is ${e.get(TagA).test}');
		trace('E has tag Y ${e.has(Y)}');
		trace('PRE SHELVE y view count ${ysystem.ycount()}');
		e.shelve(Y);
		trace('POST SHELVE y view count ${ysystem.ycount()}');
		trace('E has tag Y ${e.has(Y)}');
		e.unshelve(Y);
		trace('POST UNSHELVE y view count ${ysystem.ycount()}');
		trace('E has tag Y ${e.has(Y)}');

		worldA.update(1.);
		worldB.update(1.);
	}

	static function ecsSetup() {
		Global.setup();
	}
}
