package ecs.macros;

import sys.FileSystem;
import haxe.io.Path;
import haxe.macro.Type;
import haxe.crypto.Md5;

using haxe.macro.TypeTools;
using haxe.macro.ComplexTypeTools;

private var invalidationFile : String;

/**
 * Calculates a string hash of the given type.
 * @param _type Type to hash.
 */
function signature(_type : Type)
{
    return Md5.encode(_type.toString());
}

function setInvalidationFile(_output : String)
{
    final file = '.ecs_invalidation';

    invalidationFile = if ('' == Path.extension(_output))
    {
        Path.join([ _output, file ]);
    }
    else
    {
        Path.join([ Path.directory(_output), file ]);
    }

    if (!FileSystem.exists(Path.directory(invalidationFile)))
    {
        FileSystem.createDirectory(Path.directory(invalidationFile));
    }
}

function getInvalidationFile()
{
    return invalidationFile;
}