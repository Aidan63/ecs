import ecs.Universe;
import systems.VelocitySystem;
import components.Components.Position;
import components.Components.Velocity;

using ecs.macros.UniverseMacros;

function main()
{
    final universe = new Universe(1024);
    final object   = universe.createEntity();
    
    universe.setSystems(VelocitySystem);
    universe.setComponents(object,
        Position,
        new Velocity(1, 1));

    for (_ in 0...120)
    {
        universe.systems.update(1 / 60);
    }
}