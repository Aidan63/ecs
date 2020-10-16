package ecs.macros;

import ecs.macros.ResourceCache;

macro function createResourceVector()
{
    return macro new haxe.ds.Vector($v{ getResourceCount() });
}

macro function createResourceBits()
{
    return macro new bits.Bits($v{ getResourceCount() });
}