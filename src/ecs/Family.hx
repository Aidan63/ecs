package ecs;

import bits.Bits;

class Family {
    public final id : Int;

    public final mask : Bits;

    final entities : Array<Entity>;

    public function new(_id, _mask) {
        id       = _id;
        mask     = _mask;
        entities = [];
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