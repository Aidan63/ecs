package ecs.macros;

import ecs.macros.ComponentCache.registerComponent;
import ecs.macros.ResourceCache.registerResource;
import ecs.ds.Set;
import ecs.ds.Result;
import haxe.ds.Option;
import haxe.macro.Context;
import haxe.macro.Type.ClassType;
import haxe.macro.Type.TVar;
import haxe.macro.Expr;
import ecs.macros.ResourceCache.getResourceID;
import ecs.macros.ComponentCache.getComponentID;
import ecs.macros.FamilyCache.getFamilyByKey;
import ecs.macros.FamilyCache.getFamilyIDsWithResource;
import ecs.macros.FamilyCache.getFamilyIDsWithComponent;

using Safety;
using haxe.macro.Tools;

/**
 * This module contains all the user facing macro functions needed to easily work with a universe.
 * Functions within this module are designed to be used as static extensions to a universe object,
 * the exception to this is `iterate` which cannot be used if this module is included with `using`.
 * A way around this should be found.
 */

/**
 * Creates a new entity within the provided universe.
 * If the maximum number of entities has been reached an exception is thrown.
 * 
 * Example usage for `using ecs.macros.UniverseMacros;`
 * 
 * ```
 * final ent = universe.createEntity();
 * final ent = this.createEntity();
 * 
 * ```
 * The first line would be an example for when you have access the universe object (e.g. having just created it, or calling from inside a system).
 * Second line would be if you are extending the universe and calling from within the sub class. The `this.` part is required in this case.
 * 
 * @param _universe Universe to create the entity within.
 * @return Created entity ID.
 * @throws UniverseFullException Thrown if there is not enough space in the universe for another entity.
 */
macro function createEntity(_universe : ExprOf<Universe>) : ExprOf<Entity>
{
    return macro $e{ _universe }.entities.create();
}

/**
 * Destroy an entity and all its attached components from the given universe.
 * If the provided universe does not contain the entity then no operation is performed.
 * 
 * Example usage for `using ecs.macros.UniverseMacros;`
 * 
 * ```
 * final ent = // an entity is assigned to this field from somewhere
 * universe.destroyEntity(ent);
 * this.destroyEntity(ent);
 * ```
 * 
 * 
 * @param _universe Universe to remove the entity from.
 * @param _entity Entity ID.
 */
macro function destroyEntity(_universe : ExprOf<Universe>, _entity : ExprOf<Entity>)
{
    return macro {
        final _ecsTmpEntity = $e{ _entity };
        $e{ _universe }.components.clear(_ecsTmpEntity);
        $e{ _universe }.families.whenEntityDestroyed(_ecsTmpEntity);
    }
}

/**
 * Sets any number of components on an entity in a specific universe.
 * The final argument is a rest argument meaning it can take in any number of arguments.
 * 
 * Example usage for `using ecs.macros.UniverseMacros;`
 * 
 * ```
 * unverse.setComponents(myEntity,
 *     new Position(32, 32),
 *     new Velocity(),
 *     new Sprite('assets/player.png'));
 * ```
 * 
 * Along with the usual variable, function, and constructor expressions if the component has a constructor
 * with no arguments then simply passing in the type will construct a new component for it.
 * 
 * ```
 * universe.setComponents(myEntity,
 *     new Position(32, 32),
 *     Velocity,
 *     new Sprite('assets/player.png));
 * ```
 * 
 * It is also possible to use basic types for components.
 * 
 * ```
 * universe.setComponents(myEntity, 7, 4.2, true, 'hello world');
 * ```
 * 
 * Attempting to add a component which is not used in any families will result in a compiler warning and that
 * expression will not be typed (no functions or property getters would be called if used).
 * Setting a component onto an entity which already has a component of that type will replace it.
 * 
 * @param _universe Universe which contains the entity.
 * @param _entity Entity to add components to.
 * @param _components Components to add.
 */
