`ifndef EXCEPTION_SVH
`define EXCEPTION_SVH
`define MXLEN 32
`define CSR_ADDR_WIDTH 12
typedef enum logic[1:0] {
  PRIVILEDGE_MODE_U=2'b00, // USER MODE
  PRIVILEDGE_MODE_S=2'b01, // SUPERVISOR MODE
  PRIVILEDGE_MODE_R=2'b10, // RESERVED MODE
  PRIVILEDGE_MODE_M=2'b11 // MACHINE MODE
} priviledge_mode_t;
// `define PRIVILEDGE_MODE_U 2'b00 // USER MODE
// `define PRIVILEDGE_MODE_S 2'b01 // SUPERVISOR MODE
// `define PRIVILEDGE_MODE_R 2'b10 // RESERVED MODE
// `define PRIVILEDGE_MODE_M 2'b11 // MACHINE MODE

`define CSR_MTVEC_ADDR `CSR_ADDR_WIDTH'h305
typedef struct packed {
    logic [`MXLEN-3:0] base;
    logic [1:0] mode;
} mtvec_t;
`define CSR_MSCRATCH_ADDR `CSR_ADDR_WIDTH'h340
typedef logic[`MXLEN-1:0] mscratch_t;
`define CSR_MEPC_ADDR `CSR_ADDR_WIDTH'h341
typedef logic[`MXLEN-1:0] mepc_t;
`define CSR_MCAUSE_ADDR `CSR_ADDR_WIDTH'h342
typedef struct packed {
    logic interrupt;
    logic[`MXLEN-2:0] exception_code;
} mcause_t;
`define CSR_MSTATUS_ADDR `CSR_ADDR_WIDTH'h300
typedef struct packed {
    logic sd; 
    logic[7:0] trash_0;
    logic tsr, tw, tvm, mxr, sum, mprv;
    logic[1:0] xs, fs, mpp, trash_1;
    logic spp, mpie, trash_2, spie, upie, mie, trash_3, sie, uie;
} mstatus_t;
`define CSR_MIE_ADDR `CSR_ADDR_WIDTH'h304
typedef struct packed {
    logic[`MXLEN-13:0] trash_0;
    logic meie, trash_1, seie, ueie, mtie, trash_2, stie, utie, msie, trash_3, ssie, usie;
} mie_t;
`define CSR_MIP_ADDR `CSR_ADDR_WIDTH'h344
typedef struct packed {
    logic[`MXLEN-13:0] trash_0;
    logic meip, trash_1, seip, ueip, mtip, trash_2, stip, utip, msip, trash_3, ssip, usip;
} mip_t;
`define CSR_SATP_ADDR `CSR_ADDR_WIDTH'h180
typedef struct packed {
    logic mode;
    logic [8:0] asid;
    logic [21:0] ppn;
} satp_t;
`endif
