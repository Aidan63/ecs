package ecs.core;

import bits.Bits;
import haxe.ds.Vector;
import ecs.core.ComponentManager;

class FamilyManager
{
    final components : ComponentManager;

    final resources : ResourceManager;

    final families : Vector<Family>;

    public function new(_components, _resources, _size)
    {
        components = _components;
        resources  = _resources;

#if ecs.no_dyn_load
        families = ecs.macros.FamilyMacros.createFamilyVector();
        ecs.macros.FamilyMacros.setupFamilies(_size);
#else
        final meta           = haxe.rtti.Meta.getType(FamilyManager);
        final componentCount = meta.componentCount[0];
        final resourceCount  = meta.resourceCount[0];
        final allFamilies    = meta.families;
        
        families = new Vector(allFamilies.length);
        for (idx => family in allFamilies)
        {
            final cmpBits = new Bits();
            for (id in (family.components : Array<Int>))
            {
                cmpBits.set(id);
            }

            final resBits = new Bits();
            for (id in (family.resources : Array<Int>))
            {
                resBits.set(id);
            }

            families.set(idx, new Family(idx, cmpBits, resBits, _size));
        }
#end
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