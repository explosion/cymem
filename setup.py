#!/usr/bin/env python
from distutils.core import setup
from Cython.Build import cythonize
from Cython.Distutils import Extension


import sys
import os
from os.path import splitext

from distutils.sysconfig import get_python_inc

exts = [Extension("cymem.cymem", ["cymem/cymem.pyx"])]

setup(
    ext_modules=cythonize(exts),
    name="cymem",
    packages=["cymem"],
    version="1.0",
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
