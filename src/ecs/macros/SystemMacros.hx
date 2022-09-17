package ecs.macros;

import haxe.ds.ReadOnlyArray;
import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.macro.Context;

import ecs.ds.Result;
#if macro
import ecs.macros.FamilyCache;
import ecs.macros.ResourceCache;
import ecs.macros.ComponentCache;
#end

using Lambda;
using Safety;
using haxe.macro.Tools;

/**
 * Stores the user specified name and the complex type of a requested component or resource.
 */
@:structInit
@:publicFields
class FamilyField
{
    final name : String;
    final type : ComplexType;
}

/**
 * Stores all the info on a registered component or resource.
 */
class RegisteredField
{
    public final name : String;
    public final type : Type;
    public final hash : String;
    public final uID : Int;

    public function new(_name, _type, _hash, _uID)
    {
        name = _name;
        type = _type;
        hash = _hash;
        uID  = _uID;
    }
}

class FamilyError
{
    public final message : String;
    public final pos : Position;

    public function new(_message, _pos)
    {
        message = _message;
        pos     = _pos;
    }
}

@:structInit
@:publicFields
class FamilyDefinition
{
    /**
     * Name of this family.
     */
    final name : String;

    /**
     * Position of the original family field.
     */
    final pos : Position;

    /**
     * All the static resources requested by this family.
     */
    final resources : Array<RegisteredField>;

    /**
     * All of the components requested by this family.
     */
    final components : Array<RegisteredField>;
}

macro function familyConstruction() : Array<Field>
{
    final fields   = Context.getBuildFields();
    final output   = [];
    final families = new Array<FamilyDefinition>();

    sys.io.File.saveContent(Utils.invalidationFile, Std.string(Math.random() * 2147483647));

#if (debug && !ecs.no_debug_output)
    Sys.println('[ecs] System ${ Context.getLocalClass().get().name } wrote to invalidation file ${ Utils.invalidationFile }');
#end

    for (field in fields)
    {
        if (hasMeta(field, ':fastFamily'))
        {
            switch extractFastFamily(field)
            {
                case Ok(data):
                    families.push({
                        name       : field.name,
                        pos        : field.pos,
                        components : data.map(f -> {
                            final resolved  = try Context.resolveType(f.type, field.pos) catch (_) Context.error('Unable to resolve component type ${ f.type.toString() }', field.pos);
                            final signature = Utils.signature(resolved);

                            return new RegisteredField(f.name, resolved, signature, registerComponent(signature, resolved));
                        }),
                        resources  : []
                    });
                case Error(error): Context.error(error.message, error.pos);
            }
        }
        else if (hasMeta(field, ':fullFamily'))
        {
            switch extractFullFamily(field)
            {
                case Ok(data):
                    families.push({
                        name       : data.name,
                        pos        : field.pos,
                        components : switch data.components
                        {
                            case Ok(array):
                                array.map(f -> {
                                    final resolved  = try Context.resolveType(f.type, field.pos) catch (_) Context.error('Unable to resolve component type ${ f.type.toString() }', field.pos);
                                    final signature = Utils.signature(resolved);

                                    return new RegisteredField(f.name, resolved, signature, registerComponent(signature, resolved));
                                });
                            case Error(error):
                                Context.error(error.message, error.pos);
                        },
                        resources : switch data.resources
                        {
                            case Ok(array):
                                array.map(f -> {
                                    final resolved  = try Context.resolveType(f.type, field.pos) catch (_) Context.error('Unable to resolve resource type ${ f.type.toString() }', field.pos);
                                    final signature = Utils.signature(resolved);

                                    return new RegisteredField(f.name, resolved, signature, registerResource(signature));
                                });
                            case Error(error):
                                Context.error(error.message, error.pos);
                        }
                    });
                case Error(error): Context.error(error.message, field.pos);
            }
        }
        else
        {
            output.push(field);
        }
    }

    final currentClass = Context.getLocalClass().get();

    // This assignment expression in inserted into the systems constructor directly after the 
    final assignment = macro {
        @:mergeBlock $b{ [
            // First pass over the extracted families we define a new family field in the system for that type.
            for (idx => family in families)
            {
                output.push({
                    name   : family.name,
                    pos    : family.pos,
                    access : [ AFinal ],
                    kind   : FVar(macro : ecs.Family)
                });
        
                family.components.sort(sortFields);
                family.resources.sort(sortFields);
    
                // We then insert expressions to fet all families from the universe.
                final clsKey = '${ Utils.signature(Context.getLocalType()) }-${ family.name }';
        
                macro $i{ family.name } = universe.families.get($v{ registerFamily(clsKey, family) });
            }
        ] }

        @:mergeBlock $b{ [
            // For all unique components add a `Components<T>` member field and insert a call to populate it
            for (idx => component in getUniqueComponents(currentClass, families))
            {
                final ct   = component.type.toComplexType();
                final name = 'table${ component.hash }';

                output.push({
                    name   : name,
                    pos    : Context.currentPos(),
                    access : [ AFinal ],
                    kind   : FVar(macro : ecs.Components<$ct>)
                });

                macro $i{ name } = cast universe.components.getTable($v{ component.uID });
            }
        ] }
    }

    switch output.find(f -> f.name == 'new')
    {
        case null:
            output.push({
                name   : 'new',
                pos    : Context.currentPos(),
                access : [ APublic ],
                kind   : FFun({
                    args: [ { name: '_universe', type: macro : ecs.Universe } ],
                    expr: macro {
                        super(_universe);

                        @:mergeBlock $e{ assignment }
                    }
                })
            });
        case existing:
            switch existing.kind
            {
                case FFun({ expr : { expr : EBlock(exprs), pos : p } }):
                    var injected = false;

                    for (idx => expr in exprs)
                    {
                        switch expr.expr
                        {
                            case ECall(e, _):
                                if (e.expr.match(EConst(CIdent('super'))))
                                {
                                    if (idx + 1 >= exprs.length)
                                    {
                                        exprs.push(assignment);
                                    }
                                    else
                                    {
                                        exprs.insert(idx + 1, assignment);
                                    }

                                    injected = true;
                                }
                            case _:
                                //
                        }

                        if (injected)
                        {
                            break;
                        }
                    }

                    if (!injected)
                    {
                        Context.error('Failed to find constructor super call to inject family setup code', p);
                    }
                case other:
                    Context.error('Expected constructor to be a function, found $other', existing.pos);
            }
    }   

    return output;
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
        case FVar(TAnonymous(fields), _): extractFamilyComponentsFromObject(fields);
        case other: Error(new FamilyError('Unexpected field kind $other, expected FVar', _field.pos));
    }
}

