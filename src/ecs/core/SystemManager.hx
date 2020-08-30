package ecs.core;

class SystemManager
{
    final components : ComponentManager;

    final families : FamilyManager;

    final active : Array<System>;

    public function new(_components, _families)
    {
        components = _components;
        families   = _families;
        active     = [];
    }

    public function add(_system : System)
    {
        active.push(_system);

        _system.onAdded();
    }

    public function update(_dt : Float)
    {
        for (system in active)
        {
            system.update(_dt);
        }
    }
}