import ecs.System;
import ecs.Universe;
import types.SomeType1;
import types.SomeType3;

using ecs.macros.ComponentsCache;

class Test
{
	static function main()
	{
		final universe = new Universe();
		final comp     = new SomeType3();
		final entity   = universe.entities.create();

		universe.systems.add(new SomeSystem1(universe.families, universe.components));
		universe.components.setComponents(entity, SomeType2, comp, "spr_id");

		universe.systems.update(1 / 60);
	}

	static function getComp()
	{
		return new SomeType4();
	}
}

class SomeSystem1 extends System
{
	@:family var movable : { posTable : SomeType1, velTable : SomeType2, world : SomeType4 };

	@:family var drawable : { posTable : SomeType1, sprTable : String };

	@:family var other : { typTable : SomeType3 };

	override public function onAdded()
	{
		trace(posTable);
		trace(velTable);
	}

	override public function update(_dt : Float)
	{
		for (e in other)
		{
			trace(e);
			trace(typTable.get(e));
		}
	}
}

class SomeType4
{
	public function new()
	{
		//
	}
}

class SomeType5
{
	public function new()
	{
		//
	}
}