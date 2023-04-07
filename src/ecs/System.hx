package ecs;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
import ecs.macros.Utils;
import ecs.macros.FamilyCache;
import ecs.macros.ResourceCache;
import ecs.macros.UniverseMacros;

using haxe.macro.Tools;
#end

using Safety;

@:autoBuild(ecs.macros.SystemMacros.familyConstruction()) class System
{
	final universe : Universe;

	public function new(_universe)
	{
		universe = _universe;
	}

	public function onEnabled()
	{
		//
	}

	public function update(_dt : Float)
	{
		//
	}

	public function onDisabled()
	{
		//
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
	@:ignoreInstrument macro function setup(_this : Expr, _families : ExprOf<Family>, _function : Expr)
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
		
		// Add a final 0 expr to make non exhaustive if checks acceptable as the last expr in the block.
		extracted.push(macro 0);
		
		// Insert variable declarations to the top of the extracted function block.
		// TODO : should probably check to make sure there are no type or name collisions.
		for (ident in familiesToSetup)
		{
			final clsKey = '${ signature(Context.getLocalType()) }-${ ident }';
			switch getFamilyByKey(clsKey)
			{
				case Some(family):
	
					for (resource in family.resources)
					{
						if (resource.name != '_')
						{
							final signature = signature(resource.type);
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
	@:ignoreInstrument macro function iterate(_this : Expr, _family : ExprOf<Family>, _function : Expr)
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
		final clsKey     = '${ signature(Context.getLocalType()) }-${ familyIdent }';
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
		
		// Add a final 0 expr to make non exhaustive if checks acceptable as the last expr in the block.
		forExpr.push(macro 0);
	
		return macro @:pos(Context.currentPos()) for ($i{ extracted.name } in $e{ _family }) $b{ forExpr };
	}
	
	/**
	 * The fetch macro allows you to operate on the components of a specific entity.
	 * it automates the process of getting the components using the names provided when defining the family.
	 * 
	 * ```
	 * fetch(someFamily, someEntity, {
	 *     // code here will only be executed if someEntity is in the specified family.
	 * })
	 * ```
	 */
	@:ignoreInstrument macro function fetch(_this : Expr, _family : ExprOf<Family>, _entity : ExprOf<Entity>, _function : Expr)
	{
		final familyIdent = switch _family.expr
		{
			case EConst(CIdent(s)): s;
			case _: Context.error('Family passed into fetch must be an identifier', _family.pos);
		}

		final entityIdent = switch _entity.expr
		{
			case EConst(CIdent(s)): s;
			case _: Context.error('Entity passed into fetch must be an identifier', _entity.pos);
		}

		final blockExprs = switch _function.expr
		{
			case EBlock(exprs): _function;
			case _: Context.error('fetch function must be a code block', _function.pos);
		}

		final clsKey     = '${ signature(Context.getLocalType()) }-${ familyIdent }';
		final components = switch getFamilyByKey(clsKey)
		{
			case Some(family): family.components;
			case None: Context.error('Unable to find a family with the key $clsKey', _family.pos);
		}

		final forExpr = [];
		for (c in components)
		{
			final varName   = c.name;
			final tableName = 'table${ c.hash }';
			final ct        = c.type.toComplexType();
	
			// Defining a component in a family as '_' will skip the variable generation.
			if (varName != '_')
			{
				forExpr.push(macro final $varName = ($i{ tableName }.get($e{ _entity }) : $ct));
			}
		}
		forExpr.push(blockExprs);

		// Add a final 0 expr to make non exhaustive if checks acceptable as the last expr in the block.
		forExpr.push(macro 0);

		return macro {
			if ($e{ _family }.has($e{ _entity }))
			{
				@:mergeBlock $b{ forExpr }
			}
		};
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
	@:ignoreInstrument macro function table(_this : Expr, _type : ExprOf<TableType>)
	{
		Context.warning('table is unsafe and will be removed in a future version, use fetch instead', Context.currentPos());

		return switch _type.expr
		{
			case EConst(CIdent(s)):
				final resolved  = Context.getType(s);
				final signature = signature(resolved);
	
				{ expr : EConst(CIdent('table$signature')), pos : Context.currentPos() };
			case _:
				Context.error('Argument must be a type identifier', Context.currentPos());
		}
	}
}
