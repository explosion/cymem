#!/usr/bin/env python
from distutils.core import setup
from Cython.Build import cythonize
from Cython.Distutils import Extension


import sys
import os
from os.path import splitext

from distutils.sysconfig import get_python_inc

exts = [Extension("cymem.cymem", ["cymem/cymem.pyx"], language="c++")]

setup(
    ext_modules=cythonize(exts),
    name="cymem",
    packages=["cymem"],
    version="0.3",
    author="Matthew Honnibal",
    author_email="honnibal@gmail.com",
    url="http://github.com/syllog1sm/cymem",
    package_data={"cymem": ["*.pxd", "*.pyx", "*.cpp"]},
    description="""Manage calls to malloc/free through Cython""",
    classifiers=3
                'Environment :: Console',
                'Operating System :: OS Independent',
                'Intended Audience :: Science/Research',
                'Programming Language :: Cython',
                'Topic :: Scientific/Engineering'],
)
