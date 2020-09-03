package ecs.core;

import haxe.ds.Vector;
import ecs.core.ComponentManager;
import ecs.macros.FamilyCache;

using rx.Observable;

class FamilyManager
{
    final components : ComponentManager;

    final families : Vector<Family>;

    public function new(_components)
    {
        components = _components;
        families   = createFamilyVector();

        setupFamilies();
        components.componentsAdded().subscribeFunction(onComponentsAdded);
        components.componentsRemoved().subscribeFunction(onComponentsRemoved);
    }

    public function get(_index : Int)
    {
        return families[_index];
    }

    function onComponentsAdded(_entity : Entity)
    {
        final compFlags = components.flags[_entity];

        for (family in families)
        {
            if (compFlags.areSet(family.componentsMask))
            {
                family.add(_entity);
            }
		}
    }

    function onComponentsRemoved(_entity : Entity)
    {
        final compFlags = components.flags[_entity];

        for (family in families)
        {          
            if (!compFlags.areSet(family.componentsMask))
            {
                family.remove(_entity);
            }
        }
    }
}