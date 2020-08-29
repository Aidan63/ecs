import ecs.Entity;
import ecs.System;
import ecs.Universe;
import ecs.macros.ComponentsCache;

class Main {
	static function main() {
		final universe = new Universe();
		final system   = new SomeSystem1();
		final comp     = new SomeType3();

		setComponents(universe.components, new Entity(0), new SomeType1(), SomeType2, comp, comp.inner, getComp());
	}

	static function getComp() {
		return new SomeType4();
	}
}

class SomeSystem1 extends System {
	@:family var movable : { posTable : SomeType1, velTable : SomeType2 };

	@:family var drawable : { posTable : SomeType1, sprTable : Int };

	@:family var other : { typTable : SomeType3 };

	public function new() {
		onAdded();
	}

	override public function onAdded() {
		trace(posTable);
		trace(velTable);
	}
}

@:keep class SomeType1 {
	public function new() {
		//
	}
}

@:keep class SomeType2 {
	public function new() {
		//
	}
}

@:keep class SomeType3 {
	public final inner : SomeType5;

	public function new() {
		inner = new SomeType5();
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