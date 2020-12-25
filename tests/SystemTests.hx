import ecs.System;
import ecs.Universe;
import buddy.BuddySuite;
import ecs.macros.UniverseMacros;

using buddy.Should;
using ecs.macros.UniverseMacros;

class SystemTests extends BuddySuite
{
    public function new()
    {
        describe('System Tests', {
            describe('Regressions', {
                it('can use types with parameters in family definitions (#4)', {
                    final universe = new Universe(8);
                    final system   = new Issue4System(universe);
                    final expected = [ 'hello', 'world!' ];

                    universe.setSystems(system);
                    universe.setComponents(universe.createEntity(), [ 'hello', 'world!' ]);
                    universe.update(0);

                    system.data.should.containExactly(expected);
                });
            });
        });
    }
}

class Issue4System extends System
{
    @:fastFamily var family : { arr : Array<String> };

    public var data : Array<String>;

    override function update(_dt : Float)
    {
        iterate(family, {
            data = arr;
        });
    }
}