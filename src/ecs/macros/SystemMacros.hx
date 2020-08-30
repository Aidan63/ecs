package ecs.macros;

import haxe.ds.ReadOnlyArray;
import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.macro.Expr.Field;
import haxe.macro.Expr.Position;
import haxe.macro.Context;
import ecs.macros.FamilyCache;
import ecs.macros.ComponentsCache;

using Safety;
using haxe.macro.Tools;

typedef FamilyField = {
    final name : String;
    final type : ComplexType;
    var ?aType : Type;
}

typedef Family = {
    final name : String;
    final types : ReadOnlyArray<FamilyField>;
}

macro function familyConstruction() : Array<Field> {
    final fields = Context.getBuildFields();
    final output = new Array<Field>();

    final added    = getOrCreateOverrideFunction('onAdded', fields, Context.currentPos());
    final removed  = getOrCreateOverrideFunction('onRemoved', fields, Context.currentPos());
    final families = [];

    for (field in fields) {
        if (hasFamilyMeta(field)) {
            families.push(field);
        } else {
            output.push(field);
        }
    }

    for (family in extractFamilies(families)) {
        // For every field which was found in the family anon object create a Components<T> variable with that field name.
        // These allow you to fetch the component object for a given entity.
        for (i => field in family.types) {
            final ct = field.type;

            field.aType = field.type.toType();

            if (!Lambda.exists(output, f -> f.name == field.name)) {
                output.push({
                    name : field.name,
                    pos  : Context.currentPos(),
                    kind : FVar(macro : ecs.Components<$ct>),
                });

                insertExprIntoFunction(i, added, macro $i{ field.name } = cast components.getTable($v{ getComponentID(field.aType) }));
            }
        }

        // Create a family field for each family anon object.
        // This allows you to iterate over all entities with the components in that family.
        output.push({
            name : family.name,
            pos  : Context.currentPos(),
            kind : FVar(macro : ecs.Family)
        });

        insertExprIntoFunction(0, added, macro $i{ family.name } = families.get($v{ getFamilyID(family.types) }));
    }

    return output;
}

/**
 * Search the array of fields for one with a name that matches the provided string.
 * If no matching field is found a public override field with that name is appended to the field array.
 * @param _name Name to search for / create if not found.
 * @param _fields Existing fields.
 * @param _pos Context.currentPos()
 * @return Either the found field or the newly creatd one.
 */
function getOrCreateOverrideFunction(_name : String, _fields : Array<Field>, _pos : Position) : Field {
    for (field in _fields) {
        if (field.name == _name) {
            return field;
        }
    }

    _fields.push({
        name   : _name,
        access : [ APublic, AOverride ],
        pos    : _pos,
        kind   : FFun({ args : [], expr : macro {} })
    });

    return _fields[_fields.length - 1];
}

/**
 * Inserts an expression into a function block field.
 * @param _pos Position within the existing expression array to insert to.
 * @param _field Field to insert in, must be a FFun EBlock field.
 * @param _expr Expression to insert.
 */
function insertExprIntoFunction(_pos : Int, _field : Field, _expr : Expr) {
    switch _field.kind {
        case FFun(f):
            switch f.expr.expr {
                case EBlock(exprs): exprs.insert(_pos, _expr);
                case _:
            }
        case _:
    }
}

/**
 * Checks if the provided field contains the @:family meta.
 * @param _field Field to check.
 */
function hasFamilyMeta(_field : Field) {
    for (meta in _field.meta.or([])) {
        if (meta.name == ':family') {
            return true;
        }
    }

    return false;
}

function extractFamilies(_fields : ReadOnlyArray<Field>) : ReadOnlyArray<Family> {
    final extracted = new Array<Family>();

    for (field in _fields) {
        switch field.kind {
            case FVar(t, _):
                switch t {
                    case TAnonymous(anonFields):
                        extracted.push({
                            name  : field.name,
                            types : extractFamilyFields(anonFields)
                        });
                    case other: //
                }
            case other: //
        }
    }

    return extracted;
}

function extractFamilyFields(_fields : ReadOnlyArray<Field>) : ReadOnlyArray<FamilyField> {
    final extracted = new Array<FamilyField>();

    for (field in _fields) {
        switch field.kind {
            case FVar(t, _):
                extracted.push({
                    name : field.name,
                    type : t
                });
            case other: //
        }
    }

    extracted.sort((f1, f2) -> {
        final name1 = f1.name;
        final name2 = f2.name;

        if (name1 < name2) {
            return -1;
        }
        if (name1 > name2) {
            return 1;
        }

        return 0;
    });

    return extracted;
}