/**
 * Given a field it will attempt to extract a fully defined family from the expression within.
 * If any part of the definition is missing an empty array will be used in its place.
 * An error will be returned if any unexpected expression types are encountered.
 * @param _field Field to check.
 * @return Result<FamilyDefinition, String>
 */
private function extractFullFamily(_field : Field) : Result<{ name : String, components : Result<ReadOnlyArray<FamilyField>, FamilyError>, resources : Result<ReadOnlyArray<FamilyField>, FamilyError> }, FamilyError>
{
    return switch _field.kind
    {
        case FVar(TAnonymous(fields), _):
            final requires = fields
                .find(f -> f.name == 'requires')
                .let(f -> switch f.kind
                    {
                        case FVar(TAnonymous(fields), _): extractFamilyComponentsFromObject(fields);
                        case other: Error(new FamilyError('Unexpected object field expression $other', f.pos));
                    })
                .or(Ok([]));
            final resources = fields
                .find(f -> f.name == 'resources')
                .let(f -> switch f.kind
                    {
                        case FVar(TAnonymous(fields), _): extractFamilyComponentsFromObject(fields);
                        case other: Error(new FamilyError('Unexpected object field expression $other', f.pos));
                    })
                .or(Ok([]));

            Ok({
                name       : _field.name,
                components : requires,
                resources  : resources
            });
        case other: Error(new FamilyError('Unexpected field kind ${ other }, expected FVar', _field.pos));
    }
}

/**
 * Extracts all the `EConst(CIdent(_))` names from an array of object fields.
 * Returned family fields are lexographically ordered by their name.
 * If any other expressions are found an error is returned.
 * @param _fields Object fields to search through.
 * @return Result<ReadOnlyArray<FamilyField>, Exception>
 */
private function extractFamilyComponentsFromObject(_fields : ReadOnlyArray<Field>) : Result<ReadOnlyArray<FamilyField>, FamilyError>
{
    final extracted = new Array<FamilyField>();

    for (field in _fields)
    {
        switch field.kind
        {
            case FVar(ct, _):
                extracted.push({
                    name : field.name,
                    type : ct
                });
            case other:
                return Error(new FamilyError('Unexpected expression ${ other }, expected FVar(_, EConst(CIdent(_)))', field.pos));
        }
    }

    return Ok(extracted);
}

/**
 * Given a number of families returns all unique components requested by all of them.
 * This function checks by type not component variable name.
 * @param _class Class of the system being constructed, used to ensure we don't redefine the same component twice.
 * @param _families Families to search.
 * @return ReadOnlyArray<FamilyField>
 */
private function getUniqueComponents(_class : ClassType, _families : ReadOnlyArray<FamilyDefinition>) : ReadOnlyArray<RegisteredField>
{
    final components = new Array<RegisteredField>();

    for (family in _families)
    {
        for (component in family.components)
        {
            if (!components.exists(f -> f.uID == component.uID) && _class.findField('table${ component.hash }') == null)
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
private function sortFields(o1 : RegisteredField, o2 : RegisteredField)
{
    final name1 = o1.hash;
    final name2 = o2.hash;

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