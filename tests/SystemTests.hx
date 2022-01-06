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
                    final universe = Universe.create({
                        entities : 8,
                        phases : [
                            {
                                name : 'phase',
                                systems : [ Issue4System ]
                            }
                        ]
                    });

                    final system   = universe.getPhase('phase').getSystem(Issue4System);
                    final expected = [ 'hello', 'world!' ];

                    universe.setComponents(universe.createEntity(), [ 'hello', 'world!' ]);
                    universe.update(0);

                    system.data.should.containExactly(expected);
                });
                it('will properly initialise systems with multiple inheritence levels', {
                    final universe = Universe.create({
                        entities : 8,
                        phases : [
                            {
                                name : 'phase',
                                systems : [ ExtendedSystem ]
                            }
                        ]
                    });

                    final system = universe.getPhase('phase').getSystem(ExtendedSystem);

                    universe.setComponents(universe.createEntity(), [ 'hello', 'world!' ]);
                    universe.update(0);

                    system.adderInited.should.be(true);
                });
            });
            describe('fetching', {
                final universe = Universe.create({
                    entities : 8,
                    phases : [
                        {
                            name : 'phase',
                            systems : [ FetchingSystem ]
                        }
                    ]
                });

                final system   = universe.getPhase('phase').getSystem(FetchingSystem);
                final expected = 7;

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