package ecs;

import ecs.core.EntityManager;
import ecs.core.FamilyManager;
import ecs.core.ResourceManager;
import ecs.core.ComponentManager;

@:autoBuild(ecs.macros.SystemMacros.familyConstruction()) class System
{
	final families : FamilyManager;

	final entities : EntityManager;
	
	final components : ComponentManager;

	final resources : ResourceManager;

	public function new(_families, _entities, _components, _resources)
	{
		families   = _families;
		entities   = _entities;
		components = _components;
		resources  = _resources;
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