import ecs.System;
import ecs.Universe;
import buddy.BuddySuite;

using buddy.Should;

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
                it('will properly initialise systems with multiple inheritence levels', {
                    final universe = new Universe(8);
                    final system   = new ExtendedSystem(universe);

                    universe.setSystems(system);
                    universe.setComponents(universe.createEntity(), [ 'hello', 'world!' ]);
                    universe.update(0);

                    system.adderInited.should.be(true);
                });
            });
            describe('fetching', {
                final universe = new Universe(8);
                final system   = new FetchingSystem(universe);
                final expected = 7;

                universe.setSystems(system);
                universe.setComponents(universe.createEntity(), expected);

                it('allows safe access to a specific entities components if its in a family', {
                    system.number.should.be(expected);
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

class ExtendedSystem extends Issue4System
{
    public var adderInited (default, null) = false;

    override function onAdded()
    {
        adderInited = true;
    }
}

class FetchingSystem extends System
{
    @:fastFamily var family : { num : Int };

    public var number (default, null) = -1;

    override function onAdded()
    {
        family.onEntityAdded.subscribe(e -> {
            fetch(family, e, {
                number = num;
            });
        });
    }
}