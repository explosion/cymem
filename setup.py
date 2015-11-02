#!/usr/bin/env python

import shutil
import sys
import os
from os import path

from setuptools import setup
from setuptools import Extension
from distutils import sysconfig
from distutils.core import setup, Extension
from distutils.command.build_ext import build_ext


# By subclassing build_extensions we have the actual compiler that will be used which is really known only after finalize_options
# http://stackoverflow.com/questions/724664/python-distutils-how-to-get-a-compiler-that-is-going-to-be-used
compile_options =  {'msvc'  : ['/Ox']  ,
                    'other' : ['-O3', '-Wno-strict-prototypes', '-Wno-unused-function']       }
link_options    =  {'msvc'  : [] ,
                    'other' : [] }
# Using 
#     compile_options 'msvc'  : ['/Zi','/Od']  
#     link_options    'msvc'  : ['/DEBUG']
# will provide for PDB fie that can be used in Visual Studio for mixed-mode (native code/Python) debugging


class build_ext_options:
    def build_options(self):
        c_type = None
        if self.compiler.compiler_type in compile_options:
            c_type = self.compiler.compiler_type
        elif 'other' in compile_options:
            c_type = 'other'
        if c_type is not None:
           for e in self.extensions:
               e.extra_compile_args = compile_options[c_type]

        l_type = None 
        if self.compiler.compiler_type in link_options:
            l_type = self.compiler.compiler_type
        elif 'other' in link_options:
            l_type = 'other'
        if l_type is not None:
           for e in self.extensions:
               e.extra_link_args = link_options[l_type]

class build_ext_subclass( build_ext, build_ext_options ):
    def build_extensions(self):
        build_ext_options.build_options(self)
        build_ext.build_extensions(self)
        



def clean(ext):
    for src in ext.sources:
        if src.endswith('.c') or src.endswith('cpp'):
            so = src.rsplit('.', 1)[0] + '.so'
            html = src.rsplit('.', 1)[0] + '.html'
            if os.path.exists(so):
                os.unlink(so)
            if os.path.exists(html):
                os.unlink(html)


def name_to_path(mod_name, ext):
    return '%s.%s' % (mod_name.replace('.', '/'), ext)


def c_ext(mod_name, language, includes):
    mod_path = name_to_path(mod_name, language)
    return Extension(mod_name, [mod_path], include_dirs=includes)



def cython_setup(mod_names, language, includes):
    import Cython.Distutils
    import Cython.Build
    import distutils.core

    class build_ext_cython_subclass( Cython.Distutils.build_ext, build_ext_options ):
        def build_extensions(self):
            build_ext_options.build_options(self)
            Cython.Distutils.build_ext.build_extensions(self)

    exts = []
    for mod_name in mod_names:
        mod_path = mod_name.replace('.', '/') + '.pyx'
        e = Extension(mod_name, [mod_path], language=language, include_dirs=includes)
        exts.append(e)
    distutils.core.setup(
        name="cymem",
        packages=["cymem"],
        version=VERSION,
        author="Matthew Honnibal",
        author_email="honnibal@gmail.com",
        url="http://github.com/syllog1sm/cymem",
        package_data={"cymem": ["*.pxd", "*.pyx", "*.c"]},
        ext_modules=exts,
        cmdclass={'build_ext': build_ext_cython_subclass},
        license="MIT",
    )


def run_setup(exts):
    setup(
        ext_modules=exts,
        name="cymem",
        packages=["cymem"],
        version=VERSION,
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
        cmdclass = {'build_ext': build_ext_subclass },
    )

def main(modules, is_pypy):
    language = "c"
    includes = ['.', path.join(sys.prefix, 'include')]
    if use_cython:
        cython_setup(modules, language, includes)
    else:
        exts = [c_ext(mn, language, includes)
                      for mn in modules]
        run_setup(exts)

MOD_NAMES = ['cymem.cymem']
VERSION = '1.3.1'

if __name__ == '__main__':
    use_cython = sys.argv[1] == 'build_ext'
    main(MOD_NAMES, use_cython)
