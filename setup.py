#!/usr/bin/env python
from __future__ import print_function
import io
import os
import sys
import contextlib
from setuptools import Extension, setup, find_packages
from distutils.command.build_ext import build_ext
from distutils.sysconfig import get_python_inc
from Cython.Build import cythonize


PACKAGES = find_packages()
MOD_NAMES = ["cymem.cymem"]


# By subclassing build_extensions we have the actual compiler that will be used which is really known only after finalize_options
# http://stackoverflow.com/questions/724664/python-distutils-how-to-get-a-compiler-that-is-going-to-be-used
compile_options = {
    "msvc": ["/Ox", "/EHsc"],
    "other": ["-O3", "-Wno-strict-prototypes", "-Wno-unused-function"],
}
link_options = {"msvc": [], "other": []}


class build_ext_options:
    def build_options(self):
        for e in self.extensions:
            e.extra_compile_args = compile_options.get(
                self.compiler.compiler_type, compile_options["other"]
            )
        for e in self.extensions:
            e.extra_link_args = link_options.get(
                self.compiler.compiler_type, link_options["other"]
            )


class build_ext_subclass(build_ext, build_ext_options):
    def build_extensions(self):
        build_ext_options.build_options(self)
        build_ext.build_extensions(self)


def clean(path):
    for name in MOD_NAMES:
        name = name.replace(".", "/")
        for ext in [".so", ".html", ".cpp", ".c"]:
            file_path = os.path.join(path, name + ext)
            if os.path.exists(file_path):
                os.unlink(file_path)


@contextlib.contextmanager
def chdir(new_dir):
    old_dir = os.getcwd()
    try:
        os.chdir(new_dir)
        sys.path.insert(0, new_dir)
        yield
    finally:
        del sys.path[0]
        os.chdir(old_dir)


def setup_package():
    root = os.path.abspath(os.path.dirname(__file__))

    if len(sys.argv) > 1 and sys.argv[1] == "clean":
        return clean(root)

    with chdir(root):
        with io.open(os.path.join(root, "cymem", "about.py"), encoding="utf8") as f:
            about = {}
            exec(f.read(), about)

        with io.open(os.path.join(root, "README.md"), encoding="utf8") as f:
            readme = f.read()

        include_dirs = [get_python_inc(plat_specific=True)]

        ext_modules = []
        for mod_name in MOD_NAMES:
            mod_path = mod_name.replace(".", "/") + ".pyx"
            ext_modules.append(
                Extension(
                    mod_name, [mod_path], language="c++", include_dirs=include_dirs
                )
            )

        setup(
            name="cymem",
            zip_safe=False,
            packages=PACKAGES,
            package_data={"": ["*.pyx", "*.pxd"]},
            description=about["__summary__"],
            long_description=readme,
            long_description_content_type="text/markdown",
            author=about["__author__"],
            author_email=about["__email__"],
            version=about["__version__"],
            url=about["__uri__"],
            license=about["__license__"],
            ext_modules=cythonize(ext_modules, language_level=2),
            setup_requires=["cython>=0.25"],
            classifiers=[
                "Environment :: Console",
                "Intended Audience :: Developers",
                "Intended Audience :: Science/Research",
                "License :: OSI Approved :: MIT License",
                "Operating System :: POSIX :: Linux",
                "Operating System :: MacOS :: MacOS X",
                "Operating System :: Microsoft :: Windows",
                "Programming Language :: Cython",
                "Programming Language :: Python :: 2.6",
                "Programming Language :: Python :: 2.7",
                "Programming Language :: Python :: 3.3",
                "Programming Language :: Python :: 3.4",
                "Programming Language :: Python :: 3.5",
                "Programming Language :: Python :: 3.6",
                "Programming Language :: Python :: 3.7",
                "Programming Language :: Python :: 3.8",
                "Programming Language :: Python :: 3.9",
                "Programming Language :: Python :: 3.10",
                "Programming Language :: Python :: 3.11",
                "Topic :: Scientific/Engineering",
            ],
            cmdclass={"build_ext": build_ext_subclass},
        )


if __name__ == "__main__":
    setup_package()
