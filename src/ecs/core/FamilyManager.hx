package ecs.core;

import haxe.ds.Vector;
import ecs.core.ComponentManager;
import ecs.macros.FamilyMacros;

class FamilyManager
{
    final components : ComponentManager;

    final resources : ResourceManager;

    final families : Vector<Family>;

    public function new(_components, _resources, _size)
    {
        components = _components;
        resources  = _resources;
        families   = createFamilyVector();

        setupFamilies(_size);
    }

    public function get(_index : Int)
    {
        return families[_index];
    }

    public function componentsAdded(_entity : Entity)
    {
        final compFlags = components.flags[_entity.id()];

        for (family in families)
        {
            if (compFlags.areSet(family.componentsMask))
            {
                family.add(_entity);
            }
		}
    }

    public function componentsRemoved(_entity : Entity)
    {
        final compFlags = components.flags[_entity.id()];

        for (family in families)
        {          
            if (!compFlags.areSet(family.componentsMask))
            {
                family.remove(_entity);
            }
        }
    }

    public function resourcesAdded()
    {
        for (family in families)
        {
            if (!family.isActive() && resources.flags.areSet(family.resourcesMask))
            {
                family.activate();
            }
        }
    }

    public function resourcesRemoved()
    {
        for (family in families)
        {
            if (family.isActive() && !resources.flags.areSet(family.resourcesMask))
            {
                family.deactivate();
            }
        }
    }
}