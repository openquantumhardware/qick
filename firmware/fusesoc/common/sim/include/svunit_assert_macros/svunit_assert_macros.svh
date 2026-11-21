///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : svunit_assert_macros
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    svunit_assert_macros.svh
//!
//! @brief   SystemVerilog assertions that fail the running SVUnit test.
//!
//! @details
//!
//! `ASSERT_IMMEDIATE(expr)` and `ASSERT_IMMEDIATE_LOG(expr, msg)` wrap an
//! immediate `assert`; `ASSERT_CONCURRENT(prop)` and
//! `ASSERT_CONCURRENT_LOG(prop, msg)` wrap `assert property`. When the check
//! fails, the failure is recorded in the SVUnit testcase that is running, with
//! the checked text, file and line (and msg), and that test ends there: what
//! follows a failed check only repeats its cause.
//!
//! Each macro is defined only if nobody defined it before, so a testbench can
//! override one.
//!
//! @author  QICK Development Team
//!
//! @version 1.1

`ifndef QICK_SVUNIT_ASSERT_MACROS_SVH
`define QICK_SVUNIT_ASSERT_MACROS_SVH

// Common failure path of the four macros below.
`define QICK_ASSERT_FAILED(KIND, TEXT, MSG) \
  begin \
    void'(svunit_pkg::current_tc.fail(KIND, 1'b1, TEXT, `__FILE__, `__LINE__, MSG)); \
    if (svunit_pkg::current_tc.is_running()) svunit_pkg::current_tc.give_up(); \
  end

`ifndef ASSERT_IMMEDIATE
`define ASSERT_IMMEDIATE(expr) \
  assert (expr) else `QICK_ASSERT_FAILED("assert_immediate", `"expr`", "")
`endif

`ifndef ASSERT_IMMEDIATE_LOG
`define ASSERT_IMMEDIATE_LOG(expr, msg) \
  assert (expr) else `QICK_ASSERT_FAILED("assert_immediate", `"expr`", msg)
`endif

`ifndef ASSERT_CONCURRENT
`define ASSERT_CONCURRENT(prop) \
  assert property (prop) else `QICK_ASSERT_FAILED("assert_property", `"prop`", "")
`endif

`ifndef ASSERT_CONCURRENT_LOG
`define ASSERT_CONCURRENT_LOG(prop, msg) \
  assert property (prop) else `QICK_ASSERT_FAILED("assert_property", `"prop`", msg)
`endif

`endif // QICK_SVUNIT_ASSERT_MACROS_SVH
