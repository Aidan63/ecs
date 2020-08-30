package ecs;

import ecs.core.FamilyManager;
import ecs.core.ComponentManager;

@:autoBuild(ecs.macros.SystemMacros.familyConstruction()) class System
{
	final families : FamilyManager;
	
	final components : ComponentManager;

	public function new(_families, _components)
	{
		families   = _families;
		components = _components;
	}

	public function onAdded()
	{
		//
	}

	public function update(_dt : Float)
	{
		//
	}

	public function onRemoved()
	{
		//
	}
}