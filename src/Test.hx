import ecs.System;
import ecs.Universe;
import ecs.macros.Reports;
import types.SomeType1;
import types.SomeType3;
import ecs.macros.SystemMacros.iterate;

using ecs.macros.ResourceMacros;
using ecs.macros.ComponentMacros;

class Test
{
	static function main()
	{
		// printFullReport(trace);

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
	@:fastFamily var movable = { pos : SomeType1, vel : SomeType2 };

	@:fastFamily var drawable = { pos : SomeType1, spr : String };

	@:fullFamily var other = {
		requires : { typ : SomeType3 },
		resources : [ SomeType4, SomeType5 ]
	};

	override public function update(_dt : Float)
	{
		iterate(movable, {
			trace('movable');
			trace(pos);
			trace(vel);
		});

		iterate(drawable, () -> {
			trace('drawable');
			trace(pos);
			trace(spr);
		});

		iterate(other, e -> {
			trace(e);
			trace(typ);
			trace(resources.getByType(SomeType4));
			trace(resources.getByType(SomeType5));
		});
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