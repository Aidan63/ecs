package ecs;

import haxe.ds.Vector;

class Phase
{
    public final name : String;

    public final systems : Vector<System>;

    public function new(_name, _systems)
    {
        name    = _name;
        systems = _systems;
    }

    public function update(_dt : Float)
    {
        for (system in systems)
        {
            system.update(_dt);
        }
    }
}