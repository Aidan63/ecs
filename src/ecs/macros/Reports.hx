package ecs.macros;

import ecs.macros.FamilyCache;
import ecs.macros.ResourceCache;
import ecs.macros.ComponentCache;

macro function printFullReport()
{
    final exprs = [ macro trace('ECS Compilation Report') ];

    exprs.push(macro trace($v{ getComponentCount() } + ' components registered'));

    for (type => id in getComponentMap())
    {
        exprs.push(macro trace('  ' + $v{ id } + ' : ' + $v{ type }));
    }

    exprs.push(macro trace($v{ getResourceCount() } + ' resources registered'));

    for (type => id in getResourceMap())
    {
        exprs.push(macro trace('  ' + $v{ id } + ' : ' + $v{ type }));
    }

    exprs.push(macro trace($v{ getFamilyCount() } + ' families defined'));

    for (idx => definition in getFamilies())
    {
        exprs.push(macro trace('  ' + $v{ idx } + ' : ' + $v{ definition.name }));
        exprs.push(macro trace('    components'));
        for (comp in definition.components)
        {
            exprs.push(macro trace('      ' + $v{ comp.uID } + ' : ' + $v{ comp.name } + ' : ' + $v{ comp.type }));
        }

        exprs.push(macro trace('    resources'));
        for (res in definition.resources)
        {
            exprs.push(macro trace('      ' + $v{ res.uID } + ' : ' + $v{ res.name }));
        }
    }

    return macro $b{ exprs };
}