macro function setComponents(_universe : ExprOf<Universe>, _entity : Expr, _components : Array<Expr>)
{
    final staticLoading = Context.defined('ecs.static_loading');
    final exprs         = [ macro final _ecsTmpEntity = $e{ _entity } ];
    final added         = new Set();
    final insert        = (id, compExpr) -> {
        exprs.push(macro $e{ _universe }.components.set(_ecsTmpEntity, $v{ id }, $e{ compExpr }));

        if (staticLoading)
        {
            for (familyID in getFamilyIDsWithComponent(id))
            {
                added.add(familyID);
            }
        }
    }

    for (component in _components)
    {
        switch component.expr
        {
            case EConst(CIdent(s)):
                switch isLocalIdent(s, Context.getLocalType().getClass(), Context.getLocalTVars())
                {
                    case Some(type):
                        if (staticLoading)
                        {
                            switch getComponentID(Utils.signature(type))
                            {
                                case Some(id): insert(id, component);
                                case None: Context.warning('Local ident $s : $type is not used in any families', component.pos);
                            }
                        }
                        else
                        {
                            insert(registerComponent(Utils.signature(type), type), component);
                        }
                    case None:
                        final resolved  = Context.getType(s);
                        final signature = Utils.signature(resolved);

                        if (staticLoading)
                        {
                            switch getComponentID(signature)
                            {
                                case Some(id):
                                    switch resolved.toComplexType()
                                    {
                                        case TPath(tp): insert(id, macro new $tp());
                                        case other: Context.error('Component $other should be TPath', component.pos);
                                    }
                                case None: Context.warning('Component $resolved is not used in any families', component.pos);
                            }
                        }
                        else
                        {
                            switch resolved.toComplexType()
                            {
                                case TPath(tp): insert(registerComponent(signature, resolved), macro new $tp());
                                case other: Context.error('Component $other should be TPath', component.pos);
                            }
                        }
                }
            case _:
                try
                {
                    final resolved  = Context.typeof(component);
                    final signature = Utils.signature(resolved);

                    switch getComponentID(signature)
                    {
                        case Some(id): insert(id, component);
                        case None: Context.warning('Component ${ resolved } is not used in any families', component.pos);
                    }
                }
                catch (_)
                {
                    Context.error('Unable to get type of component expression ${ component.toString() }', component.pos);
                }
        }
    }

    // After all `set` functions are called check each family which could have been modified by the components added.
    exprs.push(macro final ecsEntCompFlags = $e{ _universe }.components.flags[_ecsTmpEntity.id()]);
    if (staticLoading)
    {
        // With static loaded the `added` set contains all families which could have been effected by the components added.
        // So we only need to check those ones.
        for (familyID in added)
        {
            exprs.push(macro final ecsTmpFamily = $e{ _universe }.families.get($v{ familyID }));
            exprs.push(macro if (ecsEntCompFlags.areSet(ecsTmpFamily.componentsMask)) {
                ecsTmpFamily.add(_ecsTmpEntity);
            });
        }
    }
    else
    {
        // With dynamic loaded we have no choice but to check all families.
        exprs.push(macro for (i in 0...$e{ _universe }.families.number) {
            final ecsTmpFamily = $e{ _universe }.families.get(i);
            if (ecsEntCompFlags.areSet(ecsTmpFamily.componentsMask))
            {
                ecsTmpFamily.add(_ecsTmpEntity);
            }
        });
    }

    return macro $b{ exprs };
}

/**
 * Removes any number of components from an entity in a given universe.
 * The final argument is a rest argument meaning it can take in any number of arguments.
 * 
 * Example usage for `using ecs.macros.UniverseMacros;`
 * 
 * ```
 * universe.removeComponents(myEntity, Position, Velocity, Sprite);
 * ```
 * 
 * Attempting to remove a component which is not used in any families will result in a compiler warning
 * and that expression will be skipped.
 * @param _universe Universe which contains the entity.
 * @param _entity Entity to remove components from.
 * @param _components Components to remove.
 */
