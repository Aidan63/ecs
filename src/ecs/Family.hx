package ecs;

import ecs.ds.SparseSet;
import bits.Bits;

class Family
{
    public final id : Int;

    public final componentsMask : Bits;

    public final resourcesMask : Bits;

    public var hasResources : Bool;

    final entities : SparseSet;

    public function new(_id, _cmpMask, _resMask)
    {
        id             = _id;
        componentsMask = _cmpMask;
        resourcesMask  = _resMask;
        hasResources   = if (resourcesMask.isEmpty()) true else false;
        entities       = new SparseSet(1024);
    }

    public function add(_entity)
    {
        entities.insert(_entity);
    }

    public function remove(_entity)
    {
        if (entities.has(_entity))
        {
            entities.remove(_entity);
        }
    }

    public function iterator()
    {
        return new FamilyIterator(entities, hasResources);
    }
}

private class FamilyIterator
{
    final set : SparseSet;

    final hasResources : Bool;

    var idx : Int;

    public function new(_set, _hasResources)
    {
        set          = _set;
        hasResources = _hasResources;
        idx          = 0;
    }

    public function hasNext()
    {
        return hasResources && idx < set.size();
    }

    public function next()
    {
        return set.getDense(idx++);
    }
}