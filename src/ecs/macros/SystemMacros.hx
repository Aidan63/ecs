package ecs.macros;

import haxe.ds.ReadOnlyArray;
import haxe.macro.Expr;
import haxe.macro.Context;
import ecs.ds.Result;
import ecs.macros.FamilyCache;
import ecs.macros.ResourceCache;
import ecs.macros.ComponentCache;

using Lambda;
using Safety;
using haxe.macro.Tools;

typedef FamilyField = {
    final name : String;
    final type : String;
    var ?uID : Int;
}

typedef FamilyError = {
    final message : String;
    final pos : Position;
}

typedef FamilyDefinition = {
    /**
     * Name of this family.
     */
    final name : String;

    /**
     * All the static resources requested by this family.
     */
    final resources : ReadOnlyArray<FamilyField>;

    /**
     * All of the components requested by this family.
     */
    final components : ReadOnlyArray<FamilyField>;
}

macro function familyConstruction() : Array<Field>
{
    final fields = Context.getBuildFields();
    final output = [];

    final added    = getOrCreateOverrideFunction('onAdded', fields, Context.currentPos());
    final removed  = getOrCreateOverrideFunction('onRemoved', fields, Context.currentPos());
    final families = new Array<FamilyDefinition>();

    for (field in fields)
    {
        if (hasMeta(field, ':fastFamily'))
        {
            switch extractFastFamily(field)
            {
                case Ok(data):
                    families.push({
                        name       : field.name,
                        components : data,
                        resources  : []
                    });
                case Error(error): Context.error(error.message, error.pos);
            }
        }
        else if (hasMeta(field, ':fullFamily'))
        {
            switch extractFullFamily(field)
            {
                case Ok(data): families.push(data);
                case Error(error): Context.error(error.message, error.pos);
            }
        }
        else
        {
            output.push(field);
        }
    }

    // First pass over the extracted families we define a new family field in the system for that type.
    // We also add a call to get that family from the world at the top of the `onAdded` function.
    for (idx => family in families)
    {
        output.push({
            name : family.name,
            pos  : Context.currentPos(),
            kind : FVar(macro : ecs.Family)
        });

        // Insert out `family.get` calls at the very top of the `onAdded` function.
        // This we we can always access them in a overridden `onAdded`.

        final clsKey = '${ Context.getLocalType().toComplexType().toString() }-${ family.name }';

        insertExprIntoFunction(idx, added, macro $i{ family.name } = universe.families.get($v{ registerFamily(clsKey, family) }));
    }

    // Register all resources and components requested by each family.
    for (family in families)
    {
        for (resource in family.resources)
        {
            resource.uID = registerResource(Context.getType(resource.type).toComplexType());
        }

        for (component in family.components)
        {
            component.uID = registerComponent(Context.getType(component.type).toComplexType());
        }
    }

    // For all unique components add a `Components<T>` member field and insert a call to populate it in the `onAdded` function.
    for (idx => component in getUniqueComponents(families))
    {
        final ct   = Context.getType(component.type).toComplexType();
        final name = 'table${ component.type }';

        output.push({
            name : name,
            pos  : Context.currentPos(),
            kind : FVar(macro : ecs.Components<$ct>),
        });

        // Inserting at `families.length + idx` ensures all out `getTable` calls happen after the families are fetched.
        insertExprIntoFunction(
            families.length + idx,
            added,
            macro $i{ name } = cast universe.components.getTable($v{ component.uID })
        );
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
private function getOrCreateOverrideFunction(_name : String, _fields : Array<Field>, _pos : Position)
{
    for (field in _fields)
    {
        if (field.name == _name)
        {
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
 * @param _pos Position within the existing expression array to insert at.
 * @param _field Field to insert in, must be a FFun EBlock field.
 * @param _expr Expression to insert.
 */
private function insertExprIntoFunction(_pos : Int, _field : Field, _expr : Expr)
{
    switch _field.kind
    {
        case FFun(f):
            switch f.expr.expr
            {
                case EBlock(exprs): exprs.insert(_pos, _expr);
                case _:
            }
        case _:
    }
}

/**
 * Returns if a field has the provided metadata string.
 * @param _field Field to check.
 * @param _meta Meta data name.
 */
private function hasMeta(_field : Field, _meta : String)
{
    if (_field.meta == null || _field.meta.length == 0)
    {
        return false;
    }

    for (meta in _field.meta)
    {
        if (meta.name == _meta)
        {
            return true;
        }
    }

    return false;
}

/**
 * Given a field it will attempt to extract a family definition from just the requested components.
 * Empty arrays will be used for the resources and exclusions.
 * An error will be returned if any unexpected expression types are encountered.
 * @param _field Field to check.
 * @return Result<FamilyDefinition, String>
 */
private function extractFastFamily(_field : Field)
{
    return switch _field.kind
    {
        case FVar(_, expr):
            switch expr.expr
            {
                case EObjectDecl(fields): extractFamilyComponentsFromObject(fields);
                case EArrayDecl(values): extractFamilyComponentsFromArray(values);
                case _: Error({ message : 'Unexpected variable expression ${ expr.toString() }, expected EObjectDecl', pos : expr.pos });
            }
        case other: Error({ message : 'Unexpected field kind $other, expected FVar', pos : _field.pos });
    }
}

/**
 * Given a field it will attempt to extract a fully defined family from the expression within.
 * If any part of the definition is missing an empty array will be used in its place.
 * An error will be returned if any unexpected expression types are encountered.
 * @param _field Field to check.
 * @return Result<FamilyDefinition, String>
 */
private function extractFullFamily(_field : Field) : Result<FamilyDefinition, FamilyError>
{
    return switch _field.kind
    {
        case FVar(_, expr):
            switch expr.expr
            {
                case EObjectDecl(fields):
                    final requires = fields
                        .find(f -> f.field == 'requires')
                        .let(f -> switch f.expr.expr
                            {
                                case EObjectDecl(fields): extractFamilyComponentsFromObject(fields);
                                case EArrayDecl(values): extractFamilyComponentsFromArray(values);
                                case other: Error({ message : 'Unexpected object field expression $other', pos : f.expr.pos });
                            })
                        .or(Ok([]));
                    final resources = fields
                        .find(f -> f.field == 'resources')
                        .let(f -> switch f.expr.expr
                            {
                                case EObjectDecl(fields): extractFamilyComponentsFromObject(fields);
                                case EArrayDecl(values): extractFamilyComponentsFromArray(values);
                                case other: Error({ message : 'Unexpected object field expression $other', pos : f.expr.pos });
                            })
                        .or(Ok([]));

                    Ok({
                        name       : _field.name,
                        components : switch requires
                        {
                            case Ok(data): data;
                            case Error(error): return Error(error);
                        },
                        resources  : switch resources
                        {
                            case Ok(data): data;
                            case Error(error): return Error(error);
                        }
                    });
                case _: Error({ message : 'Unexpected variable expression ${ expr.toString() }, expected EObjectDec', pos : expr.pos });
            }
        case other: Error({ message : 'Unexpected field kind ${ other }, expected FVar', pos : _field.pos });
    }
}

/**
 * Extracts all the `EConst(CIdent(_))` names from an array of object fields.
 * Returned family fields are lexographically ordered by their name.
 * If any other expressions are found an error is returned.
 * @param _fields Object fields to search through.
 * @return Result<ReadOnlyArray<FamilyField>, Exception>
 */
private function extractFamilyComponentsFromObject(_fields : Array<ObjectField>) : Result<ReadOnlyArray<FamilyField>, FamilyError>
{
    final extracted = new Array<FamilyField>();

    for (field in _fields)
    {
        switch field.expr.expr
        {
            case EConst(CIdent(s)):
                extracted.push({
                    name : field.field,
                    type : s
                });
            case _: return Error({ message : 'Unexpected expression ${ field.expr.toString() }, expected EConst(CIdent(_))', pos : field.expr.pos });
        }
    }

    extracted.sort(sort);

    return Ok(extracted);
}

/**
 * Extracts all the `EConst(CIdent(_))` names from an array of expressions.
 * Returned family fields are lexographically ordered by their name.
 * If any other expressions are found an error is returned.
 * Since this only checks for `CIdent` expressions the name of all returned components will be `_`,
 * this causes the `iterate` macro to not generate local variables for these components.
 * @param _values 
 * @return Result<ReadOnlyArray<FamilyField>, FamilyError>
 */
private function extractFamilyComponentsFromArray(_values : Array<Expr>) : Result<ReadOnlyArray<FamilyField>, FamilyError>
{
    final extracted = new Array<FamilyField>();

    for (value in _values)
    {
        switch value.expr
        {
            case EConst(CIdent(s)):
                extracted.push({
                    name : '_',
                    type : s
                });
            case _: Error({ message : 'Unexpected expression ${ value.toString() }, expected EConst(CIdent(_))', pos : value.pos });
        }
    }

    extracted.sort(sort);

    return Ok(extracted);
}

/**
 * Given a number of families returns all unique components requested by all of them.
 * This function checks by type not component variable name.
 * @param _families Families to search.
 * @return ReadOnlyArray<FamilyField>
 */
private function getUniqueComponents(_families : ReadOnlyArray<FamilyDefinition>) : ReadOnlyArray<FamilyField>
{
    final components = new Array<FamilyField>();

    for (family in _families)
    {
        for (component in family.components)
        {
            if (!components.exists(f -> f.type == component.type))
            {
                components.push(component);
            }
        }
    }

    return components;
}

/**
 * Function to sort two objects based on a name field.
 * @param o1 Object 1.
 * @param o2 Object 2.
 */
private function sort(o1 : Dynamic, o2 : Dynamic)
{
    final name1 = o1.type;
    final name2 = o2.type;

    if (name1 < name2)
    {
        return -1;
    }
    if (name1 > name2)
    {
        return 1;
    }

    return 0;
}