package ecs.macros;

import haxe.macro.Expr;
#if macro
import ecs.macros.FamilyCache;
import ecs.macros.ResourceCache;
import ecs.macros.ComponentCache;
#end

using haxe.macro.TypeTools;

macro function printFullReport(_printer : Expr)
{
    final exprs = [ macro $e{ _printer }('ECS Compilation Report') ];

    exprs.push(macro $e{ _printer }($v{ getComponentCount() } + ' components registered'));
    for (hash => data in getComponentMap())
    {
        exprs.push(macro $e{ _printer }('  hash : ' + $v{ hash } + ', id : ' + $v{ data.id } + ', type : ' + $v{ data.type.toString() }));
    }

    exprs.push(macro $e{ _printer }($v{ getResourceCount() } + ' resources registered'));
    for (hash => id in getResourceMap())
    {
        exprs.push(macro $e{ _printer }('  hash : ' + $v{ hash } + ', id : ' + $v{ id }));
    }

    exprs.push(macro $e{ _printer }($v{ getFamilyCount() } + ' families defined'));

    for (idx => definition in getFamilies())
    {
        exprs.push(macro $e{ _printer }('  ' + $v{ idx } + ' : ' + $v{ definition.name }));
        exprs.push(macro $e{ _printer }('  components'));
        for (comp in definition.components)
        {
            exprs.push(macro $e{ _printer }('    hash : ' + $v{ comp.hash } + ', id : ' + $v{ comp.uID } + ', name : ' + $v{ comp.name } + ', type : ' + $v{ comp.type.toString() }));
        }

        exprs.push(macro $e{ _printer }('  resources'));
        for (res in definition.resources)
        {
            exprs.push(macro $e{ _printer }('    hash : ' + $v{ res.hash } + ', id : ' + $v{ res.uID } + ', name : ' + $v{ res.name } + ', type : ' + $v{ res.type.toString() }));
        }
    }

    return macro $b{ exprs };
}