package fxp_pkg;
    typedef struct packed  {
        bit sign;
        int unsigned nb;
        int unsigned nf;
    } repr_t;

    typedef enum {SUM, MULT} fxp_op;

    function repr_t get_repr(repr_t val1, repr_t val2, fxp_op op);
        case (op)
            SUM: begin
                return '{
                    sign: val1.sign | val2.sign,
                    nb: (val1.nb > val2.nb ? val1.nb : val2.nb) + 1 + 32'({(val1.sign^val2.sign)}),
                    nf: val1.nf > val2.nf ? val1.nf : val2.nf
                };
            end
            MULT: begin
                return '{
                    sign: val1.sign | val2.sign,
                    nb: val1.nb + val2.nb + 32'({(val1.sign^val2.sign)}),
                    nf: val1.nf + val2.nf
                };
            end
            default: $fatal(1, "Invalid operation");
        endcase
    endfunction

endpackage
