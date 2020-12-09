package;

import ecs.Entity;
import ecs.ds.SparseSet;
import buddy.BuddySuite;

using buddy.Should;

class SparseSetTests extends BuddySuite
{
    public function new()
    {
        describe('sparse set tests', {
            describe('adding entities', {
                final ent = new Entity(2);
                final set = new SparseSet(8);

                set.insert(ent);

                it('will return the number of entities in the set', {
                    set.size().should.be(1);
                });

                it('will return that the entity is in the set', {
                    set.has(ent).should.be(true);
                });

                it('will return the dense array index of the entity', {
                    set.getDense(set.getSparse(ent)).should.be(ent);
                });
            });
            describe('removing entities', {
                final ent = new Entity(2);
                final set = new SparseSet(8);

                set.insert(ent);
                set.remove(ent);

                it('will return the number of entities in the set', {
                    set.size().should.be(0);
                });

                it('will return if an entity is in the set', {
                    set.has(ent).should.be(false);
                });
            });
        });
    }
}