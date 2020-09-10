import ecs.System;
import ecs.Universe;
import types.SomeType1;
import types.SomeType3;

using ecs.macros.ComponentsCache;
using ecs.macros.ResourceCache;

class Test
{
	static function main()
	{
		final universe = new Universe();
		final comp     = new SomeType3();
		final entity   = universe.entities.create();

		universe.systems.add(new SomeSystem1(universe.families, universe.entities, universe.components, universe.resources));
		universe.components.setComponents(entity, SomeType2, comp, "spr_id");
		universe.resources.setResources(SomeType4, SomeType5);

		universe.systems.update(1 / 60);

		universe.components.removeComponents(entity, SomeType3);

		universe.resources.removeResources(SomeType4);

		universe.systems.update(1 / 60);

		trace('done');
	}

	static function getComp()
	{
		return new SomeType4();
	}
}

class SomeSystem1 extends System
{
	@:fastFamily var movable = { posTable : SomeType1, velTable : SomeType2 };

	// @:fastFamily var drawable = { posTable : SomeType1, sprTable : String };

	@:fullFamily var other = {
		requires : { typTable : SomeType3 },
		resources : [ SomeType4, SomeType5 ]
	};

	override public function update(_dt : Float)
	{
		for (e in other)
		{
			trace(e);
			trace(typTable.get(e));
			trace(resources.getByType(SomeType4));
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