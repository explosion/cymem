cdef struct _Memory:
    void* ptr
    size_t size

cdef class Pool:
    cdef _Memory* _addresses
    cdef size_t _resize_at
    cdef size_t _length

    cdef void* alloc(self, size_t number, size_t size) except NULL
    cdef void free(self, void* addr) except *
    cdef void* realloc(self, void* addr, size_t n) except NULL

    cdef int _resize(self) except -1


cdef class Address:
    cdef void* ptr
