import ecs.System;
import ecs.Universe;
import buddy.BuddySuite;

using buddy.Should;

class FamilyManagerTests extends BuddySuite
{
    public function new()
    {
        describe('FamilyManager Tests', {
            it('It will not iterate over a families entities if it does not have the requested resources', {
                final comp   = new TestComponent1();
                final world  = Universe.create({
                    entities : 8,
                    phases : [
                        {
                            name : 'phase',
                            systems : [ TestSystem ]
                        }
                    ]
                });
                
                world.setComponents(world.createEntity(), comp);

                world.update(1);
                comp.number.should.be(0);

                world.setResources(TestResource1);

                world.update(1);
                comp.number.should.be(0);

                world.setResources(TestResource2);

                world.update(1);
                comp.number.should.be(1);
            });

            it('will fire onEntityAdded events for each entity in a family when it gains all its required resources', {
                final world  = Universe.create({
                    entities : 8,
                    phases : [
                        {
                            name : 'phase',
                            systems : [ TestSystem ]
                        }
                    ]
                });
                final system = world.getPhase('phase').getSystem(TestSystem);

                world.setComponents(world.createEntity(), TestComponent1);
                world.setComponents(world.createEntity(), TestComponent1);

                system.counter.should.be(0);

                world.setResources(TestResource1);

                system.counter.should.be(0);

                world.setResources(TestResource2);

                system.counter.should.be(2);
            });

            it('will fire onEntityRemoved events for each entity in a family when it loses a required resource', {
                final world  = Universe.create({
                    entities : 8,
                    phases : [
                        {
                            name : 'phase',
                            systems : [ TestSystem ]
                        }
                    ]
                });
                final system = world.getPhase('phase').getSystem(TestSystem);

                world.setResources(TestResource1, TestResource2);
                
                world.setComponents(world.createEntity(), TestComponent1);
                world.setComponents(world.createEntity(), TestComponent1);

                world.removeResources(TestResource1);

                system.counter.should.be(0);
            });

            it('allows access to resources from onEntityAdded subscribers', {
                final world  = Universe.create({
                    entities : 8,
                    phases : [
                        {
                            name : 'phase',
                            systems : [ TestResourceAccessSystem ]
                        }
                    ]
                });
                final system = world.getPhase('phase').getSystem(TestResourceAccessSystem);

                world.setComponents(world.createEntity(), TestComponent1);
                world.setComponents(world.createEntity(), TestComponent1);

                world.setResources(TestResource1);

                system.counter.should.be(2);
            });

            it('allows access to resources from onEntityAdded subscribers', {
                final world  = Universe.create({
                    entities : 8,
                    phases : [
                        {
                            name : 'phase',
                            systems : [ TestResourceAccessSystem ]
                        }
                    ]
                });
                final system = world.getPhase('phase').getSystem(TestResourceAccessSystem);

                world.setComponents(world.createEntity(), TestComponent1);
                world.setComponents(world.createEntity(), TestComponent1);

                world.setResources(TestResource1);
                world.removeResources(TestResource1);

                system.counter.should.be(0);
            });

            describe('Regressions', {
                it('will not deactivate all families when removing resources', {
                    final world  = Universe.create({
                        entities : 8,
                        phases : [
                            {
                                name : 'phase',
                                systems : [ TestMultiFamilyResourceAccessSystem ]
                            }
                        ]
                    });
                    final system = world.getPhase('phase').getSystem(TestMultiFamilyResourceAccessSystem);
    
                    world.setComponents(world.createEntity(), TestComponent1);
    
                    world.setResources(TestResource1);
                    system.counter1.should.be(1);
                    system.counter2.should.be(0);
    
                    world.setResources(TestResource2);
                    system.counter1.should.be(1);
                    system.counter2.should.be(1);
    
                    world.removeResources(TestResource1);
    
                    system.counter1.should.be(0);
                    system.counter2.should.be(1);
                }); 
            });
        });
    }
}

class TestSystem extends System
{
    public var counter : Int;

    @:fullFamily var family : {
        requires  : { comp : TestComponent1 },
        resources : { _ : TestResource1, _ : TestResource2 }
    }

    override function onAdded()
    {
        counter = 0;
        family.onEntityAdded.subscribe(_ -> counter++);
        family.onEntityRemoved.subscribe(_ -> counter--);
    }

    override public function update(_dt : Float)
    {
        iterate(family, {
            comp.number++;
        });
    }
}

class TestResourceAccessSystem extends System
{
    public var counter = 0;

    @:fullFamily var family : {
        requires  : { comp : TestComponent1 },
        resources : { res : TestResource1 }
    }

    override function onAdded()
    {
        family.onEntityAdded.subscribe(entity -> {
            setup(family, {
                counter += res.const;
            });
        });
        family.onEntityRemoved.subscribe(entity -> {
            setup(family, {
                counter -= res.const;
            });
        });
    }
}

class TestMultiFamilyResourceAccessSystem extends System
{
    public var counter1 = 0;

    public var counter2 = 0;

    @:fullFamily var family1 : {
        requires  : { comp : TestComponent1 },
        resources : { res : TestResource1 }
    }

    @:fullFamily var family2 : {
        requires  : { comp : TestComponent1 },
        resources : { res : TestResource2 }
    }

    override function onAdded()
    {
        family1.onEntityAdded.subscribe(entity -> {
            setup(family1, {
                counter1 += 1;
            });
        });
        family1.onEntityRemoved.subscribe(entity -> {
            setup(family1, {
                counter1 -= 1;
            });
        });

        family2.onEntityAdded.subscribe(entity -> {
            setup(family2, {
                counter2 += 1;
            });
        });
        family2.onEntityRemoved.subscribe(entity -> {
            setup(family2, {
                counter2 -= 1;
            });
        });
    }
}

@:keep class TestComponent1
{
    public var number : Int;

    public function new()
    {
        number = 0;
    }
}

@:keep class TestResource1
{
    public final const = 1;

    public function new() {}
}

@:keep class TestResource2
{
    public function new() {}
}