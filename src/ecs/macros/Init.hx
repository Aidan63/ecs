package ecs.macros;

import haxe.macro.Context;
import haxe.macro.Compiler;
import haxe.macro.Expr;
import ecs.macros.FamilyCache;
import ecs.macros.ResourceCache;
import ecs.macros.ComponentCache;

using haxe.macro.TypeTools;

var hasAddedEcsMeta = false;

macro function printFullReport()
{
    Context.onGenerate(_ -> {
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
                Sys.println('    hash : ${ component.hash }, id : ${ component.uID }, name : ${ component.name }, type : ${ component.type.toString() }');
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
    if (!Context.defined('ecs.static_loading'))
    {
        Context.onAfterTyping(_ -> {
            if (hasAddedEcsMeta)
            {
                return;
            }

            // Find the `ecs.core.FamilyManager` class and add meta data about all of the families.
            // These will then be read at start up and added to the family manager.
            final familyManager = Context.getType('ecs.core.FamilyManager').getClass();
            familyManager.meta.add('componentCount', [ macro $v{ getComponentCount() } ], familyManager.pos);
            familyManager.meta.add('resourceCount', [ macro $v { getResourceCount() } ], familyManager.pos);

            final families  = getFamilies();
            final familyIDs = new Array<Expr>();

            for (family in families)
            {
                final cmpIDs = [ for (c in family.components) macro $v{ c.uID } ];
                final resIDs = [ for (r in family.resources) macro $v{ r.uID } ];
                final obj    = EObjectDecl([ { field: 'components', expr: macro $a{ cmpIDs } }, { field: 'resources', expr: macro $a{ resIDs } } ]);

                familyIDs.push({ expr: obj, pos: familyManager.pos });
            }

            familyManager.meta.add('families', familyIDs, familyManager.pos);

            // Find the `ecs.core.ResourceManager` class and add meta data about the maximum number of resources.
            final resourceManager = Context.getType('ecs.core.ResourceManager').getClass();
            resourceManager.meta.add('resourceCount', [ macro $v { getResourceCount() } ], resourceManager.pos);

            // Find the `ecs.core.ComponentManager` class and add meta data about the maximum number of components.
            // The ID of all components is also added.
            final componentManager = Context.getType('ecs.core.ComponentManager').getClass();
            componentManager.meta.add('componentCount', [ macro $v{ getComponentCount() } ], componentManager.pos);
            componentManager.meta.add('components', [ for (c in getComponentMap()) macro $v{ c.id } ], componentManager.pos);

            hasAddedEcsMeta = true;
        });
    }

    return macro null;
}