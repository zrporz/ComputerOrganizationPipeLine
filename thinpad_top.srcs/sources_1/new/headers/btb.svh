`ifndef BTB_SVH
`define BTB_SVH

typedef struct packed {
    logic valid;                // whether the BTB entry is valid
    logic [31:0] target_addr;   // target address
    logic [25:0] source_tag;    // source address's tag, for compare
} btb_entry;

`endif