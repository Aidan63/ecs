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
        for (i in 0...families.length) {
			final family = families[i];
			final comps  = components.flags[_entity];

            if (comps.areSet(family.mask))
            {
                trace('$_entity added to family $i');
            }
		}
    }

    function onComponentsRemoved(_entity : Entity)
    {
        trace('components removed from $_entity');
    }
}