from distutils.core import setup

import platform

def _parse_version_string(s):
    arr = [int(v) for v in s.split(".")]
    return arr + [0]*(3-len(arr))

def _compare_version_lt(a, b):
    if a[0] < b[0]:
        return True
    elif a[0] > b[0]:
        return False

    if a[1] < b[1]:
        return True
    elif a[1] > b[1]:
        return False

    if a[2] < b[2]:
        return True

    return False

_python_version = _parse_version_string(platform.python_version())

def python_version_lt(a):
    if isinstance(a, str):
        return _compare_version_lt(_python_version, _parse_version_string(a))
    else:
        return _compare_version_lt(_python_version, a)

dependencies = ["spidev>=3.5"]

setup(name='ipq_pynq_utils',
      version='0.1.0',
      packages=['ipq_pynq_utils'],
      author="David Winter",
      author_email="david.winter@student.kit.edu",
      description="Provides helper modules to help with common tasks",
      url="https://github.com/kit-ipq/ipq-pynq-utils/",
      python_requires=">=3.6",
      include_package_data=True,
      install_requires=[
          "spidev>=3.5"
        ],
      classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: BSD License",
        "Operating System :: POSIX :: Linux"
        ]
      )
