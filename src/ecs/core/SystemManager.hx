package ecs.core;

class SystemManager
{
    final active : Array<System>;

    public function new()
    {
        active = [];
    }

    public function add(_system : System)
    {
        active.push(_system);

        _system.onAdded();
    }

    public function remove(_system : System)
    {
        _system.onRemoved();

        active.remove(_system);
    }

    public function update(_dt : Float)
    {
        for (system in active)
        {
            system.update(_dt);
        }
    }
}