from distutils.core import setup
from ipq_pynq_utils import utils

dependencies = ["spidev>=3.5"]

if utils.python_version_lt("3.10"):
    dependencies.append("importlib_resources")

setup(name='ipq_pynq_utils',
      version='0.1.0',
      packages=['ipq_pynq_utils'],
      author="David Winter",
      author_email="david.winter@student.kit.edu",
      description="Provides helper modules to help with common tasks",
      url="https://git.scc.kit.edu/ipq_systemgroup/fpga/ipq_pynq_utils",
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
