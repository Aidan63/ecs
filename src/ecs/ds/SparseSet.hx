package ecs.ds;

import haxe.ds.Vector;

/**
 * Sparse set of entities contains both a dense and sparse vector for storage.
 * This allows O(1) insertion, removal, and searching of entities and allows them to be iterated over in a dense array.
 * Entities are not guarenteed to be in the order they were inserted.
 */
class SparseSet
{
    /**
     * Sparse vector which contains indices into the dense vector.
     * Index using an entity to find the corresponding dense vector position.
     */
    final sparse : Vector<Int>;

    /**
     * Packed array of all entity values
     */
    final dense : Vector<Entity>;

    /**
     * Number of entities currently stored in the dense vector.
     */
    var number : Int;

    /**
     * Create a new sparse set of entities.
     * On creation all sparse values point to the first element of the dense array and all dense array values contain -1 (null entity).
     * @param _size Maximum number of entities this set can contain.
     */
    public function new(_size)
    {
        sparse = new Vector(_size);
        dense  = new Vector(_size);
        number = 0;

        for (i in 0...sparse.length)
        {
            sparse[i] = 0;
        }
        for (i in 0...dense.length)
        {
            dense[i] = Entity.none;
        }
    }

    /**
     * Check if the provided entity is stored in the sparse set.
     * @param _entity Entity to check.
     */
    public function has(_entity : Entity)
    {
        return sparse[_entity.id()] < number && dense[sparse[_entity.id()]] == _entity;
    }

    /**
     * Insert an entity into the sparse set.
     * @param _entity Entity to insert.
     */
    public function insert(_entity : Entity)
    {
        dense[number] = _entity;
        sparse[_entity.id()] = number;

        number++;
    }

    /**
     * Removes an entity from the sparse set.
     * Does not check if the entity is in the set before removing.
     * @param _entity Entity to remove.
     */
    public function remove(_entity : Entity)
    {
        final temp = dense[number - 1];
        dense[sparse[_entity.id()]] = temp;
        sparse[temp.id()] = sparse[_entity.id()];

        number--;
    }

    /**
     * Get the entity at the provided dense vector location.
     * @param _idx Dense vector index.
     */
    public function getDense(_idx : Int)
    {
        return dense[_idx];
    }

    /**
     * Get the index into the dense vector that the provided entity is stored in.
     * @param _entity Entity to get index of.
     */
    public function getSparse(_entity : Entity)
    {
        return sparse[_entity.id()];
    }

    /**
     * Number of entity currently stored in the dense vector.
     */
    public function size()
    {
        return number;
    }
}