macro function removeComponents(_universe : ExprOf<Universe>, _entity : Expr, _components : Array<Expr>)
{
    final staticLoading = Context.defined('ecs.static_loading');
    final exprs         = [ macro final _ecsTmpEntity = $e{ _entity } ];
    final added         = new Set();
    final insert        = id -> {
        exprs.push(macro $e{ _universe }.components.remove(_ecsTmpEntity, $v{ id }));

        if (staticLoading)
        {
            for (familyID in getFamilyIDsWithComponent(id))
            {
                added.add(familyID);
            }
        }
    };

    for (component in _components)
    {
        switch component.expr
        {
            case EConst(CIdent(s)):
                switch isLocalIdent(s, Context.getLocalType().getClass(), Context.getLocalTVars())
                {
                    case Some(type):
                        switch getComponentID(Utils.signature(type))
                        {
                            case Some(id): insert(id);
                            case None: Context.warning('Component ${ type } is not used in any families', component.pos);
                        }
                    case None:
                        final resolved  = Context.getType(s);
                        final signature = Utils.signature(resolved);

                        switch getComponentID(signature)
                        {
                            case Some(id): insert(id);
                            case None: Context.warning('Component ${ resolved } is not used in any families', component.pos);
                        }
                }
            case _: Context.error('Unsupported component expression ${ component.toString() }', component.pos);
        }
    }

    // After all `remove` functions are called check each family which could have been modified by the components removed.
    exprs.push(macro final ecsEntCompFlags = $e{ _universe }.components.flags[_ecsTmpEntity.id()]);
    if (staticLoading)
    {
        // With static loaded the `added` set contains all families which could have been effected by the components added.
        // So we only need to check those ones.
        for (familyID in added)
        {
            exprs.push(macro final ecsTmpFamily = $e{ _universe }.families.get($v{ familyID }));
            exprs.push(macro if (!ecsEntCompFlags.areSet(ecsTmpFamily.componentsMask)) {
                ecsTmpFamily.remove(_ecsTmpEntity);
            });
        }
    }
    else
    {
        // With dynamic loaded we have no choice but to check all families.
        exprs.push(macro for (i in 0...$e{ _universe }.families.number) {
            final ecsTmpFamily = $e{ _universe }.families.get(i);
            if (!ecsEntCompFlags.areSet(ecsTmpFamily.componentsMask))
            {
                ecsTmpFamily.add(_ecsTmpEntity);
            }
        });
    }

    return macro $b{ exprs };
}

/**
 * Add any number of resources to a given universe.
 * The final argument is a rest argument meaning it can take in any number of arguments.
 * 
 * Example usage for `using ecs.macros.UniverseMacros;`
 * 
 * ```
 * unverse.setResource(
 *     new LevelData('assets/level1.json'),
 *     new SpriteBatcher());
 * ```
 * 
 * Along with the usual variable, function, and constructor expressions if the resource has a constructor
 * with no arguments then simply passing in the type will construct it.
 * 
 * ```
 * universe.setResources(
 *     new LevelData('assets/level1.json'),
 *     SpriteBatcher);
 * ```
 * 
 * It is also possible to use basic types for resources.
 * 
 * ```
 * universe.setResources(7, 4.2, true, 'hello world');
 * ```
 * 
 * Attempting to add a resource which is not used in any families will result in a compiler warning and that
 * expression will not be typed (no functions or property getters would be called if used).
 * Setting a resource which has already been set will replace.
 * @param _universe Universe to add resources to.
 * @param _resources Resources to add.
 */
macro function setResources(_universe : ExprOf<Universe>, _resources : Array<Expr>)
{
    final staticLoading = Context.defined('ecs.static_loading');
    final exprs         = [];
    final added         = new Set();
    final insert        = (id, resExpr) -> {
        exprs.push(macro $e{ _universe }.resources.insert($v{ id }, $e{ resExpr }));

        if (staticLoading)
        {
            for (familyID in getFamilyIDsWithResource(id))
            {
                added.add(familyID);
            }   
        }
    };

    for (resource in _resources)
    {
        switch resource.expr
        {
            case EConst(CIdent(s)):
                switch isLocalIdent(s, Context.getLocalType().getClass(), Context.getLocalTVars())
                {
                    case Some(type):
                        insert(registerResource(Utils.signature(type)), resource);
                    case None:
                        final resolved  = Context.getType(s);
                        final signature = Utils.signature(resolved);
                        final id        = registerResource(signature);

                        switch resolved.toComplexType()
                        {
                            case TPath(tp): insert(id, macro new $tp());
                            case other: Context.error('Resource $other should be TPath', resource.pos);
                        }
                }
            case _:
                try
                {
                    final resolved  = Context.typeof(resource);
                    final signature = Utils.signature(resolved);
                    final id        = registerResource(signature);

                    insert(id, resource);
                }
                catch (_)
                {
                    Context.error('Unable to get type of resource expression $resource', resource.pos);
                }
        }
    }

    // Add a call to try and activate each families which requested the resources.
    // If we are not dynamically loading we can reduced the number of families we try and activate
    // When dynamically loading we have no choice by to try and load each family.
    if (staticLoading)
    {
        for (familyID in added)
        {
            exprs.push(macro $e{ _universe }.families.tryActivate($v{ familyID }));
        }
    }
    else
    {
        exprs.push(macro for (i in 0...$e{ _universe }.families.number) $e{ _universe }.families.tryActivate(i));
    }

    return macro $b{ exprs };
}

