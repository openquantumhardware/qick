from distutils.core import setup

setup(name='ipq_pynq_utils',
      version='0.1.0',
      packages=['ipq_pynq_utils'],
      author="David Winter",
      author_email="david.winter@student.kit.edu",
      description="Provides helper modules to help with common tasks",
      url="https://github.com/kit-ipq/ipq-pynq-utils/",
      python_requires=">=3.6",
      include_package_data=True,
      install_requires=[],
      classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: BSD License",
        "Operating System :: POSIX :: Linux"
        ]
      )
