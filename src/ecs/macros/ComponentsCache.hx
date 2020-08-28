package ecs.macros;

import haxe.macro.Expr.ComplexType;

using haxe.macro.ComplexTypeTools;

private final components = new Map<String, Int>();

private var componentIncrementer = 0;

function getComponentID(_ct : ComplexType) {
    final name = _ct.toString();

    return if (components.exists(name)) {
        components.get(name);
    } else {
        final id = componentIncrementer++;

        components.set(name, id);

        id;
    }
}