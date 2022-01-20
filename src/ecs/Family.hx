package ecs;

import ecs.ds.Unit;
import ecs.ds.Signal;
import ecs.ds.SparseSet;
import bits.Bits;

class Family
{
    public final id : Int;

    public final componentsMask : Bits;

    public final resourcesMask : Bits;

    public final onActivated : Signal<Unit>;

    public final onDeactivated : Signal<Unit>;

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
        onActivated     = new Signal();
        onDeactivated   = new Signal();
        entities        = new SparseSet(_size);
        active          = false;
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
            if (isActive())
            {
                onEntityRemoved.notify(_entity);
            }

            entities.remove(_entity);
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

            onActivated.notify(Unit.unit);

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

            onDeactivated.notify(Unit.unit);

            active = false;
        }
    }

    public function isActive()
    {
        return active;
    }

    public inline function iterator()
    {
        return new FamilyIterator(entities, isActive());
    }
}

private class FamilyIterator
{
    final set : SparseSet;

    final active : Bool;

    var idx : Int;

    public inline function new(_set, _active)
    {
        set    = _set;
        active = _active;
        idx    = _set.size() - 1;
    }

    public inline function hasNext()
    {
        return active && idx >= 0;
    }

    public inline function next()
    {
        return set.getDense(idx--);
    }
}