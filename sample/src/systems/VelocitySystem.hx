package systems;

import ecs.System;
import ecs.macros.UniverseMacros;
import components.Components.Position;
import components.Components.Velocity;

class VelocitySystem extends System
{
    @:fastFamily var movables : { pos : Position, vel : Velocity };

    override function update(_dt : Float)
    {
        iterate(movables, {
            pos.x += vel.x * _dt;
            pos.y += vel.y * _dt;

            trace('${ pos.x },${ pos.y }');
        });
    }
}