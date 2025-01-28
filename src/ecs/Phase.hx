package ecs;

import haxe.Exception;
import haxe.ds.Vector;

class Phase
{
    public var enabled(default, null) : Bool;

    final systems : Vector<System>;

    final enabledSystems : Vector<Bool>;

    public final name : String;

    public function new(_enabled, _name, _systems, _enabledSystems)
    {
        enabled        = _enabled;
        name           = _name;
        systems        = _systems;
        enabledSystems = _enabledSystems;
    }

    public function update(_dt : Float)
    {
        if (!enabled)
        {
            return;
        }

        for (idx in 0...systems.length)
        {
            if (enabledSystems[idx])
            {
                systems[idx].update(_dt);
            }
        }
    }

    public function enable()
    {
        if (enabled)
        {
            return;
        }

        enabled = true;

        for (idx in 0...systems.length)
        {
            if (enabledSystems[idx])
            {
                systems[idx].onEnabled();
            }
        }
    }

    public function disable()
    {
        if (!enabled)
        {
            return;
        }

        enabled = false;

        for (idx in 0...systems.length)
        {
            if (enabledSystems[idx])
            {
                systems[idx].onDisabled();
            }
        }
    }

    @:generic public function enableSystem<T : System>(_type : Class<T>)
    {
        for (idx in 0...systems.length)
        {
            switch Std.downcast(systems[idx], _type)
            {
                case null:
                    continue;
                case system:
                    if (!enabledSystems[idx])
                    {
                        enabledSystems[idx] = true;

                        system.onEnabled();
                    }

                    return;
            }
        }

        throw new Exception('Unable to find system with the specified type');
    }

    @:generic public function disableSystem<T : System>(_type : Class<T>)
    {
        for (idx in 0...systems.length)
        {
            switch Std.downcast(systems[idx], _type)
            {
                case null:
                    continue;
                case system:
                    if (enabledSystems[idx])
                    {
                        enabledSystems[idx] = false;

                        system.onDisabled();
                    }

                    return;
            }
        }

        throw new Exception('Unable to find system with the specified type');
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
