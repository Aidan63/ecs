package ecs;

import ecs.ds.SparseSet;
import bits.Bits;

class Family
{
    public final id : Int;

    public final componentsMask : Bits;

    public final resourcesMask : Bits;

    final entities : SparseSet;

    public function new(_id, _cmpMask, _resMask)
    {
        id             = _id;
        componentsMask = _cmpMask;
        resourcesMask  = _resMask;
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
        return new FamilyIterator(entities);
    }
}

private class FamilyIterator
{
    final set : SparseSet;

    var idx : Int;

    public function new(_set)
    {
        set = _set;
        idx = 0;
    }

    public function hasNext()
    {
        return idx < set.size();
    }

    public function next()
    {
        return set.getDense(idx++);
    }
}