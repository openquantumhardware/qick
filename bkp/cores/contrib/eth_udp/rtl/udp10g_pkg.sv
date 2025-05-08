package udp10g_pkg;

    typedef struct packed {
        logic [5:0]  dscp;
        logic [1:0]  ecn;
        logic [7:0]  ttl;
        logic [31:0] source_ip;
        logic [31:0] dest_ip;
    } ip_hdr_t;

    typedef struct packed {
        ip_hdr_t     ip_hdr;
        logic [15:0] source_port;
        logic [15:0] dest_port;
        logic [15:0] length;
        logic [15:0] checksum;
    } udp_hdr_t;

endpackage
