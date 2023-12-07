`ifndef EXCEPTION_SVH
`define EXCEPTION_SVH
`define MXLEN 32
`define CSR_ADDR_WIDTH 12
`define INSTRUCTION_PAGE_FAULT 31'd12
`define LOAD_PAGE_FAULT 31'd13
`define STORE_PAGE_FAULT 31'd15
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
// Refer https://c-yongheng.github.io/2022/07/30/riscv-privileged-spec/
`define MSTATUS_MASK 32'b1000_0000_0111_1111_1111_1111_1110_1010
`define SSTATUS_MASK 32'b1000_0000_0000_1101_1110_0111_0110_0010
`define SIE_MASK 32'b0000_0000_0000_0000_0000_0011_0011_0011
`define SIP_MASK 32'b0000_0000_0000_0000_0000_0011_0011_0011
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
typedef logic[`MXLEN-1:0] pmpaddr0_t;
typedef logic[`MXLEN-1:0] pmpcfg0_t;
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
} msstatus_t; // mstatus and sstatus share one register
typedef struct packed {
    logic[`MXLEN-13:0] trash_0;
    logic meie, trash_1, seie, ueie, mtie, trash_2, stie, utie, msie, trash_3, ssie, usie;
} msie_t; // mie and sie share one register
typedef struct packed {
    logic[`MXLEN-13:0] trash_0;
    logic meip, trash_1, seip, ueip, mtip, trash_2, stip, utip, msip, trash_3, ssip, usip;
} msip_t; // mip and sip share one register
typedef struct packed {
    logic mode;
    logic [8:0] asid;
    logic [21:0] ppn;
} satp_t;
`endif
