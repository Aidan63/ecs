package ecs;

abstract Entity(Int) {
    public inline function new(_id) {
        this = _id;
    }
}