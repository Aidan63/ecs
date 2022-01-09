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
                it('will treat generic classes with different parameters as separate components', {
                    final universe = Universe.create({
                        entities : 8,
                        phases : [
                            {
                                name : 'phase',
                                systems : [ GenericClassParamsSystem ]
                            }
                        ]
                    });

                    final system = universe.getPhase('phase').getSystem(GenericClassParamsSystem);
                    final comp   = new MyGenericClass(7);

                    universe.setComponents(universe.createEntity(), new MyGenericClass('test'), comp);
                    universe.update(0);

                    system.gen1Value.should.be('test');
                    system.gen2Value.should.be(7);
                });
                it('supports typedefs as separate component types', {
                    final universe = Universe.create({
                        entities : 8,
                        phases : [
                            {
                                name : 'phase',
                                systems : [ MovementSystem ]
                            }
                        ]
                    });

                    final system = universe.getPhase('phase').getSystem(MovementSystem);

                    universe.setComponents(universe.createEntity(), new Position(2, 4), new Velocity(7, 10));
                    universe.update(0);

                    system.posX.should.be(2);
                    system.posY.should.be(4);

                    system.velX.should.be(7);
                    system.velY.should.be(10);
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
            describe('constructors', {
                it('can inject family and table setup code into custom empty constructors', {
                    Universe.create({
                        entities : 8,
                        phases : [
                            {
                                name : 'phase',
                                systems : [ CustomConstructorFamily ]
                            }
                        ]
                    });
                });
                it('can inject family and table setup code into constructors with user code', {
                    final universe = Universe.create({
                        entities : 8,
                        phases : [
                            {
                                name : 'phase',
                                systems : [ CustomConstructorCodeFamily ]
                            }
                        ]
                    });

                    universe.getPhase('phase').getSystem(CustomConstructorCodeFamily).myRes.should.be(true);
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

class GenericClassParamsSystem extends System
{
    @:fastFamily var family : { gen1 : MyGenericClass<String>, gen2 : MyGenericClass<Int> };

    public var gen1Value = '';
    public var gen2Value = 0;

    override function update(_ : Float)
    {
        iterate(family, {
            gen1Value = gen1.v;
            gen2Value = gen2.v;
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

class MovementSystem extends System
{
    @:fastFamily var movables : { pos : Position, vel : Velocity };

    public var posX = 0.0;

    public var posY = 0.0;

    public var velX = 0.0;

    public var velY = 0.0;

    override function update(_ : Float)
    {
        iterate(movables, {
            posX = pos.x;
            posY = pos.y;

            velX = vel.x;
            velY = vel.y;
        });
    }
}

class CustomConstructorFamily extends FetchingSystem
{
    public function new(_universe)
    {
        super(_universe);
    }
}

class CustomConstructorCodeFamily extends FetchingSystem
{
    public final myRes : Bool;

    public function new(_universe)
    {
        super(_universe);

        myRes = family.isActive();
    }
}

class MyGenericClass<T>
{
    public var v : T;

    public function new(_v)
    {
        v = _v;
    }
}

class Point
{
    public var x : Float;

    public var y : Float;

    public function new(_x, _y)
    {
        x = _x;
        y = _y;
    }
}

typedef Position = Point;

typedef Velocity = Point;