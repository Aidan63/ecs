package ecs.macros;

import haxe.ds.Option;
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

        // Insert out `family.get` calls at the very top of the `onAdded` function.
        // This we we can always access them in a overridden `onAdded`.

        final clsKey = '${ Context.getLocalType().toComplexType().toString() }-${ family.name }';

        insertExprIntoFunction(idx, added, macro $i{ family.name } = families.get($v{ registerFamily(clsKey, family) }));
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
        final name = makeTableName(component.type);

        output.push({
            name : name,
            pos  : Context.currentPos(),
            kind : FVar(macro : ecs.Components<$ct>),
        });

        // Inserting at `families.length + idx` ensures all out `getTable` calls happen after the families are fetched.
        insertExprIntoFunction(
            families.length + idx,
            added,
            macro $i{ name } = cast components.getTable($v{ component.uID })
        );
    }

    return output;
}

/**
 * Iterate over a family and access the components required by it.
 * @param _family Family to iterate over.
 * @param _function Code to run for each entity in the family.
 */
macro function iterate(_family : ExprOf<Family>, _function : Expr)
{
    // Get the name of the family to iterate over.
    final familyIdent = switch _family.expr
    {
        case EConst(CIdent(s)):
            s;
        case other:
            Context.error('Family passed into iterate must be an identifier', _family.pos);
    }
    // Extract the name of the entity variable in each iteration and the user typed expressions for the loop.
    final extracted = switch _function.expr
    {
        case EFunction(_, f):
            {
                name : if (f.args.length == 0) '_tmpEnt' else f.args[0].name,
                expr : switch extractFunctionBlock(f.expr)
                {
                    case Some(v): v;
                    case None: Context.error('Unable to extract EBlock from function', f.expr.pos);
                }
            };
        case EBlock(exprs):
            { name : '_tmpEnt', expr : exprs };
        case other:
            Context.error('Unsupported iterate expression $other', _function.pos);
    }

    // Based on the family name and this systems name search all registered families for a match
    final clsKey     = '${ Context.getLocalType().toComplexType().toString() }-${ familyIdent }';
    final components = switch getFamilyByKey(clsKey)
    {
        case Some(family): family.components;
        case None: Context.error('Unable to find a family with the key $clsKey', _family.pos);
    }

    // Generate a local variable with the requested name for each component in the family.
    // Then append the user typed for loop expression to ensure the variables are always accessible
    final forExpr = [];
    for (c in components)
    {
        final varName   = c.name;
        final tableName = makeTableName(c.type);

        // Defining a component in a family as '_' will skip the variable generation.
        if (varName != '_')
        {
            forExpr.push(macro final $varName = $i{ tableName }.get($i{ extracted.name }));
        }
    }
    for (e in extracted.expr)
    {
        forExpr.push(e);
    }

    return macro for ($i{ extracted.name } in $e{ _family }) $b{ forExpr };
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

    extracted.sort(sort);

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
            case EConst(CIdent(s)): types.push({ type : s });
            case other: Error({ message : 'Unexpected expression type $other', pos : e.pos });
        }
    }

    types.sort(sort);

    return Ok(types);
}

/**
 * Given a number of families returns all unique components requested by all of them.
 * This function checks by type not component variable name.
 * @param _families Families to search.
 * @return ReadOnlyArray<FamilyField>
 */
function getUniqueComponents(_families : ReadOnlyArray<FamilyDefinition>) : ReadOnlyArray<FamilyField>
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
 * Given an expression it will try and extract the EBlock expressions acting as if it is a function expression.
 * It expects an `EMeta(EReturn(EBlock))` expression three.
 * @param _expr Expression to operate on.
 * @return Option<Array<Expr>>
 */
function extractFunctionBlock(_expr : Expr) : Option<Array<Expr>>
{
    return switch _expr.expr
    {
        case EMeta(_, e):
            switch e.expr
            {
                case EReturn(e):
                    switch e.expr
                    {
                        case EBlock(exprs): Some(exprs);
                        case _: None;
                    }
                case _: None;
            }
        case _: None;
    }
}

/**
 * Function to sort two objects based on a name field.
 * @param o1 Object 1.
 * @param o2 Object 2.
 */
function sort(o1 : Dynamic, o2 : Dynamic)
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

function makeTableName(_type : String) return 'table$_type';