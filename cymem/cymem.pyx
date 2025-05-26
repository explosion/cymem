# cython: embedsignature=True

from cpython.mem cimport PyMem_Malloc, PyMem_Free
from cpython.ref cimport Py_INCREF, Py_DECREF
from libc.string cimport memset
from libc.string cimport memcpy
import warnings

WARN_ZERO_ALLOC = False

cdef bint CYTHON_FREE_THREADING

IF CYTHON_FREE_THREADING:
    from libcpp.mutex cimport once_flag, call_once
    cdef once_flag _lazy_import_lock

cdef class PyMalloc:
    cdef void _set(self, malloc_t malloc):
        self.malloc = malloc

cdef PyMalloc WrapMalloc(malloc_t malloc):
    cdef PyMalloc o = PyMalloc()
    o._set(malloc)
    return o

cdef class PyCalloc:
    cdef void _set(self, calloc_t calloc):
        self.calloc = calloc

cdef PyCalloc WrapCalloc(calloc_t calloc):
    cdef PyCalloc o = PyCalloc()
    o._set(calloc)
    return o

cdef class PyRealloc:
    cdef void _set(self, realloc_t realloc):
        self.realloc = realloc

cdef PyRealloc WrapRealloc(realloc_t realloc):
    cdef PyRealloc o = PyRealloc()
    o._set(realloc)
    return o

cdef class PyFree:
    cdef void _set(self, free_t free):
        self.free = free

cdef PyFree WrapFree(free_t free):
    cdef PyFree o = PyFree()
    o._set(free)
    return o

Default_Malloc = WrapMalloc(PyMem_Malloc)
Default_Calloc = WrapCalloc(PyMem_Calloc)
Default_Realloc = WrapRealloc(PyMem_Realloc)
Default_Free = WrapFree(PyMem_Free)

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
        pymalloc (PyMalloc): The allocator to use (default uses PyMem_Malloc).
        pycalloc (PyCalloc): The allocator to use (default uses PyMem_Calloc).
        pyrealloc (PyRealloc): The allocator to use (default uses PyMem_Realloc).
        pyfree (PyFree): The free to use (default uses PyMem_Free).
    """

    def __cinit__(self, PyMalloc pymalloc=Default_Malloc,
                  PyCalloc pycalloc = Default_Calloc,
                  PyRealloc pyrealloc = Default_Realloc,
                  PyFree pyfree=Default_Free):
        self.size = 0
        self.addresses = {}
        self.refs = []
        self.pymalloc = pymalloc
        self.pycalloc = pycalloc
        self.pyrealloc = pyrealloc
        self.pyfree = pyfree

    def __dealloc__(self):
        cdef size_t addr
        if self.addresses is not None:
            for addr in self.addresses:
                if addr != 0:
                    self.pyfree.free(<void*>addr)

    cdef void* alloc(self, size_t number, size_t elem_size) except NULL:
        """Allocate a 0-initialized number*elem_size-byte block of memory, and
        remember its address. The block will be freed when the Pool is garbage
        collected. Throw warning when allocating zero-length size and 
        WARN_ZERO_ALLOC was set to True.
        """
        if WARN_ZERO_ALLOC and (number == 0 or elem_size == 0):
            warnings.warn("Allocating zero bytes")
        cdef void* p = self.pycalloc.calloc(number * elem_size)
        if p == NULL:
            raise MemoryError("Error assigning %d bytes" % (number * elem_size))
        self.addresses[<size_t>p] = number * elem_size
        self.size += number * elem_size
        return p

    cdef void* realloc(self, void* p, size_t new_size) except NULL:
        """Resizes the memory block pointed to by p to new_size bytes, returning
        a non-NULL pointer to the new block. new_size must be larger than the
        original.

        If p is not in the Pool or new_size is 0, a MemoryError is raised.
        """
        cdef void* p_new
        if <size_t>p not in self.addresses:
            raise ValueError("Pointer %d not found in Pool %s" % (<size_t>p, self.addresses))
        if new_size == 0:
            raise ValueError("Realloc requires new_size > 0")
        assert new_size > self.addresses[<size_t>p]
        old_size_val = self.addresses[<size_t>p]
        p_new = self.pyrealloc.realloc(p, new_size)
        if p_new == NULL:
            raise MemoryError("Error reallocating to %d bytes" % new_size)
        # Resize in place
        self.addresses.pop(<size_t>p_old)
        self.addresses[<size_t>p_new] = new_size
        self.size = (self.size - old_size_val) + new_size
        return p_new

    cdef void free(self, void* p) except *:
        """Frees the memory block pointed to by p, which must have been returned
        by a previous call to Pool.alloc.  You don't necessarily need to free
        memory addresses manually --- you can instead let the Pool be garbage
        collected, at which point all the memory will be freed.

        If p is not in Pool.addresses, a KeyError is raised.
        """
        self.size -= self.addresses.pop(<size_t>p)
        self.pyfree.free(p)

    def own_pyref(self, object py_ref):
        self.refs.append(py_ref)


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
        pymalloc (PyMalloc): The allocator to use (default uses PyMem_Malloc).
        pyfree (PyFree): The free to use (default uses PyMem_Free).
    """
    def __cinit__(self, size_t number, size_t elem_size,
                  PyMalloc pymalloc=Default_Malloc, PyFree pyfree=Default_Free):
        self.ptr = NULL
        self.pymalloc = pymalloc
        self.pyfree = pyfree

    def __init__(self, size_t number, size_t elem_size):
        self.ptr = self.pymalloc.malloc(number * elem_size)
        if self.ptr == NULL:
            raise MemoryError("Error assigning %d bytes" % number * elem_size)
        memset(self.ptr, 0, number * elem_size)

    property addr:
        def __get__(self):
            return <size_t>self.ptr

    def __dealloc__(self):
        if self.ptr != NULL:
            self.pyfree.free(self.ptr)
