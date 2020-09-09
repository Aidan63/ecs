package ecs.ds;

enum Result<T, E>
{
    Ok(data : T);
    Error(error : E);
}