/**
 * Removes any number of resource from the given universe.
 * The final argument is a rest argument meaning it can take in any number of arguments.
 * 
 * Example usage for `using ecs.macros.UniverseMacros;`
 * 
 * ```
 * universe.removeResources(LevelData, SpriteBatcher);
 * ```
 * 
 * Attempting to remove a resource which is not used in any families will result in a compiler warning
 * and that expression will be skipped.
 * @param _universe Universe to remove the resource from.
 * @param _components Resources to remove.
 */
macro function removeResources(_universe : ExprOf<Universe>, _resources : Array<Expr>)
{
    final staticLoading = Context.defined('ecs.static_loading');
    final exprs         = [];
    final adder         = new Set();
    final insert        = id -> {
        adder.add(id);

        if (staticLoading)
        {
            for (familyID in getFamilyIDsWithResource(id))
            {
                exprs.push(macro $e{ _universe }.families.get($v{ familyID }).deactivate());
            }
        }
    };

    for (resource in _resources)
    {
        switch resource.expr
        {
            case EConst(CIdent(s)):
                switch isLocalIdent(s, Context.getLocalType().getClass(), Context.getLocalTVars())
                {
                    case Some(type):
                        switch getResourceID(Utils.signature(type))
                        {
                            case Some(id): insert(id);
                            case None: Context.warning('Resource $type is not used in any families', resource.pos);
                        }
                    case None:
                        final resolved  = Context.getType(s);
                        final signature = Utils.signature(resolved);

                        switch getResourceID(signature)
                        {
                            case Some(id):
                                switch resolved.toComplexType()
                                {
                                    case TPath(_): insert(id);
                                    case other:
                                }
                            case None: Context.warning('Resource $resolved is not used in any families', resource.pos);
                        }
                }
            case _:
                Context.error('Unsupported resource expression ${ resource.toString() }', resource.pos);
        }
    }

    // Remove the resources once each family has been deactivated
    for (resourceID in adder)
    {
        if (!staticLoading)
        {
            exprs.push(macro for (i in 0...$e{ _universe }.families.number) $e{ _universe }.families.tryDeactivate(i, $v{ resourceID }));
        }

        exprs.push(macro $e{ _universe }.resources.remove($v{ resourceID }));
    }

    return macro $b{ exprs };
}

/**
 * Add any number of systems to be ran by the provided universe.
 * The final argument is a rest argument meaning it can take in any number of arguments.
 * 
 * Example usage for `using ecs.macros.UniverseMacros;`
 * 
 * ```
 * unverse.setSystems(
 *     new VelocitySystem(),
 *     new SpriteDrawingSystem());
 * ```
 * 
 * Along with the usual variable, function, and constructor expressions if the system does not have a custom
 * constructor you can provide just the type and it will be constructed for you.
 * 
 * ```
 * universe.setSystems(
 *     new VelocitySystem(),
 *     SpriteDrawingSystem);
 * ```
 * 
 * Systems are updated in the order they were added, and adding the same system to the universe twice will cause it
 * to be updated twice on every universe update.
 * @param _universe Universe to add systems to.
 * @param _systems Systems to add.
 */
