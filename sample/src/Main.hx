import ecs.Universe;
import systems.VelocitySystem;
import components.Components.Position;
import components.Components.Velocity;

using ecs.macros.ComponentMacros;

function main()
{
    final universe = new Universe(1024);
    final object   = universe.entities.create();
    
    universe.systems.add(new VelocitySystem(
        universe.families,
        universe.entities,
        universe.components,
        universe.resources));

    universe.components.setComponents(object,
        Position,
        new Velocity(1, 1));

    for (_ in 0...120)
    {
        universe.systems.update(1 / 60);
    }
}