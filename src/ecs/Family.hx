package ecs;

import rx.Subject;
import ecs.ds.SparseSet;
import bits.Bits;

class Family
{
    public final id : Int;

    public final componentsMask : Bits;

    public final resourcesMask : Bits;

    public final onEntityAdded : Subject<Entity>;

    public final onEntityRemoved : Subject<Entity>;

    final entities : SparseSet;

    var active : Bool;

    public function new(_id, _cmpMask, _resMask, _size)
    {
        id              = _id;
        componentsMask  = _cmpMask;
        resourcesMask   = _resMask;
        onEntityAdded   = new Subject();
        onEntityRemoved = new Subject();
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
                onEntityAdded.onNext(_entity);
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
                onEntityRemoved.onNext(_entity);
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
                onEntityAdded.onNext(entities.getDense(i));
            }
        }
    }

    public function deactivate()
    {
        if (active)
        {
            for (i in 0...entities.size())
            {
                onEntityRemoved.onNext(entities.getDense(i));
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