package ecs;

import bits.Bits;

class Family
{
    public final id : Int;

    public final componentsMask : Bits;

    public final resourcesMask : Bits;

    final entities : Array<Entity>;

    public function new(_id, _cmpMask, _resMask)
    {
        id             = _id;
        componentsMask = _cmpMask;
        resourcesMask  = _resMask;
        entities       = [];
    }

    public function add(_entity)
    {
        entities.push(_entity);
    }

    public function remove(_entity)
    {
        entities.remove(_entity);
    }

    public function iterator()
    {
        return entities.iterator();
    }
}