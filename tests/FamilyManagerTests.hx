import ecs.System;
import ecs.Universe;
import ecs.macros.SystemMacros.iterate;
import buddy.BuddySuite;

using rx.Observable;
using ecs.macros.ResourceMacros;
using ecs.macros.ComponentMacros;
using buddy.Should;

class FamilyManagerTests extends BuddySuite
{
    public function new()
    {
        describe('FamilyManager Tests', {
            it('It will not iterate over a families entities if it does not have the requested resources', {
                final world  = new Universe(8);
                final system = new TestSystem(world.families, world.entities, world.components, world.resources);
                final comp   = new TestComponent1();

                world.systems.add(system);
                
                world.components.setComponents(world.entities.create(), comp);

                world.systems.update(1);
                comp.number.should.be(0);

                world.resources.setResources(TestResource1);

                world.systems.update(1);
                comp.number.should.be(0);

                world.resources.setResources(TestResource2);

                world.systems.update(1);
                comp.number.should.be(1);
            });

            it('will fire onEntityAdded events for each entity in a family when it gains all its required resources', {
                final world  = new Universe(8);
                final system = new TestSystem(world.families, world.entities, world.components, world.resources);

                world.systems.add(system);
                world.components.setComponents(world.entities.create(), TestComponent1);
                world.components.setComponents(world.entities.create(), TestComponent1);

                system.counter.should.be(0);

                world.resources.setResources(TestResource1);

                system.counter.should.be(0);

                world.resources.setResources(TestResource2);

                system.counter.should.be(2);
            });

            it('will fire onEntityRemoved events for each entity in a family when it loses a required resource', {
                final world  = new Universe(8);
                final system = new TestSystem(world.families, world.entities, world.components, world.resources);

                world.systems.add(system);
                world.resources.setResources(TestResource1, TestResource2);
                
                world.components.setComponents(world.entities.create(), TestComponent1);
                world.components.setComponents(world.entities.create(), TestComponent1);

                world.resources.removeResources(TestResource1);

                system.counter.should.be(0);
            });

            it('allows access to resources from onEntityAdded subscribers', {
                final world  = new Universe(8);
                final system = new TestResourceAccessSystem(world.families, world.entities, world.components, world.resources);

                world.systems.add(system);
                world.components.setComponents(world.entities.create(), TestComponent1);
                world.components.setComponents(world.entities.create(), TestComponent1);

                world.resources.setResources(TestResource1);

                system.counter.should.be(2);
            });

            it('allows access to resources from onEntityAdded subscribers', {
                final world  = new Universe(8);
                final system = new TestResourceAccessSystem(world.families, world.entities, world.components, world.resources);

                world.systems.add(system);
                world.components.setComponents(world.entities.create(), TestComponent1);
                world.components.setComponents(world.entities.create(), TestComponent1);

                world.resources.setResources(TestResource1);
                world.resources.removeResources(TestResource1);

                system.counter.should.be(0);
            });
        });
    }
}

class TestSystem extends System
{
    public var counter : Int;

    @:fullFamily var family = {
        requires  : { comp : TestComponent1 },
        resources : [ TestResource1, TestResource2 ]
    }

    override function onAdded()
    {
        counter = 0;
        family.onEntityAdded.subscribeFunction(_ -> counter++);
        family.onEntityRemoved.subscribeFunction(_ -> counter--);
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

    @:fullFamily var family = {
        requires  : { comp : TestComponent1 },
        resources : [ TestResource1 ]
    }

    override function onAdded()
    {
        family.onEntityAdded.subscribeFunction(entity -> {
            counter += resources.getByType(TestResource1).const;
        });
        family.onEntityRemoved.subscribeFunction(entity -> {
            counter -= resources.getByType(TestResource1).const;
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