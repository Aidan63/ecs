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

typedef FamilyType = {
    final name : String;
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
    final resources : ReadOnlyArray<FamilyType>;

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

        insertExprIntoFunction(idx, added, macro $i{ family.name } = families.get($v{ registerFamily(family) }));
    }

    // For every field which was found in the family anon object create a Components<T> variable with that field name.
    // These allow you to fetch the component object for a given entity.
    for (family in families)
    {
        for (resource in family.resources)
        {
            resource.uID = registerResource(Context.getType(resource.name).toComplexType());
        }

        for (idx => field in family.components)
        {
            final ct = Context.getType(field.type).toComplexType();

            field.uID = registerComponent(ct);

            // Don't add multiple table fetches for components across multiple families in the same system.
            // Should probably have some better checking system.
            if (!output.exists(f -> f.name == field.name))
            {
                output.push({
                    name : field.name,
                    pos  : Context.currentPos(),
                    kind : FVar(macro : ecs.Components<$ct>),
                });

                insertExprIntoFunction(
                    families.length + idx,
                    added,
                    macro $i{ field.name } = cast components.getTable($v{ field.uID })
                );
            }
        }
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
function getOrCreateOverrideFunction(_name : String, _fields : Array<Field>, _pos : Position)
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
function insertExprIntoFunction(_pos : Int, _field : Field, _expr : Expr)
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
function hasMeta(_field : Field, _meta : String)
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
function extractFastFamily(_field : Field)
{
    return switch _field.kind
    {
        case FVar(_, expr):
            switch expr.expr
            {
                case EObjectDecl(fields): extractFamilyComponents(fields);
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
function extractFullFamily(_field : Field) : Result<FamilyDefinition, FamilyError>
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
                                case EObjectDecl(fields): extractFamilyComponents(fields);
                                case other: Error({ message : 'Unexpected object field expression $other', pos : f.expr.pos });
                            })
                        .or(Ok([]));
                    final resources = fields
                        .find(f -> f.field == 'resources')
                        .let(f -> switch f.expr.expr
                            {
                                case EArrayDecl(values): extractFamilyResources(values);
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
function extractFamilyComponents(_fields : Array<ObjectField>) : Result<ReadOnlyArray<FamilyField>, FamilyError>
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

    extracted.sort((f1, f2) -> {
        final name1 = f1.name;
        final name2 = f2.name;

        if (name1 < name2)
        {
            return -1;
        }
        if (name1 > name2)
        {
            return 1;
        }

        return 0;
    });

    return Ok(extracted);
}

/**
 * Given an array of expressions it will extract all `EConst(CIdent(_))` names into family types.
 * If an expression not of that type is found it will return with an error.
 * @param _exprs Expressions to read.
 * @return Result<ReadOnlyArray<FamilyType>, FamilyError>
 */
function extractFamilyResources(_exprs : Array<Expr>) : Result<ReadOnlyArray<FamilyType>, FamilyError>
{
    final types = new Array<FamilyType>();

    for (e in _exprs)
    {
        switch e.expr
        {
            case EConst(CIdent(s)): types.push({ name : s });
            case other: Error({ message : 'Unexpected expression type $other', pos : e.pos });
        }
    }

    return Ok(types);
}