package ecs;

import haxe.Exception;
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

    @:generic public function getSystem<T : System>(_type : Class<T>)
    {
        for (system in systems)
        {
            switch Std.downcast(system, _type)
            {
                case null:
                    continue;
                case casted:
                    return casted;
            }
        }

        throw new Exception('Unable to find system with the specified type');
    }
}