Software API
============

This page is the raw, auto-generated API reference -- every public class,
method, and function in ``qick_lib``, with its docstring. For most tasks
you don't need to browse it directly: the narrative pages
(:doc:`/generators`, :doc:`/readout`, :doc:`/tprocv2_trm`, ...) already
link to the specific method you need via cross-references. Come here when
you need the full signature/parameter list for something, or want to see
everything a class exposes at a glance.

The modules are grouped below by what you'd actually reach for them for,
not alphabetically.

Writing programs
-----------------

The classes you subclass and call directly when writing an experiment.
:mod:`qick.asm_v2` is the current tProc v2 API (used throughout this doc
set); :mod:`qick.asm_v1`/:mod:`qick.averager_program` are the legacy tProc
v1 equivalent (see :doc:`/tprocv1`). :mod:`qick.qick_asm` holds the base
classes and methods (``declare_gen``, ``declare_readout``, ``add_pulse``,
``add_envelope``, ...) shared by both.

.. autosummary::
   :toctree: _autosummary

   qick.qick_asm
   qick.asm_v2
   qick.asm_v1
   qick.averager_program

Connecting to the board
-------------------------

.. autosummary::
   :toctree: _autosummary

   qick
   qick.qick
   qick.rfboard
   qick.pyro

:class:`.QickSoc` (:mod:`qick.qick`) is the main entry point -- instantiate
it once, then reach every generator/readout/buffer/tProc driver through its
``soc.gens``/``soc.readouts``/``soc.avg_bufs``/``soc.tproc`` arrays (see
:doc:`/firmware` for what's on your board). :mod:`qick.rfboard` extends it
for boards with an external RF front-end. :mod:`qick.pyro` lets you connect
to a board running headless over the network instead of locally.

Hardware drivers
-------------------

You'll interact with these through the ``soc.gens``/``soc.readouts``/
``soc.avg_bufs``/``soc.tproc`` arrays above, not by importing these
modules directly -- see :doc:`/generators`, :doc:`/readout`, and
:doc:`/tprocv1`/:doc:`/tprocv2_trm` for the driver classes' individual
pages (register maps, RTL cross-references) rather than the bare
docstrings here.

.. autosummary::
   :toctree: _autosummary

   qick.drivers.generator
   qick.drivers.readout
   qick.drivers.tproc

Assembly and compilation internals
-------------------------------------

Normal programs don't call these directly -- :mod:`qick.asm_v2`/
:mod:`qick.asm_v1` invoke them for you. Useful if you're debugging a
compiled program or working with raw assembly text (see
:doc:`topics/asmv2_cheatsheet`).

.. autosummary::
   :toctree: _autosummary

   qick.tprocv2_assembler
   qick.parser

Utilities and framework internals
-------------------------------------

.. autosummary::
   :toctree: _autosummary

   qick.helpers
   qick.streamer
   qick.ip

:mod:`qick.helpers` holds small standalone support functions.
:mod:`qick.streamer` is :class:`.DataStreamer`, a polling thread for
continuous acquisition -- not a driver for a specific IP core (see
:doc:`/support_cores` if you were looking for the ``axis_streamer`` RTL
block instead, a different thing despite the name). :mod:`qick.ip` has the
base :class:`.SocIP`/:class:`.QickIP` driver classes and the board metadata
tracing every driver's ``configure_connections()`` uses -- framework
internals, only relevant if you're writing a new driver.
