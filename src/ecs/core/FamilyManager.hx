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

    public function tryActivate(_id : Int)
    {
        if (!families[_id].isActive() && resources.flags.areSet(families[_id].resourcesMask))
        {
            families[_id].activate();
        }
    }

    public function whenEntityDestroyed(_entity : Entity)
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
}