from cpython.mem cimport PyMem_Malloc, PyMem_Realloc, PyMem_Free
from libc.string cimport memset


cdef class Pool:
    """Track allocated memory addresses, and free them all when the Pool is
    garbage collected.  This provides an easy way to avoid memory leaks, and 
    removes the need for deallocation functions for complicated structs.

    Attributes:
        size (size_t): The current size (in bytes) allocated by the pool.
        addresses (set): The set of currently allocated addresses. Read-only.
    """
    def __cinit__(self):
        self.size = 0
        self.addresses = set()

    def __dealloc__(self):
        cdef size_t addr
        for addr in self.addresses:
            PyMem_Free(<void*>addr)

    cdef void* alloc(self, size_t number, size_t size) except NULL:
        """Allocate a 0-initialized number*size-byte block of memory, and remember
        its address. The block will be freed when the Pool is garbage collected.
        """
        cdef void* p = PyMem_Malloc(number * size)
        memset(p, 0, number * size)
        self.addresses.add(<size_t>p)
        self.size += number * size
        return p

    cdef void* realloc(self, void* p, size_t n) except NULL:
        """Resizes the memory block pointed to by p to n bytes, returning a
        non-NULL pointer to the new block. The contents will be unchanged to the
        minimum of the old and the new sizes.
        
        If p is not in the Pool or n is 0, a MemoryError is raised. If p is not
        found in the Pool, a KeyError is raised. If the call to PyMem_Realloc
        fails, a MemoryError is raised.
        """
        cdef size_t addr
        if addr not in self.addresses:
            raise MemoryError("Pointer %d not found in Pool %s" % (<size_t>p, self.addresses))
        if n == 0:
            raise MemoryError("Realloc requires n > 0")
        self.addresses.remove(addr)
        cdef void* new_p = PyMem_Realloc(p, n)
        if new_p == NULL:
            raise MemoryError("Failed to resize pointer %d to %d bytes" % (<size_t>p, <size_t>n))
        self.addresses.add(<size_t>new_p)
        return new_p

    cdef void* free(self, void* p) except NULL:
        """Frees the memory block pointed to by p, which must have been returned
        by a previous call to Pool.alloc.  You should not normally need to free
        memory addresses manually --- it will usually be sufficient to let the
        Pool be garbage collected, at which point all the memory will be freed.
        
        If p is not in Pool.addresses, a KeyError is raised.
        """
        self.addresses.remove(<size_t>p)
        PyMem_Free(p)


cdef class Address:
    def __cinit__(self, size_t number, size_t size):
        cdef void* addr = PyMem_Malloc(number * size)
        memset(addr, 0, number * size)
        self.addr = <size_t>addr

    def __dealloc__(self):
        PyMem_Free(<void*>self.addr)