macro function setSystems(_universe : ExprOf<Universe>, _systems : Array<Expr>)
{
    final exprs = [];

    for (system in _systems)
    {
        switch system.expr
        {
            case EConst(CIdent(s)):
                // Systems don't have unique IDs so we pass a function which will always return 0.
                // This way we can still use the same resolution logic
                switch isLocalIdent(s, Context.getLocalType().getClass(), Context.getLocalTVars())
                {
                    case Some(_):
                        exprs.push(macro $e{ _universe }.systems.add($e{ system }));
                    case None:
                        switch Context.getType(s).toComplexType()
                        {
                            case TPath(tp): exprs.push(macro $e{ _universe }.systems.add(new $tp($e{ _universe })));
                            case other: Context.error('System $other should be TPath', system.pos);
                        }
                }
            case ENew(tp, _):
                exprs.push(macro $e{ _universe }.systems.add($e{ system }));
            case _:
                Context.error('Unsupported system expression ${ system }', system.pos);
        }
    }

    return macro $b{ exprs };
}

/**
 * Remove any number of systems from the provided universe.
 * The final argument is a rest argument meaning it can take in any number of arguments.
 * 
 * Example usage for `using ecs.macros.UniverseMacros;`
 * 
 * ```
 * unverse.removeSystems(
 *     someField,
 *     functionWhichReturnsSomeSystem());
 * ```
 * 
 * The system expressions must refer to a system object, as currently systems do not have a unique ID.
 * 
 * @param _universe Universe to remove systems from.
 * @param _systems fields pointing to system objects to remove.
 */
macro function removeSystems(_universe : ExprOf<Universe>, _systems : Array<Expr>)
{
    final exprs = [];

    for (system in _systems)
    {
        switch system.expr
        {
            case EConst(CIdent(s)):
                switch isLocalIdent(s, Context.getLocalType().getClass(), Context.getLocalTVars())
                {
                    case Some(_):
                        exprs.push(macro $e{ _universe }.systems.remove($e{ system }));
                    case None:
                        Context.error('Only expressions which reference a system object can be used to remove a system', system.pos);
                }
            case _: Context.error('Only expressions which reference a system object can be used to remove a system', system.pos);
        }
    }

    return macro $b{ exprs };
}

/**
 * The setup macro function checks if all the resources requested by the provided families are available,
 * if they are it creates local variables for each resource with the specified name and runs the provided code block.
 * 
 * ```
 * setup(someFamily, {
 *     // code will only be ran if all of the resources requested by `someFamily` are available.
 * });
 * ```
 * 
 * This macro function cannot be used when importing the `UniverseMacros` module for static extension use.
 * @param _families Either a family definition variable or an array of family definition variables. 
 * @param _function Code to execute if all the families are active.
 */
macro function setup(_families : ExprOf<Family>, _function : Expr)
{
    final familiesToSetup = switch _families.expr
    {
        case EConst(CIdent(s)): [ s ];
        case EArrayDecl(values): [ for (e in values) switch e.expr {
            case EConst(CIdent(s)): s;
            case _: Context.error('Family should be an identifier', e.pos);
        } ];
        case _: Context.error('Families to setup must be an identifier or an array of identifiers', _families.pos);
    }
    final extracted = switch _function.expr
    {
        case EFunction(_, f):
            switch extractFunctionBlock(f.expr)
            {
                case Some(v): v;
                case None: Context.error('Unable to extract EBlock from function', f.expr.pos);
            }
        case EBlock(exprs):
            exprs;
        case other:
            Context.error('Unsupported iterate expression $other', _function.pos);
    };
    
    // Insert variable declarations to the top of the extracted function block.
    // TODO : should probably check to make sure there are no type or name collisions.
    for (ident in familiesToSetup)
    {
        final clsKey = '${ Utils.signature(Context.getLocalType()) }-${ ident }';
        switch getFamilyByKey(clsKey)
        {
            case Some(family):

                for (resource in family.resources)
                {
                    if (resource.name != '_')
                    {
                        final signature = Utils.signature(resource.type);
                        final ct        = resource.type.toComplexType();
                        final varName   = resource.name;

                        switch getResourceID(signature)
                        {
                            case Some(id):
                                extracted.insert(0, macro final $varName = (universe.resources.get($v{ id }) : $ct));
                            case None:
                                Context.error('Resource ${ resource.type } has not been requested by any families', _families.pos);
                        }
                    }
                }
            case None: Context.error('Unable to find a family with the key $clsKey', _families.pos);
        }
    }

    // Build up the if check for all the of families
    var idx  = familiesToSetup.length - 1;
    var expr = macro $i{ familiesToSetup[idx] }.isActive();

    while (idx > 0)
    {
        idx--;

        expr = macro $e{ expr } && $i{ familiesToSetup[idx] }.isActive();
    }

    return macro if ($e{ expr }) $b{ extracted };
}

