`ifndef ASSERT_IMMEDIATE
`define ASSERT_IMMEDIATE(exp) \
    assert(exp) else begin \
        void'(svunit_pkg::current_tc.fail(`"fail_assertion_immediate`", (1'b1), `"exp`", `__FILE__, `__LINE__)); \
        if (svunit_pkg::current_tc.is_running()) svunit_pkg::current_tc.give_up(); \
    end
`endif

`ifndef ASSERT_CONCURRENT
`define ASSERT_CONCURRENT(prop) \
    assert property (prop) else begin \
        void'(svunit_pkg::current_tc.fail(`"fail_assertion_concurrent`", (1'b1), `"prop`", `__FILE__, `__LINE__)); \
        if (svunit_pkg::current_tc.is_running()) svunit_pkg::current_tc.give_up(); \
    end
`endif

`ifndef ASSERT_IMMEDIATE_LOG
`define ASSERT_IMMEDIATE_LOG(exp, msg) \
    assert(exp) else begin \
        void'(svunit_pkg::current_tc.fail(`"fail_assertion_immediate`", (1'b1), `"exp`", `__FILE__, `__LINE__, msg)); \
        if (svunit_pkg::current_tc.is_running()) svunit_pkg::current_tc.give_up(); \
    end
`endif

`ifndef ASSERT_CONCURRENT_LOG
`define ASSERT_CONCURRENT_LOG(prop, msg) \
    assert property (prop) else begin \
        void'(svunit_pkg::current_tc.fail(`"fail_assertion_concurrent`", (1'b1), `"prop`", `__FILE__, `__LINE__, msg)); \
        if (svunit_pkg::current_tc.is_running()) svunit_pkg::current_tc.give_up(); \
    end
`endif

