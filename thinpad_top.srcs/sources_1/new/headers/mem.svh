`ifndef MEM_SVH
`define MEM_SVH

// All the Addr structs are composed of *spilt bytes* of the address
// All the Entry structs are in the format of *table entry* 

// Vitual Address
typedef struct packed {
    logic [9:0] vpn1;
    logic [9:0] vpn0;
    logic [11:0] offset;
} virt_addr_t;

// TLB Address
typedef struct packed {
    logic [14:0] tlbi;
    logic [4:0] tlbt;
    logic [11:0] offset;
} tlb_addr_t;

// PT Entry
typedef struct packed {
    logic [11:0] ppn1;
    logic [9:0] ppn0;
    logic [1:0] rsw;
    logic D, A, G, U, X, W, R, V;
} pte_t;

// TLB Entry
typedef struct packed {
    logic [14:0] tlbi;
    logic [8:0] asid;
    pte_t pte;
    logic valid;
} tlbe_t;

`endif