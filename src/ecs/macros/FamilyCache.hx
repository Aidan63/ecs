package ecs.macros;

import haxe.macro.Expr.ComplexType;
import haxe.ds.ReadOnlyArray;

using haxe.macro.ComplexTypeTools;

private final families = new Map<String, Int>();

private var familyIncrementer = 0;

function getFamily(_names : ReadOnlyArray<ComplexType>) {
    final buffer = new StringBuf();

    for (name in _names) {
        buffer.add(name.toString());
    }

    final concat = buffer.toString();

    trace(concat);

    return if (families.exists(concat)) {
        families.get(concat);
    } else {
        final id = familyIncrementer++;

        families.set(concat, id);

        id;
    }
}

macro function createFamilyVector() {
    return macro new haxe.ds.Vector($v{ familyIncrementer });
}