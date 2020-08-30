import ecs.System;
import ecs.Universe;
import types.SomeType1;
import types.SomeType3;

using ecs.macros.ComponentsCache;

class Main {
	static function main() {
		final universe = new Universe();
		final system   = new SomeSystem1(universe.families, universe.components);
		final comp     = new SomeType3();
		final entity   = universe.entities.create();

		universe.components.setComponents(entity, SomeType2, comp, "spr_id", getComp());

		system.onAdded();
		system.update();
	}

	static function getComp() {
		return new SomeType4();
	}
}

class SomeSystem1 extends System {
	@:family var movable : { posTable : SomeType1, velTable : SomeType2 };

	@:family var drawable : { posTable : SomeType1, sprTable : String };

	@:family var other : { typTable : SomeType3 };

	override public function onAdded() {
		trace(posTable);
		trace(velTable);
	}

	override public function update() {
		for (e in other) {
			trace(e);
			trace(typTable.get(e));
		}
	}
}

@:keep class SomeType4 {
	public function new() {
		//
	}
}

@:keep class SomeType5 {
	public function new() {
		//
	}
}