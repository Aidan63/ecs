package ecs;

import ecs.ds.Signal;
import ecs.ds.SparseSet;
import bits.Bits;

class Family
{
    public final id : Int;

    public final componentsMask : Bits;

    public final resourcesMask : Bits;

    public final onEntityAdded : Signal<Entity>;

    public final onEntityRemoved : Signal<Entity>;

    final entities : SparseSet;

    var active : Bool;

    public function new(_id, _cmpMask, _resMask, _size)
    {
        id              = _id;
        componentsMask  = _cmpMask;
        resourcesMask   = _resMask;
        onEntityAdded   = new Signal();
        onEntityRemoved = new Signal();
        entities        = new SparseSet(_size);
        active          = if (resourcesMask.isEmpty()) true else false;
    }

    public function add(_entity)
    {
        if (!entities.has(_entity))
        {
            entities.insert(_entity);

            if (isActive())
            {
                onEntityAdded.notify(_entity);
            }
        }
    }

    public function remove(_entity)
    {
        if (entities.has(_entity))
        {
            entities.remove(_entity);
            
            if (isActive())
            {
                onEntityRemoved.notify(_entity);
            }
        }
    }

    public function has(_entity)
    {
        return entities.has(_entity);
    }

    public function activate()
    {
        if (!active)
        {
            active = true;

            for (i in 0...entities.size())
            {
                onEntityAdded.notify(entities.getDense(i));
            }
        }
    }

    public function deactivate()
    {
        if (active)
        {
            for (i in 0...entities.size())
            {
                onEntityRemoved.notify(entities.getDense(i));
            }

            active = false;
        }
    }

    public function isActive()
    {
        return active;
    }

    public function iterator()
    {
        return new FamilyIterator(entities, isActive());
    }
}

private class FamilyIterator
{
    final set : SparseSet;

    final active : Bool;

    var idx : Int;

    public function new(_set, _active)
    {
        set    = _set;
        active = _active;
        idx    = 0;
    }

    public function hasNext()
    {
        return active && idx < set.size();
    }

    public function next()
    {
        return set.getDense(idx++);
    }
}