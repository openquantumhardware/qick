#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# QICK documentation build configuration file
#
# This file is execfile()d with the current directory set to its
# containing dir.

import sys
import os
import pathlib
import shutil

#Check if Pandoc is installed
if shutil.which('pandoc') is None:
    import warnings
    warnings.warn(
        "pandoc not found. Install it with: sudo apt install pandoc (Linux) "
        "or brew install pandoc (macOS). Required for notebook conversion."
    )

# -- Path setup --------------------------------------------------------------

# Make your modules available in sys.path
here = pathlib.Path(__file__).parent.resolve()
sys.path.insert(0, (here / '../../qick_lib').resolve().as_posix())
print(f"Python path: {sys.path[0]}")

def get_version(rel_path):
    """
    qick_lib/qick/VERSION is a text file containing only the version number.
    """
    return (here / rel_path).read_text().strip()

# -- Project information -----------------------------------------------------

project = 'QICK'
copyright = 'OpenQuantumHardware'
author = 'OpenQuantumHardware'

# The short X.Y version.
version = get_version("../../qick_lib/qick/VERSION")
# The full version, including alpha/beta/rc tags.
release = version

# -- General configuration ---------------------------------------------------

# Add any Sphinx extension module names here
extensions = [
    'sphinx.ext.autodoc',
    'sphinx.ext.viewcode',
    'sphinx.ext.intersphinx',
    'sphinx.ext.mathjax',
    'sphinx.ext.autosummary',
    'sphinx.ext.napoleon',
    'sphinx.ext.extlinks',
    'nbsphinx',                      # For Jupyter notebooks
    'myst_parser',                   # For Markdown files
]

# nbsphinx configuration
nbsphinx_execute = 'never'           # Don't execute notebooks during build
nbsphinx_allow_errors = True         # Continue even if notebooks have errors
nbsphinx_timeout = 120               # Timeout for notebook execution (seconds)

# autodoc configuration
autodoc_member_order = 'bysource'
autodoc_default_options = {
    'members': True,
    'show-inheritance': True,
    'special-members': '__init__',
    'undoc-members': True,
    'exclude-members': '__weakref__'
}

# Mock imports for modules that are not available during documentation build
autodoc_mock_imports = ["pynq", "xrfclk", "xrfdc", "cffi", "Pyro4", "psutil"]

# Generate autodoc stubs with summaries from code
autosummary_generate = True

# Add any paths that contain templates here
templates_path = ['_templates']

# The suffix(es) of source filenames
source_suffix = {
    '.rst': 'restructuredtext',
    '.md': 'markdown',
    #'.ipynb': 'jupyter_notebooks',
}

# The master toctree document
master_doc = 'index'

# The language for content
language = 'en'

# List of patterns to ignore when looking for source files
exclude_patterns = [
    '_build',
    'Thumbs.db',
    '.DS_Store',
    '**.ipynb_checkpoints',  # Exclude Jupyter checkpoint files
]

# The name of the Pygments (syntax highlighting) style
pygments_style = 'sphinx'

# -- Options for HTML output -------------------------------------------------

# The theme to use for HTML pages
html_theme = 'sphinx_rtd_theme'

# Theme options
html_theme_options = {
    'logo_only': True,
    'navigation_depth': 4,
}

# The name of an image file to place at the top of the sidebar
html_logo = "../../graphics/logoQICK.svg"

# Add any paths that contain custom static files
html_static_path = ['_static']

# Custom CSS files
html_css_files = ['custom.css']

# If true, links to the reST sources are added to the pages
html_show_sourcelink = True

# If true, "Created using Sphinx" is shown in the HTML footer
html_show_sphinx = True

# If true, "(C) Copyright ..." is shown in the HTML footer
html_show_copyright = True

# Output file base name for HTML help builder
htmlhelp_basename = 'QICKdoc'

# -- Options for LaTeX output ------------------------------------------------

latex_elements = {
    'papersize': 'letterpaper',
    'pointsize': '10pt',
    'figure_align': 'htbp',
}

# Grouping the document tree into LaTeX files
latex_documents = [
    (master_doc, 'QICK.tex', 'QICK Documentation',
     author, 'manual'),
]

# -- Options for manual page output ------------------------------------------

man_pages = [
    (master_doc, 'qick', 'QICK Documentation',
     [author], 1)
]

# -- Options for Texinfo output ----------------------------------------------

texinfo_documents = [
    (master_doc, 'QICK', 'QICK Documentation',
     author, 'QICK', 'Quantum Instrumentation Control Kit',
     'Miscellaneous'),
]

# -- Intersphinx configuration -----------------------------------------------

intersphinx_mapping = {
    'python': ('https://docs.python.org/3.10', None),
    'numpy': ('https://numpy.org/doc/stable', None),
    'pynq': ('https://pynq.readthedocs.io/en/latest', None),
}

# -- Extlinks configuration --------------------------------------------------

extlinks = {
    'repofile': ('https://github.com/openquantumhardware/qick/blob/main/%s', '%s'),
}

extlinks_detect_hardcoded_links = True

# -- Linkcheck configuration ------------------------------------------------

linkcheck_ignore = [
    r'^https://blogs.keysight.com/',  # gives 403 error
    r'^http://localhost',              # ignore local servers
]

# -- Custom CSS -------------------------------------------------------------

def setup(app):
    app.add_css_file("custom.css")
