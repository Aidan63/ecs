package ecs.macros;

import haxe.io.Path;
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Compiler;
#if macro
import ecs.macros.FamilyCache;
import ecs.macros.ResourceCache;
import ecs.macros.ComponentCache;
#end

using haxe.macro.TypeTools;

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
    // Whenever a system changes we need a way to invalidate the core ecs types.
    // The easiest way to do this is to register a dependency to a dummy file.
    // Whenever a systems auto macro is called it writes a random number to that file which should then invalidate the ecs types.
    final file = switch Context.definedValue('ecs.invalidationFile')
    {
        case null:
            final output           = Compiler.getOutput();
            final invalidationFile = '.ecs_invalidation';
            final invalidationPath = if ('' == Path.extension(output))
            {
                Path.join([ output, invalidationFile ]);
            }
            else
            {
                Path.join([ Path.directory(output), invalidationFile ]);
            }

            invalidationFile;
        case path:
            path;
    }

    if (Context.defined('ecs.noInvalidationFile'))
    {
        Utils.invalidationFile = null;

#if (debug && !ecs.no_debug_output)
        Sys.println('[ecs] Not using an invalidation file');
#end
    }
    else
    {
        Utils.invalidationFile = file;

        if (!sys.FileSystem.exists(Path.directory(file)))
        {
            sys.FileSystem.createDirectory(Path.directory(file));
        }

        Context.registerModuleDependency('ecs.Universe', Utils.invalidationFile);
        Context.registerModuleDependency('ecs.core.ComponentManager', Utils.invalidationFile);
        Context.registerModuleDependency('ecs.core.ResourceManager', Utils.invalidationFile);
        Context.registerModuleDependency('ecs.core.EntityManager', Utils.invalidationFile);
        Context.registerModuleDependency('ecs.core.FamilyManager', Utils.invalidationFile);
        
#if (debug && !ecs.no_debug_output)
        Sys.println('[ecs] Set invalidation file to $file');
#end
    }

    return macro null;
}