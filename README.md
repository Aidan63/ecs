# **ECS**

[![Build Status](https://dev.azure.com/aidanlee63/ecs/_apis/build/status/Aidan63.ecs?branchName=master)](https://dev.azure.com/aidanlee63/ecs/_build/latest?definitionId=1&branchName=master)
[![codecov](https://codecov.io/gh/Aidan63/ecs/branch/master/graph/badge.svg?token=JW7KTFU3M4)](https://codecov.io/gh/Aidan63/ecs)

Macro powered entity component system for haxe. Many of the existing ECS libraries were very verbose and / or required extending / implementing some type for all components. I wasn't a fan of this so made my own.

All components and families are resolved at compile time allowing entities and components to be stored in flat arrays. No dynamic lookup, reflection, or anything like that is used at runtime, so it should be reasonably performant.

Inspired / ideas stolen from [clay_ecs](https://github.com/RudenkoArts/clay_ecs/) and [baldrick](https://github.com/hamaluik/baldrick).

Requires Haxe 4.2 nightlies as well as the safety and bits library.

- [Quick Example](#--quick-example--)
- [Advance Usage](#--advance-usage--)
  + [Iterate](#--iterate--)
  + [Resources](#--resources--)
  + [Family Definition](#--family-definition--)
    - [FastFamily](#--fastfamily--)
    - [FullFamily](#--fullfamily--)
  + [Family Activation](#--family-activation--)
  + [OnAdded and OnRemoved](#--onadded-and-onremoved--)
  + [OnEntityAdded and OnEntityRemoved](#--onentityadded-and-onentityremoved--)
- [Implementation Details](#--implementation-details--)
- [Future Additions and Improvements](#future-additions-and-improvements)

## **Quick Example**

Components and resources can be plain old haxe classes as well as ints, floats, bools, and strings. No interface needs to be implemented or class extended.

```haxe
package components;

class Position
{
    public var x : Float;

    public var y : Float;

    public function new()
    {
        x = 0;
        y = 0;
    }
}

class Velocity
{
    public var x : Float;

    public var y : Float;

    public function new(_x, _y)
    {
        x = _x;
        y = _y;
    }
}
```

Families are groups of components we are interested in, as components are added and removed from entities the families keep track of which entities currently fit the request. Systems must extend `ecs.System` and the easiest way to define a family is to create a variable with the `@:fastFamily` meta, this should be an object declaration defining the component types you want on entities and the name you want them accessible by.

```haxe
package systems;

import ecs.System;
import ecs.macros.UniverseMacros;
import components.Components.Position;
import components.Components.Velocity;

class VelocitySystem extends System
{
    @:fastFamily var movables = { pos : Position, vel : Velocity };

    override function update(_dt : Float)
    {
        iterate(movables, {
            pos.x += vel.x * _dt;
            pos.y += vel.y * _dt;

            trace('${ pos.x },${ pos.y }');
        });
    }
}
```

The `iterate` macro function allows you to run a block of code for each entity in a specified family. Notice that `pos` and `vel` which were defined the the `movables` family are being used in the `iterate` function. When giving a name to a component in a family definition a variable of that name with that component for the current entity will be accessible in a iterate function for that family.

To bring everything together we need to create a universe object, this will hold all entities, components, resources, and systems. Currently when adding a system you need to pass it several objects from the universe its being added to, in the future this will be changed.

```haxe
import ecs.Universe;
import systems.VelocitySystem;
import components.Components.Position;
import components.Components.Velocity;

using ecs.macros.UniverseMacros;

function main()
{
    final universe = new Universe(1024);
    final object   = universe.createEntity();
    
    universe.setSystems(VelocitySystem); //setSystem is found by the static extension in `UniverseMacros`

    universe.setComponents(object,
        Position,
        new Velocity(1, 1));

    for (_ in 0...120)
    {
        universe.update(1 / 60);
    }
}
```

The function `setComponents` is a macro which eases the process of adding multiple components and notifying the required families about changes. If a component has a constructor with no parameters you can just enter its type and the new call will be generated for you. Constructors, fields, and function calls are also allowed in the macro. If you add a component which isn't used by any family the compiler will emit a warning and that expression will be skipped.

The universe can then be ticked forward by calling the `update`. Systems are currently iterated upon in the order they were added. See future additions and details at the bottom of this README for possible changes / improvements to this.

This example can be found in the `sample` directory of this repository, it can be ran with `haxe run.hxml`, the universe will be ticked forward 120 times and the velocity system will update the entities position and print out the result along the way.

## **Advance Usage**

### **Iterate**

The `iterate` macro is the main way to execute code with each entities components in a given family, it automates the process of getting the components using the names provided when defining the family. In situations where you don't actually care about the entity itself you can use the following syntax.

```haxe
iterate(someFamily, {
    // code here is ran for each entity found in `someFamily`.
});
```

Alternativly lambda function syntax can be used.

```haxe
iterate(someFamily, () -> {
    // code here is ran for each entity found in `someFamily`.
});
```

If you do need to access the entity whos components are currently being accessed then you can use lambda function syntax with a single parameter which will then be accessible in the block and contain the current entity.

```haxe
iterate(someFamily, entity -> {
    // `entity` is the entity which has the components currently being accessed.
});
```

:warning: While the last two of these iterate examples used lambda function syntax no function is actually generate or called! All `iterate` macro functions generate a for loop so passing a real function into iterate is not valid.

It is also valid to nest `iterate` calls, just make sure that families do not have any component name collisions.

In the below example both the `bullets` and `enemies` families request the `Position` and `BBox` component, but because we give them different names (`bulletPos` vs `enemyPos` and `bulletBox` vs `enemyBox`) we can safely nest iterations without name collisions.

```haxe
class BulletCollisionSystem extends System
{
    @:fastFamily bullets = { bulletPos : Position, bulletBox : BBox, bullet : Bullet };

    @:fastFamily enemies = { enemyPos : Position, enemyBox : BBox, enemy : Enemy };

    override function update(_dt : Float)
    {
        iterate(bullets, {
            iterate(enemies, {
                // check bounding box collision between enemies and bullets.
            });
        });
    }
} 
```

### **Resources**

Resources are components which are attached to the universe instead of entities. They can be required by families and are very useful for data which could be considered "singleton" in nature (e.g. current level data).

```haxe
import ecs.macros.UniverseMacros;

class MySystem extends System
{
    @:fullFamily var myFamily = {
        requires : { comp : SomeComp },
        resources : { myRes : MyResourceType }
    };

    override function update(_dt : Float)
    {
        setup(myFamily, {
            // myRes is avaialble in this block.

            iterate(myFamily, {
                // do stuff with the components and resources.
            });
        });
    }
}
```

Using the `fullFamily` meta instead of `fastFamily` allows us to define resources which are required for the family to run. In the same way that `iterate` automatically creates variables for components `setup` create variables for any resources in that family.

If the resources requested by a family are not currently all in the universe then the code block passed to `setup` will not be ran.

### **Family Definition**

#### **FastFamily**

The `fastFamily` meta provides an easy way to define a family which only requires components. Variables tagged with this meta must then be assigned an object or array declaration. If you are using object declaration local variable generation can be skipped on a per-component basis by using `_` as the name.

:information_source: `fastFamily` does not provide any runtime speed increases over `fullFamily`, the fast comes from the fact that its faster to type when your family only needs components.

```haxe
import ecs.macros.UniverseMacros;

class MySystem extends System
{
    @:fastFamily myFamily1 = { pos : Position, vel : Velocity, _ : Sprite };

    @:fastFamily myFamily2 = [ Position, Velocity ];

    override function update(_dt : Float)
    {
        iterate(myFamily1, {
            // `pos` and `vel` are two local variables accessible in this block.
            // No local variable for the `Sprite` component will be generated.
        });

        iterate(myFamily2, {
            // No local variables are generated when a family uses array declaration.
        });
    }
}
```

#### **FullFamily**

The `fullFamily` meta allows defining families which require both components and resources. Variables tagged with this meta must be an object declaration which has a `requires` and `resources` field. The `requires` field is for defining what components are needed and follows all the same rules outlined in the above `fastFamily` section.

```haxe
import ecs.macros.UniverseMacros;

class MySystem extends System
{
    @:fastFamily myFamily = {
        requires : { pos : Position, vel : Velocity, _ : Sprite },
        resources : { myRes : MyResource }
    };

    override function update(_dt : Float)
    {
        setup(myFamily, {
            // This block will only be executed if `MyResource` is attached to the universe.
            // a local variable `myRes` will also be accessible here.

            iterate(myFamily, {
                // `pos` and `vel` are two local variables accessible in this block.
                // No local variable for the `Sprite` component will be generated.
            });
        });
    }
}
```

### **Family Activation**

You may find yourself wanting to run pre and post iterate code for the family as a whole in the update function. The following shows an example of this.

```haxe
import ecs.macros.UniverseMacros;

class SpriteDrawerSystem extends System
{
    @:fullFamily var sprites = {
        requires : { pos : Position, origin : Origin, spr : Sprite },
        resources : { painter : Painter }
    }

    override function update(_dt : Float)
    {
        setup(sprites, {
            painter.begin();

            iterate(sprites, {
                painter.drawSprite(
                    spr.id,
                    pos.x,
                    pos.y,
                    origin.x,
                    origin.y);
            });

            painter.end();
        });
    }
}
```

The above is an example of what a drawing system might look like and how it would interface with some imaginary game engine. Here the `Painter` resource is some object from the game engine which allows efficient drawing through batching, but in order to do that you need to make a `begin` and `end` call.

The code within the `setup` block will only be ran if all the resources requested by the family we're setting up are currently attached to the systems universe. This macro also handles creating local variables with the names specified in the family definition so we can safely access our resources. We can also then `iterate` over that same family allowing us to run pre and post iterate code.

### **OnAdded and OnRemoved**

The `ecs.System` type contains `onAdded` and `onRemoved` functions which can be overridden to add custom code for when a system is added or removed from the universe. It is also perfectly save to access families, components, and resource from whithin these functions.

```haxe
class MySystem extends System
{
    @:fastFamily var myFamily = [ SomeComponent ];

    override function onAdded()
    {
        trace(myFamily.isActive());
    }

    override function onRemoved()
    {
        trace(myFamily.isActive());
    }
}
```

### **OnEntityAdded and OnEntityRemoved**

Families also expose two signals you can subscribe to for when entities are added and removed from the family.

```haxe
class MySystem extends System
{
    @:fastFamily var myFamily = [ SomeComponent ];

    override function onAdded()
    {
        myFamily.onEntityAdded.subscribe(added);
        myFamily.onEntityRemoved.subscribe(removed);
    }

    function added(_entity)
    {
        trace('${ _entity } was added to myFamily');
    }

    function removed(_entity)
    {
        trace('${ _entity } was removed from myFamily');
    }
}
```

All components and resources requested by a family are guarenteed to still be accessible from within `onEntityAdded` and `onEntityRemoved` subscribers.

:information_source: If a family has 10 entities in it and a resource it requires is removed from the universe all subscribers to that families `onEntityRemoved` signal will recieve 10 notifications, one for each entity being removed. In the same fashion when a resource is added any subscribers to a family which now has entities will recieve a notification for each entity added.

## **Implementation Details**

The `ecs.Entity` type is an abstract around an int, `-1` is a special reserved integer ID representing none / a null entity.

Each unique component and resource across the entire compiled project is given an ID by hashing its `ComplexType`, IDs start at 0 and increment each time a new component or resource is found. Components and resources both have their own ID lists.

For each component a `ecs.Components<T>` object is created at universe creation, these objects contain a `haxe.ds.Vector` to store the components, this vector is pre-allocated with enough space to store a component of its type for each entity.  
Since entities are just integer abstracts they are used to index into these vectors when fetching a component.  
The `ecs.ComponentManager` has a `haxe.ds.Vector` containing all of these `ecs.Components<T>` objects, indexing into this vector with the ID given to a component during compilation will get you the `ecs.Components<T>` object for that component type. It also stores a `haxe.ds.Vector` of bit flags, one for every possible entity in the universe. These bit flags track which components an entity currently has. When a component is added or removed from an entity the bits are changed accordingly, the unique ID for each component is also used to set, unset, and check these bits.

Resources are handled in a similar way, `ecs.ResourceManager` keeps a `haxe.ds.Vector` allocated to the number of unique resources found during family compilation. It also keeps a bit flag, but just the one as resources are not stored per entity, but per universe.

For each family defined a corresponding `ecs.Family` object is created. This object contains a sparse set which holds all entities currently in this family. It also contains a components and resource bit flag mask based on the components and resources requested, these masks are used for checking against the component masks in `ecs.ComponentManager` and resource mask in `ecs.ResourceManager` to see which entities fit the the family definition.

Currently even when a family doesn't have its required resources it keeps track of entities which fit the requested components in its sparse set, then, as and when resources are added and removed it notifies any subscribers whithout going through the expensive process or checking all entities to clear and repopulate the sparse set.

Systems have field variables injected into them based on all families defined, for each defined family in a system an `ecs.Family` variable is added which is assigned when the system is added to the universe. For each unique component in a system a variable of `ecs.Components<T>` is added for the component type, this is also assigned when the system is added to the universe. These `ecs.Components<T>` variables are named `table$t` where `$t` is the type name of that component. Below is an example system before and after macro code generation.

```haxe
class MySystem extends System
{
    @:fastFamily var myFamily = { pos : Position, vel : Velocity };

    @:fastFamily var justPos = { pos : Position };
}
```

```haxe

class MySystem extends System
{
    var myFamily : ecs.Family;
    var justPos : ecs.Family;

    var tablePosition : ecs.Components<Position>;
    var tableVelocity : ecs.Components<Velocity>;

    override function onAdded()
    {
        myFamily = families.get(0);
        justPos  = families.get(1);

        tablePosition = components.get(0);
        tableVelocity = components.get(1);
    }
}
```

Since this is all handled in macros the index / component ID is generated at compile time.

:information_source: If you override the `onAdded` function these `get` calls are guarenteed to be injected before any of your code so will be accessible from it.

When calling `iterate` it generates a for loop with local variables based on the defined components in that family. So a complete before and after of the `VelocitySystem` shown at the top of this README and in the sample would look like this.

```haxe
class VelocitySystem extends System
{
    @:fastFamily var movables = { pos : Position, vel : Velocity };

    override function update(_dt : Float)
    {
        iterate(movables, {
            pos.x += vel.x * _dt;
            pos.y += vel.y * _dt;

            trace('${ pos.x },${ pos.y }');
        });
    }
}
```

```haxe
class VelocitySystem extends System
{
    var movables : ecs.Family;

    var tablePosition : ecs.Components<Position>;
    var tableVelocity : ecs.Components<Velocity>;

    override function onUpdate()
    {
        movables = families.get(0);

        tablePosition = components.get(0);
        tableVelocity = components.get(1);
    }

    override function update(_dt : Float)
    {
        for (_tmpEnt in movables)
        {
            final pos = tablePosition.get(_tmpEnt);
            final vel = tableVelocity.get(_tmpEnt);

            pos.x += vel.x * _dt;
            pos.y += vel.y * _dt;

            trace('${ pos.x },${ pos.y }');
        }
    }
}
```

## Future Additions and Improvements

Need a better entity tracking / recycling setup, right now it will just fail when running out of entities.

Would also like a way to specify the update priority of a system, unsure if this should be able to be changed on the fly though.

I also really like the idea of phases from baldrick, an example of the api might be.

```haxe
final universe = new Universe(1024);

final simPhase = universe.createPhase();
final drawPhase = universe.createPhase();
final networkPhase = universe.createPhase();

simPhase.set(VelocitySystem, CollisionSystem);
drawPhase.set(WorldDrawerSystem, SpriteDrawerSystem, HudDrawerSystem);
networkPhase.set(SnapshotGeneratorSystem)
```

I've started but really need to build out a good test suite.
