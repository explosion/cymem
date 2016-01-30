#!/usr/bin/env python
from distutils.core import setup

try:
    from Cython.Build import cythonize
    from Cython.Distutils import Extension
    exts = cythonize([Extension("cymem.cymem", ["cymem/cymem.pyx"])])
except ImportError:
    from distutils.extension import Extension
    exts = [Extension("cymem.cymem", ["cymem/cymem.c"])]


import sys
import os
from os.path import splitext


setup(
    ext_modules=exts,

    name="cymem",
    packages=["cymem"],
    version="1.31.0",
    author="Matthew Honnibal",
    author_email="honnibal@gmail.com",
    url="http://github.com/syllog1sm/cymem",
    package_data={"cymem": ["*.pxd", "*.pyx", "*.c"]},
    description="""Manage calls to calloc/free through Cython""",
    classifiers=[
                'Environment :: Console',
                'Operating System :: OS Independent',
                'Intended Audience :: Science/Research',
                'Programming Language :: Cython',
                'Topic :: Scientific/Engineering'],
)
