package ecs.macros;

import haxe.macro.Context;
import haxe.macro.Compiler;
import haxe.macro.Expr;
import ecs.macros.FamilyCache;
import ecs.macros.ResourceCache;
import ecs.macros.ComponentCache;

using haxe.macro.TypeTools;

macro function printFullReport()
{
    Context.onAfterGenerate(() -> {
        Sys.println('${ getComponentCount() } components registered');
        for (hash => data in getComponentMap())
        {
            Sys.println('  hash : $hash, id : ${ data.id }, type : ${ data.type.toString() }');
        }

        Sys.println('${ getResourceCount() } resources registered');
        for (type => id in getResourceMap())
        {
            Sys.println('  id : $id, type : ${ type.toString() }');
        }

        Sys.println('${ getFamilyCount() } families defined');
        for (idx => definition in getFamilies())
        {
            Sys.println('  id : $idx name : ${ definition.name }');
            Sys.println('  components');
            for (component in definition.components)
            {
                Sys.println('    hash : ${ component.hash }, id : ${ component.uID }, name : "${ component.name }, type : ${ component.type.toString() }');
            }

            Sys.println('  resources');
            for (resource in definition.resources)
            {
                Sys.println('    hash : ${ resource.hash }, id : ${ resource.uID }, name : ${ resource.name }, type : ${ resource.type.toString() }');
            }
        }
    });

    return macro null;
}

macro function inject()
{
    Context.onAfterTyping(types -> {
        final componentClass = macro class InjectedComponentManager {
            final entities   : ecs.core.EntityManager;
            final components : haxe.ds.Vector<Any>;
            final flags      : haxe.ds.Vector<bits.Bits>;

            public function new(_entities) {
                entities   = _entities;
                components = new haxe.ds.Vector($v{ getComponentCount() });
                flags      = new haxe.ds.Vector(entities.capacity());

                $b{ [
                    for (key => value in getComponentMap()) {
                        final ct = value.type.toComplexType();

                        macro components.set($v{ value.id }, new ecs.Components<$ct>(entities.capacity()));
                    }
                ] }

                for (i in 0...flags.length) {
                    flags[i] = new bits.Bits();
                }
            }

            public function getTable(_compID : Int)
            {
                return components[_compID];
            }

            @:generic public function set<T>(_entity : ecs.Entity, _id : Int, _component : T)
            {
                (components[_id] : ecs.Components<T>).set(_entity, _component);

                flags[_entity.id()].set(_id);
            }

            public function remove(_entity : ecs.Entity, _id : Int)
            {
                flags[_entity.id()].unset(_id);
            }

            public function clear(_entity : ecs.Entity)
            {
                flags[_entity.id()].clear();
            }
        }

        trace(new haxe.macro.Printer().printTypeDefinition(componentClass));

        componentClass.pack = [ 'ecs', 'core' ];

        Context.defineModule('ecs.core', [ componentClass ]);
    });

    return macro null;
}