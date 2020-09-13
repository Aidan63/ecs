package ecs.macros;

import haxe.macro.Expr;
import ecs.macros.FamilyCache;
import ecs.macros.ResourceCache;
import ecs.macros.ComponentCache;

macro function printFullReport(_printer : Expr)
{
    final exprs = [ macro $e{ _printer }('ECS Compilation Report') ];

    exprs.push(macro $e{ _printer }($v{ getComponentCount() } + ' components registered'));

    for (type => id in getComponentMap())
    {
        exprs.push(macro $e{ _printer }('  ' + $v{ id } + ' : ' + $v{ type }));
    }

    exprs.push(macro $e{ _printer }($v{ getResourceCount() } + ' resources registered'));

    for (type => id in getResourceMap())
    {
        exprs.push(macro $e{ _printer }('  ' + $v{ id } + ' : ' + $v{ type }));
    }

    exprs.push(macro $e{ _printer }($v{ getFamilyCount() } + ' families defined'));

    for (idx => definition in getFamilies())
    {
        exprs.push(macro $e{ _printer }('  ' + $v{ idx } + ' : ' + $v{ definition.name }));
        exprs.push(macro $e{ _printer }('    components'));
        for (comp in definition.components)
        {
            exprs.push(macro $e{ _printer }('      ' + $v{ comp.uID } + ' : ' + $v{ comp.name } + ' : ' + $v{ comp.type }));
        }

        exprs.push(macro $e{ _printer }('    resources'));
        for (res in definition.resources)
        {
            exprs.push(macro $e{ _printer }('      ' + $v{ res.uID } + ' : ' + $v{ res.type }));
        }
    }

    return macro $b{ exprs };
}