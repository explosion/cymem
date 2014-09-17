Cython Memory Helper
--------------------

cymem provides two small memory-management helpers for Cython. They make it
easy to tie memory to a Python object's life-cycle, so that the memory is freed
when the object is garbage collected.

The most useful is cymem.Pool, which acts as a thin wrapper around the calloc
function:

    >>> from cymem.cymem cimport Pool
    >>> mem = Pool()
    >>> data1 = <int*>mem.alloc(10, sizeof(int))
    >>> data2 = <float*>mem.alloc(12, sizeof(float))

The Pool object saves the memory addresses in a vector, and frees them when the
object is garbage collected. Typically you'll attach the Pool to some cdef'd
class. This is particularly handy for deeply nested structs, which have
complicated initialization functions. Just pass the pool object into the
initializer, and you don't have to worry about freeing your struct at all ---
all of the calls to Pool.alloc will be automatically freed when the Pool
expires.
