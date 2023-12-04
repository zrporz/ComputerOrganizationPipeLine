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

typedef struct packed {
    logic [`MXLEN-3:0] base;
    logic [1:0] mode;
} mtvec_t;
typedef struct packed {
    logic [`MXLEN-3:0] base;
    logic [1:0] mode;
} stvec_t;
typedef logic[`MXLEN-1:0] mscratch_t;
typedef logic[`MXLEN-1:0] sscratch_t;
typedef logic[`MXLEN-1:0] mepc_t;
typedef logic[`MXLEN-1:0] sepc_t;
typedef logic[`MXLEN-1:0] mhartid_t;
typedef logic[`MXLEN-1:0] mideleg_t;
typedef logic[`MXLEN-1:0] medeleg_t;
typedef logic[`MXLEN-1:0] mtval_t;
typedef logic[`MXLEN-1:0] stval_t;
typedef struct packed {
    logic interrupt;
    logic[`MXLEN-2:0] exception_code;
} mcause_t;
typedef struct packed {
    logic interrupt;
    logic[`MXLEN-2:0] exception_code;
} scause_t;
typedef struct packed {
    logic sd; 
    logic[7:0] trash_0;
    logic tsr, tw, tvm, mxr, sum, mprv;
    logic[1:0] xs, fs, mpp, trash_1;
    logic spp, mpie, trash_2, spie, upie, mie, trash_3, sie, uie;
} mstatus_t;
typedef struct packed {
    logic[`MXLEN-13:0] trash_0;
    logic meie, trash_1, seie, ueie, mtie, trash_2, stie, utie, msie, trash_3, ssie, usie;
} mie_t;
typedef struct packed {
    logic[`MXLEN-13:0] trash_0;
    logic meie, trash_1, seie, ueie, mtie, trash_2, stie, utie, msie, trash_3, ssie, usie;
} sie_t;
typedef struct packed {
    logic[`MXLEN-13:0] trash_0;
    logic meip, trash_1, seip, ueip, mtip, trash_2, stip, utip, msip, trash_3, ssip, usip;
} mip_t;
typedef struct packed {
    logic[`MXLEN-13:0] trash_0;
    logic meip, trash_1, seip, ueip, mtip, trash_2, stip, utip, msip, trash_3, ssip, usip;
} sip_t;
typedef struct packed {
    logic mode;
    logic [8:0] asid;
    logic [21:0] ppn;
} satp_t;
`endif
