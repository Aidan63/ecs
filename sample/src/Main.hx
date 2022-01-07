import ecs.Universe;
import systems.*;
import components.*;

function main()
{
    final universe = Universe.create({
        name : 'universe',
        entities : 1024,
        phases : [
            {
                name : 'logic',
                systems : [ VelocitySystem ]
            }
        ]
    });

    universe.setComponents(
        universe.createEntity(),
        Position,
        new Velocity(1, 1));

    for (_ in 0...120)
    {
        universe.update(1 / 60);
    }
}