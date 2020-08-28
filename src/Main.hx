import ecs.System;

class Main {
	static function main() {
		new SomeSystem1();
	}
}

class SomeSystem1 extends System {
	@:family var movable : { posTable : SomeType1, velTable : SomeType2 };

	@:family var drawable : { posTable : SomeType1, sprTable : Int };

	public function new() {
		onAdded();
	}

	override public function onAdded() {
		trace(posTable);
		trace(velTable);
	}
}

@:keep class SomeType1 {}

@:keep class SomeType2 {}

@:keep class SomeType3 {}