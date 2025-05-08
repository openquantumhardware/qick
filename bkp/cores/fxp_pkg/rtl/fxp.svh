`ifndef FXP_MACRO
    `define FXP_MACRO
    `define NB_INT(repr) (repr.nb - repr.nf)
    `define POS_SAT(repr) {1'b0, {repr.nb-1{1'b1}}}
    `define NEG_SAT(repr) {1'b1, {repr.nb-1{1'b0}}}

    `define FXPSAT(sig, in_repr, out_repr) \
        (~sig[$high(sig)] & |sig[$high(sig)-1-:(`NB_INT(in_repr)-`NB_INT(out_repr))]) ? \
            `POS_SAT(out_repr) : \
            (sig[$high(sig)] & ~&sig[$high(sig)-1-:(`NB_INT(in_repr)-`NB_INT(out_repr))]) ? \
                `NEG_SAT(out_repr) : sig[$high(sig)-(`NB_INT(in_repr)-`NB_INT(out_repr))-:out_repr.nb]
`endif
