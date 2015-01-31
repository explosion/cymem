# cython: embedsignature=True

from cpython.mem cimport PyMem_Malloc, PyMem_Realloc, PyMem_Free
from libc.string cimport memset
from libc.string cimport memcpy, memmove


cdef class Pool:
    """Track allocated memory addresses, and free them all when the Pool is
    garbage collected.  This provides an easy way to avoid memory leaks, and 
    removes the need for deallocation functions for complicated structs.

    >>> from cymem.cymem cimport Pool
    >>> cdef Pool mem = Pool()
    >>> data1 = <int*>mem.alloc(10, sizeof(int))
    >>> data2 = <float*>mem.alloc(12, sizeof(float))

    Attributes:
        size (size_t): The current size (in bytes) allocated by the pool.
        addresses (dict): The currently allocated addresses and their sizes. Read-only.
    """
    def __cinit__(self):
        self._resize_at = 8
        self._length = 0
        self._addresses = <_Memory*>PyMem_Malloc(self._resize_at * sizeof(_Memory))
        for i in range(self._resize_at):
            self._addresses[i].ptr = NULL
            self._addresses[i].size = 0

    def __dealloc__(self):
        if self._addresses is not NULL:
            for i in range(self._length):
                if self._addresses[i].ptr is not NULL:
                    PyMem_Free(self._addresses[i].ptr)
            PyMem_Free(self._addresses)

    cdef void* alloc(self, size_t number, size_t elem_size) except NULL:
        """Allocate a 0-initialized number*elem_size-byte block of memory, and
        remember its address. The block will be freed when the Pool is garbage
        collected.
        """
        cdef void* p = PyMem_Malloc(number * elem_size)
        assert p is not NULL
        memset(p, 0, number * elem_size)
        cdef int i, index
        for i in range(self._length):
            if self._addresses[i].ptr == NULL:
                index = i
                break
        else:
            index = self._length
            self._length += 1
        self._addresses[index].ptr = p
        self._addresses[index].size = number * elem_size
        if self._length == self._resize_at:
            self._resize()
        return p

    cdef void* realloc(self, void* p, size_t new_size) except NULL:
        """Resizes the memory block pointed to by p to new_size bytes, returning
        a non-NULL pointer to the new block. new_size must be larger than the
        original.
        
        If p is not in the Pool or new_size is 0, a MemoryError is raised.
        """
        if new_size == 0:
            raise MemoryError("Realloc requires new_size > 0")
        cdef void* new = self.alloc(1, new_size)
        cdef int i
        cdef size_t size
        for i in range(self._length):
            if self._addresses[i].ptr == p:
                size = self._addresses[i].size
                self._addresses[i].ptr = NULL
                self._addresses[i].size = 0
                break
        else:
            raise MemoryError("Pointer %d not found in Pool" % <size_t>p)
        memcpy(new, p, size)
        PyMem_Free(p)
        return new

    cdef void free(self, void* p) except *:
        """Frees the memory block pointed to by p, which must have been returned
        by a previous call to Pool.alloc.  You don't necessarily need to free
        memory addresses manually --- you can instead let the Pool be garbage
        collected, at which point all the memory will be freed.
        
        If p is not in Pool.addresses, a KeyError is raised.
        """
        for i in range(self._length):
            if self._addresses[i].ptr == p:
                self._addresses[i].ptr = NULL
                self._addresses[i].size = 0
                break
        else:
            raise KeyError(<size_t>p)
        PyMem_Free(p)

    cdef int _resize(self) except -1:
        self._resize_at *= 2
        new_addresses = <_Memory*>PyMem_Malloc(self._resize_at * sizeof(_Memory))
        for i in range(self._length):
            new_addresses[i].ptr = self._addresses[i].ptr
            new_addresses[i].size = self._addresses[i].size
        PyMem_Free(self._addresses)
        self._addresses = new_addresses
        for i in range(self._length, self._resize_at):
            self._addresses[i].ptr = NULL
            self._addresses[i].size = 0


cdef class Address:
    """A block of number * size-bytes of 0-initialized memory, tied to a Python
    ref-counted object. When the object is garbage collected, the memory is freed.

    >>> from cymem.cymem cimport Address
    >>> cdef Address address = Address(10, sizeof(double))
    >>> d10 = <double*>address.ptr

    Args:
        number (size_t): The number of elements in the memory block.
        elem_size (size_t): The size of each element.

    Attributes:
        ptr (void*): Pointer to the memory block.
        addr (size_t): Read-only size_t cast of the pointer.
    """
    def __cinit__(self, size_t number, size_t elem_size):
        self.ptr = NULL

    def __init__(self, size_t number, size_t elem_size):
        self.ptr = PyMem_Malloc(number * elem_size)
        memset(self.ptr, 0, number * elem_size)

    property addr:
        def __get__(self):
            return <size_t>self.ptr

    def __dealloc__(self):
        PyMem_Free(self.ptr)