/**
 * The iterate macro is the main way to execute code with each entities components in a given family,
 * it automates the process of getting the components using the names provided when defining the family.
 * In situations where you don't actually care about the entity itself you can use it in the following way.
 * 
 * ```
 * iterate(someFamily, {
 *     // code here is ran for each entity found in `someFamily`.
 * });
 * ```
 * Alternatively lambda function syntax can be used.
 * ```
 * iterate(someFamily, () -> {
 *     // code here is ran for each entity found in `someFamily`.
 * });
 * ```
 * If you do need to access the entity whos components are currently being accessed then you can use lambda function
 * syntax with a single parameter which will then be accessible in the block and contain the current entity.
 * ```
 * iterate(someFamily, entity -> {
 *     // `entity` is the entity which has the components currently being accessed.
 * });
 * ```
 * It is perfectly valid to nest iterate calls as long as there are no component identifier collisions in any of the
 * nested function iterations.
 * 
 * This macro function cannot be used when importing the `UniverseMacros` module for static extension use.
 * @param _family Family to iterate over.
 * @param _function Code to run for each entity in the family.
 */
macro function iterate(_family : ExprOf<Family>, _function : Expr)
{
    // Get the name of the family to iterate over.
    final familyIdent = switch _family.expr
    {
        case EConst(CIdent(s)): s;
        case _: Context.error('Family passed into iterate must be an identifier', _family.pos);
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
    final clsKey     = '${ Utils.signature(Context.getLocalType()) }-${ familyIdent }';
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
        final tableName = 'table${ c.hash }';
        final ct        = c.type.toComplexType();

        // Defining a component in a family as '_' will skip the variable generation.
        if (varName != '_')
        {
            forExpr.push(macro final $varName = ($i{ tableName }.get($i{ extracted.name }) : $ct));
        }
    }
    for (e in extracted.expr)
    {
        forExpr.push(e);
    }

    return macro @:pos(Context.currentPos()) for ($i{ extracted.name } in $e{ _family }) $b{ forExpr };
}

/**
 * Returns the table variable for a specific component type.
 * This should not be used outside of a system.
 * If the provided type is not used as a component in any of the systems families the behaviour is undefined.
 * 
 * ```
 * final component = table(SomeComponent).get(entity);
 * ```
 * @param _type Type to get the table for.
 */
macro function table(_type : ExprOf<TableType>)
{
    return switch _type.expr
    {
        case EConst(CIdent(s)):
            final resolved  = Context.getType(s);
            final signature = Utils.signature(resolved);

            { expr : EConst(CIdent('table$signature')), pos : Context.currentPos() };
        case _:
            Context.error('Argument must be a type identifier', Context.currentPos());
    }
}

/**
 * Given an expression it will try and extract the EBlock expressions acting as if it is a function expression.
 * It expects an `EMeta(EReturn(EBlock))` expression three.
 * @param _expr Expression to operate on.
 * @return Option<Array<Expr>>
 */
private function extractFunctionBlock(_expr : Expr) : Option<Array<Expr>>
{
    return switch _expr.expr
    {
        case EMeta(_, { expr : EReturn({ expr : EBlock(exprs) }) }):
            Some(exprs);
        case _:
            None;
    }
}

/**
 * Given an identified string, class type, and local variables it will return the type of the identified if it exists in the class or local variables.
 * @param _target Identifier string.
 * @param _classType Class type to check local and static variables.
 * @param _vars Map of local variables to check.
 * @return Option<haxe.macro.Type>
 */
private function isLocalIdent(_target : String, _classType : ClassType, _vars : Map<String, TVar>) : Option<haxe.macro.Type>
{
    final found = _classType.findField(_target).or(_classType.findField(_target, true));

    if (found != null)
    {
        return Some(found.type);
    }

    return if (_vars.exists(_target))
    {
        Some(_vars.get(_target).unsafe().t);
    }
    else
    {
        None;
    }
}

abstract TableType(String) from String to String {
	function new(value) {
		 this = value;
	}
	
	@:from static function fromClass(input:Class<Dynamic>) {
		 return new TableType(Type.getClassName(input));
	}
 }
