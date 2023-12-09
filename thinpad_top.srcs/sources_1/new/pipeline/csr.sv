`include "../headers/exception.svh"
module Csr#(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input wire clk_i,
    input wire rst_i,
    input wire [ADDR_WIDTH-1:0]  inst_i, // instruction
    input wire [DATA_WIDTH-1:0]  rf_rdata_a_i, // rs1 data
    input wire [ADDR_WIDTH-1:0]  pc_now_i,
    input wire [ADDR_WIDTH-1:0]  idex_pc_now_i,
    input wire [ADDR_WIDTH-1:0]  ifid_pc_now_i,
    input wire [ADDR_WIDTH-1:0]  wb0_pc_now_i,
    output reg [DATA_WIDTH-1:0]  rf_wdata_o, // rd
    output reg [1:0] priviledge_mode_o,
    output reg [ADDR_WIDTH-1:0] pc_next_o,
    output reg pc_next_en,
    // mtimer -> cpu -> csr
    input wire mtime_exceed_i,
    input wire [DATA_WIDTH-1:0] mtime_i,
    input wire [DATA_WIDTH-1:0] mtimeh_i,
    // mmu -> cpu -> csr
    output wire [ADDR_WIDTH-1:0] satp_o,
    output reg flush_tlb_o,
    // pipeline -> csr
    input wire[30:0] if_exception_code_i, // Instruction page fault: 12
    input wire[ADDR_WIDTH-1:0] if_exception_addr_i, // Virtual address
    input wire[30:0] mem_exception_code_i, // Load page fault: 13, Store page fault: 15
    input wire[ADDR_WIDTH-1:0] mem_exception_addr_i, // Virtual address
    input wire[DATA_WIDTH-1:0] id_exception_instr_i, // Illegeal Instruction
    input wire id_exception_instr_wen,
    input wire flush_exe_i, 
    // debug
    input wire [31:0] dip_sw_i,
    output reg [31:0] leds
);
    parameter  CSRRC = 32'b????_????_????_????_?011_????_?111_0011;
    parameter  CSRRS = 32'b????_????_????_????_?010_????_?111_0011;
    parameter  CSRRW = 32'b????_????_????_????_?001_????_?111_0011;
    parameter  CSRRCI = 32'b????_????_????_????_?111_????_?111_0011;
    parameter  CSRRSI = 32'b????_????_????_????_?110_????_?111_0011;
    parameter  CSRRWI = 32'b????_????_????_????_?101_????_?111_0011;
    parameter  EBREAK = 32'b0000_0000_0001_0000_0000_0000_0111_0011;
    parameter  ECALL = 32'b0000_0000_0000_0000_0000_0000_0111_0011;
    parameter  MRET = 32'b0011_0000_0010_0000_0000_0000_0111_0011;
    parameter  SRET = 32'b0001_0000_0010_0000_0000_0000_0111_0011;
    parameter  SFENCE_VMA = 32'b0001_001?_????_????_?000_0000_0111_0011;
    typedef enum logic [11:0]{
      MSTATUS= 12'h300,
      SSTATUS= 12'h100,
      MIE= 12'h304,
      SIE= 12'h104,
      MTVEC= 12'h305,
      STVEC= 12'h105,
      MSCRATCH= 12'h340,
      SSCRATCH= 12'h140,
      MEPC= 12'h341,
      SEPC= 12'h141,
      MCAUSE= 12'h342,
      SCAUSE= 12'h142,
      MIP= 12'h344,
      SIP= 12'h144,
      MTVAL=12'h343,
      STVAL=12'h143,
      SATP= 12'h180,
      MIDELEG = 12'h303,
      MEDELEG = 12'h302,
      PMPADDR0 = 12'h3B0,
      PMPCFG0 = 12'h3A0,
      TIME = 12'hC01,
      TIMEH = 12'hC81
    } csr_reg_t;

    mtvec_t mtvec;
    mscratch_t mscratch;
    mepc_t mepc;
    mcause_t mcause;
    msstatus_t msstatus;
    mtval_t mtval;
    stvec_t stvec;
    sscratch_t sscratch;
    sepc_t sepc;
    scause_t scause;
    stval_t stval;
    msie_t msie;
    msip_t msip;
    satp_t satp;
    mideleg_t mideleg;
    medeleg_t medeleg;
    pmpaddr0_t pmpaddr0;
    pmpcfg0_t pmpcfg0;
    reg[1:0] priviledge_mode_reg; // 00:User, 01:Supervisor, 10:Reserved, 11:Machine
    logic[31:0] uimm;
    // reg [31:0] previous_csr_pc_reg;
    assign satp_o = satp;
    // always_comb begin
    //   if(mip.mtip && mie.mtie)begin // time interrupt exist and machine mode enable all interrupt
        
    //   end 
    // end
    logic[15:0] leds_r;
    assign leds = leds_r;
    always_comb begin 
      leds_r = 16'h0000;
      case(dip_sw_i)
        32'h0000_0001: leds_r = {15'b0,clk_i};
        32'h0000_0002: leds_r = mcause[15:0];
        32'h0000_0003: leds_r = mcause[31:16];
        32'h0000_0004: leds_r = msstatus[15:0];
        32'h0000_0005: leds_r = msstatus[31:16];
        32'h0000_0006: leds_r = msie[15:0];
        32'h0000_0007: leds_r = msie[31:16];
        32'h0000_0008: leds_r = msip[15:0];
        32'h0000_0009: leds_r = msip[31:16];
        32'h0000_000a: leds_r = mtvec[15:0];
        32'h0000_000b: leds_r = mtvec[31:16];
        32'h0000_000c: leds_r = {15'b0, mtime_exceed_i};
        32'h0000_000d: leds_r = {14'b0, priviledge_mode_reg};
        32'h0000_0010: leds_r = mepc[15:0];
        32'h0000_0011: leds_r = mepc[31:16];
        32'h0000_0012: leds_r = pc_now_i[15:0];
        32'h0000_0013: leds_r = pc_now_i[31:16];
        32'h0000_0014: leds_r = pc_next_o[15:0];
        32'h0000_0015: leds_r = pc_next_o[31:16];
        32'h0000_0016: leds_r = {15'b0,pc_next_en};
      endcase

    end
    always_comb begin
      rf_wdata_o = 32'b0;
      casez(inst_i)
        CSRRC,CSRRS,CSRRCI,CSRRSI: begin
          case(inst_i[31:20])
            MSTATUS: rf_wdata_o = msstatus & `MSTATUS_MASK;
            SSTATUS: rf_wdata_o = msstatus & `SSTATUS_MASK;
            MTVEC: rf_wdata_o = mtvec;
            STVEC: rf_wdata_o = stvec;
            MCAUSE: rf_wdata_o = mcause;
            SCAUSE: rf_wdata_o = scause;
            MIP: rf_wdata_o = msip;
            SIP: rf_wdata_o = (msip & `SIP_MASK);
            MIE: rf_wdata_o = msie;
            SIE: rf_wdata_o = (msie & `SIE_MASK);
            MSCRATCH: rf_wdata_o = mscratch;
            SSCRATCH: rf_wdata_o = sscratch;
            MEPC: rf_wdata_o = mepc;
            SEPC: rf_wdata_o = sepc;
            MTVAL: rf_wdata_o = mtval;
            STVAL: rf_wdata_o = stval;
            MIDELEG: rf_wdata_o = mideleg;
            MEDELEG: rf_wdata_o = medeleg;
            SATP: rf_wdata_o = satp;
            PMPADDR0: rf_wdata_o =  pmpaddr0;
            PMPCFG0: rf_wdata_o =  pmpcfg0;
            // CSRRS Instrucion may read mtime register(RDTIME,RDTIMEH), but promise that rs1 is zero, so in this case, just read mtime register, don't need to write anything in          
            TIME: rf_wdata_o = mtime_i;
            TIMEH: rf_wdata_o = mtimeh_i;
          endcase
        end
        CSRRW, CSRRWI: begin
          if(inst_i[11:7])begin
            case(inst_i[31:20])
              MSTATUS: rf_wdata_o = msstatus & `MSTATUS_MASK;
              SSTATUS: rf_wdata_o = msstatus & `SSTATUS_MASK;
              MTVEC: rf_wdata_o = mtvec;
              STVEC: rf_wdata_o = stvec;
              MCAUSE: rf_wdata_o = mcause;
              SCAUSE: rf_wdata_o = scause;
              MIP: rf_wdata_o = msip;
              SIP: rf_wdata_o = (msip & `SIP_MASK);
              MIE: rf_wdata_o = msie;
              SIE: rf_wdata_o = (msie & `SIE_MASK);
              MSCRATCH: rf_wdata_o = mscratch;
              SSCRATCH: rf_wdata_o = sscratch;
              MEPC: rf_wdata_o = mepc;
              SEPC: rf_wdata_o = sepc;
              MTVAL: rf_wdata_o = mtval;
              STVAL: rf_wdata_o = stval;
              MIDELEG: rf_wdata_o = mideleg;
              MEDELEG: rf_wdata_o = medeleg;
              SATP: rf_wdata_o = satp;
              PMPADDR0: rf_wdata_o =  pmpaddr0;
              PMPCFG0: rf_wdata_o =  pmpcfg0;
              // CSRRS Instrucion may read mtime register(RDTIME,RDTIMEH), but promise that rs1 is zero, so in this case, just read mtime register, don't need to write anything in          
              TIME: rf_wdata_o = mtime_i;
              TIMEH: rf_wdata_o = mtimeh_i;
            endcase
          end
        end
      endcase
    end
    always_comb begin
      priviledge_mode_o = priviledge_mode_reg;
    end
    // unsigned imm extention
    always_comb begin
      uimm = {27'b0,inst_i[19:15]};
    end
    // always_comb begin
    //   if(priviledge_mode_i == PRIVILEDGE_MODE_U)begin
    //     mcause.exception_code = 31'h4;
    //     priviledge_mode_o = PRIVILEDGE_MODE_M;
    //   end else if(priviledge_mode_i == PRIVILEDGE_MODE_M)begin
    //     mcause.exception_code = 31'h7;
    //     priviledge_mode_o = PRIVILEDGE_MODE_U;
    //   end
    // end
    always_ff @ (posedge clk_i) begin
      if (rst_i) begin
        mtvec <= 32'b0;
        mscratch <= 32'b0;
        mepc <= 32'b0;
        mcause <= 32'b0;
        msstatus <= 32'b0;
        msie <= 32'b0;
        msip <= 32'b0;
        satp <= 32'b0;
        priviledge_mode_reg <= 2'b11;
        pc_next_en <= 0;
        pc_next_o <= 32'b0;
        // previous_csr_pc_reg <= 32'b0;
        flush_tlb_o <= 0;
      end else begin
        msip.mtip <= mtime_exceed_i;
        // previous_csr_pc_reg <= pc_next_o;
        casez(inst_i)
          CSRRC:begin
            flush_tlb_o <= 0;
            pc_next_en <= 0;
            pc_next_o <= 32'b0;
            if(inst_i[19:15])begin // only write csr when rs1 is not x0
              case(inst_i[31:20])
                MSTATUS: msstatus <= msstatus & ~(rf_rdata_a_i & `MSTATUS_MASK);
                SSTATUS: msstatus <= msstatus & ~(rf_rdata_a_i & `SSTATUS_MASK);
                MTVEC: mtvec <= mtvec & ~rf_rdata_a_i;
                STVEC: stvec <= stvec & ~rf_rdata_a_i;
                MCAUSE: mcause <= mcause & ~rf_rdata_a_i;
                SCAUSE: scause <= scause & ~rf_rdata_a_i;
                MIP: msip <= msip & ~rf_rdata_a_i;
                SIP: msip <= msip & ~(rf_rdata_a_i & `SIP_MASK);
                MIE: msie <= msie & ~rf_rdata_a_i;
                SIE: msie <= msie & ~(rf_rdata_a_i & `SIE_MASK);
                MSCRATCH: mscratch <= mscratch & ~rf_rdata_a_i;
                SSCRATCH: sscratch <= sscratch & ~rf_rdata_a_i;
                MEPC: mepc <= mepc & ~rf_rdata_a_i;
                SEPC: sepc <= sepc & ~rf_rdata_a_i;
                MTVAL: mtval <= mtval & ~rf_rdata_a_i;
                STVAL: stval <= stval & ~rf_rdata_a_i;
                MIDELEG: mideleg <= mideleg & ~rf_rdata_a_i;
                MEDELEG: medeleg <= medeleg & ~rf_rdata_a_i;
                SATP: satp <= satp & ~rf_rdata_a_i;
                PMPADDR0: pmpaddr0 <=  pmpaddr0 & ~rf_rdata_a_i;      
                PMPCFG0: pmpcfg0 <=  pmpcfg0 & ~rf_rdata_a_i;      
              endcase
            end
          end
          CSRRCI:begin
            flush_tlb_o <= 0;
            pc_next_en <= 0;
            pc_next_o <= 32'b0;
            if(inst_i[19:15])begin // only write csr when rs1 is not x0
              case(inst_i[31:20])
                MSTATUS: msstatus <= msstatus & ~(uimm & `MSTATUS_MASK);
                SSTATUS: msstatus <= msstatus & ~(uimm & `SSTATUS_MASK);
                MTVEC: mtvec <= mtvec & ~uimm;
                STVEC: stvec <= stvec & ~uimm;
                MCAUSE: mcause <= mcause & ~uimm;
                SCAUSE: scause <= scause & ~uimm;
                MIP: msip <= msip & ~uimm;
                SIP: msip <= msip & ~(uimm & `SIP_MASK);
                MIE: msie <= msie & ~uimm;
                SIE: msie <= msie & ~(uimm & `SIE_MASK);
                MSCRATCH: mscratch <= mscratch & ~uimm;
                SSCRATCH: sscratch <= sscratch & ~uimm;
                MEPC: mepc <= mepc & ~uimm;
                SEPC: sepc <= sepc & ~uimm;
                MTVAL: mtval <= mtval & ~uimm;
                STVAL: stval <= stval & ~uimm;
                MIDELEG: mideleg <= mideleg & ~uimm;
                MEDELEG: medeleg <= medeleg & ~uimm;
                SATP: satp <= satp & ~uimm;
                PMPADDR0: pmpaddr0 <=  pmpaddr0 & ~uimm;      
                PMPCFG0: pmpcfg0 <=  pmpcfg0 & ~uimm;       
              endcase
            end
          end
          CSRRS:begin
            flush_tlb_o <= 0;
            pc_next_en <= 0;
            pc_next_o <= 32'b0;
            if(inst_i[19:15])begin
              case(inst_i[31:20])
                MSTATUS: msstatus <= msstatus | (rf_rdata_a_i & `MSTATUS_MASK);
                SSTATUS: msstatus <= msstatus | (rf_rdata_a_i & `SSTATUS_MASK);
                MTVEC: mtvec <= mtvec | rf_rdata_a_i;
                STVEC: stvec <= stvec | rf_rdata_a_i;
                MCAUSE: mcause <= mcause | rf_rdata_a_i;
                SCAUSE: scause <= scause | rf_rdata_a_i;
                MIP: msip <= msip | rf_rdata_a_i;
                SIP: msip <= msip | (rf_rdata_a_i & `SIP_MASK);
                MIE: msie <= msie | rf_rdata_a_i;
                SIE: msie <= msie | (rf_rdata_a_i & `SIE_MASK);
                MSCRATCH: mscratch <= mscratch | rf_rdata_a_i;
                SSCRATCH: sscratch <= sscratch | rf_rdata_a_i;
                MEPC: mepc <= mepc | rf_rdata_a_i;
                SEPC: sepc <= sepc | rf_rdata_a_i;
                MTVAL: mtval <= mtval | rf_rdata_a_i;
                STVAL: stval <= stval | rf_rdata_a_i;
                MIDELEG: mideleg <= mideleg | rf_rdata_a_i;
                MEDELEG: medeleg <= medeleg | rf_rdata_a_i;
                SATP: satp <= satp | rf_rdata_a_i;
                PMPADDR0: pmpaddr0 <=  pmpaddr0 | rf_rdata_a_i;      
                PMPCFG0: pmpcfg0 <=  pmpcfg0 | rf_rdata_a_i;                
              endcase
            end
          end
          CSRRSI:begin
            flush_tlb_o <= 0;
            pc_next_en <= 0;
            pc_next_o <= 32'b0;
            if(inst_i[19:15])begin
              case(inst_i[31:20])
                MSTATUS: msstatus <= msstatus | (uimm & `MSTATUS_MASK);
                SSTATUS: msstatus <= msstatus | (uimm & `SSTATUS_MASK);
                MTVEC: mtvec <= mtvec | uimm;
                STVEC: stvec <= stvec | uimm;
                MCAUSE: mcause <= mcause | uimm;
                SCAUSE: scause <= scause | uimm;
                MIP: msip <= msip | uimm;
                SIP: msip <= msip | (uimm & `SIP_MASK);
                MIE: msie <= msie | uimm;
                SIE: msie <= msie | (uimm & `SIE_MASK);
                MSCRATCH: mscratch <= mscratch | uimm;
                SSCRATCH: sscratch <= sscratch | uimm;
                MEPC: mepc <= mepc | uimm;
                SEPC: sepc <= sepc | uimm;
                MTVAL: mtval <= mtval | uimm;
                STVAL: stval <= stval | uimm;
                MIDELEG: mideleg <= mideleg | uimm;
                MEDELEG: medeleg <= medeleg | uimm;
                SATP: satp <= satp | uimm;         
                PMPADDR0: pmpaddr0 <=  pmpaddr0 | uimm;      
                PMPCFG0: pmpcfg0 <=  pmpcfg0 | uimm;     
              endcase
            end
          end
          CSRRW:begin
            flush_tlb_o <= 0;
            pc_next_en <= 0;
            pc_next_o <= 32'b0;
            // For csr write, don't need rs1!=x0 or uimm != 0
            case(inst_i[31:20])
              MSTATUS: msstatus <= (msstatus & ~`MSTATUS_MASK) | (rf_rdata_a_i & `MSTATUS_MASK);
              SSTATUS: msstatus <= (msstatus & ~`SSTATUS_MASK) | (rf_rdata_a_i & `SSTATUS_MASK);
              MTVEC: mtvec <= rf_rdata_a_i;
              STVEC: stvec <= rf_rdata_a_i;
              MCAUSE: mcause <= rf_rdata_a_i;
              SCAUSE: scause <= rf_rdata_a_i;
              MIP: msip <= rf_rdata_a_i;
              SIP: msip <= (msip & ~`SIP_MASK) | (rf_rdata_a_i & `SIP_MASK);
              MIE: msie <= rf_rdata_a_i;
              SIE: msie <= (msie & ~`SIE_MASK) | (rf_rdata_a_i & `SIE_MASK);
              MSCRATCH: mscratch <= rf_rdata_a_i;
              SSCRATCH: sscratch <= rf_rdata_a_i;
              MEPC: mepc <= rf_rdata_a_i;
              SEPC: sepc <= rf_rdata_a_i;
              MTVAL: mtval <= rf_rdata_a_i;
              STVAL: stval <= rf_rdata_a_i;
              MIDELEG: mideleg <= rf_rdata_a_i;
              MEDELEG: medeleg <= rf_rdata_a_i;
              SATP: satp <= rf_rdata_a_i;
              PMPADDR0: pmpaddr0 <=  rf_rdata_a_i;      
              PMPCFG0: pmpcfg0 <=  rf_rdata_a_i;             
            endcase
          end
          CSRRWI:begin
            flush_tlb_o <= 0;
            pc_next_en <= 0;
            pc_next_o <= 32'b0;
            case(inst_i[31:20])
              MSTATUS: msstatus <= (msstatus & ~`MSTATUS_MASK) | (uimm & `MSTATUS_MASK);
              SSTATUS: msstatus <= (msstatus & ~`SSTATUS_MASK) | (uimm & `SSTATUS_MASK);
              MTVEC: mtvec <= uimm;
              STVEC: stvec <= uimm;
              MCAUSE: mcause <= uimm;
              SCAUSE: scause <= uimm;
              MIP: msip <= uimm;
              SIP: msip <= (msip & ~`SIP_MASK) | (uimm & `SIP_MASK);
              MIE: msie <= uimm;
              SIE: msie <= (msie & ~`SIE_MASK) | (uimm & `SIE_MASK);
              MSCRATCH: mscratch <= uimm;
              SSCRATCH: sscratch <= uimm;
              MEPC: mepc <= uimm;
              SEPC: sepc <= uimm;
              MTVAL: mtval <= uimm;
              STVAL: stval <= uimm;
              MIDELEG: mideleg <= uimm;
              MEDELEG: medeleg <= uimm;
              SATP: satp <= uimm;
              PMPADDR0: pmpaddr0 <=  uimm;      
              PMPCFG0: pmpcfg0 <=  uimm;            
            endcase
          end
          SFENCE_VMA:begin
            flush_tlb_o <= 1;
          end
          EBREAK:begin
            flush_tlb_o <= 0;
            mepc <= pc_now_i; 
            mcause.interrupt <= 1'b0;
            mcause.exception_code <= 31'h3;
            msstatus.mpp <= priviledge_mode_reg;
            priviledge_mode_reg <= PRIVILEDGE_MODE_M;
            pc_next_en <= 1;
            pc_next_o <= {mtvec[31:2],2'b00};
          end
          ECALL:begin
            flush_tlb_o <= 0;
            if((priviledge_mode_reg == PRIVILEDGE_MODE_U && medeleg[8]) || (priviledge_mode_reg == PRIVILEDGE_MODE_S && medeleg[9]))begin
              sepc <= pc_now_i;
              scause.interrupt <= 1'b0;
              scause.exception_code <= priviledge_mode_reg == PRIVILEDGE_MODE_U ? 31'h8 : 31'h9;
              msstatus.spp <= priviledge_mode_reg; 
              pc_next_en <= 1;
              pc_next_o <= {stvec[31:2],2'b00};
              priviledge_mode_reg <= PRIVILEDGE_MODE_S;

            end else begin
              mepc <= pc_now_i; // ECALL is a exception, not interruption, thus mepc should save current pc , not pc+4
              mcause.interrupt <= 1'b0;
              mcause.exception_code <= (priviledge_mode_reg == PRIVILEDGE_MODE_U)? 31'h8 : ((priviledge_mode_reg == PRIVILEDGE_MODE_S) ? 31'h9 : 31'hb);
              msstatus.mpp <= priviledge_mode_reg;
              pc_next_en <= 1;
              pc_next_o <= {mtvec[31:2],2'b00};
              priviledge_mode_reg <= PRIVILEDGE_MODE_M;
            end
          end
          MRET:begin
            flush_tlb_o <= 0;
            pc_next_en <= 1;
            pc_next_o <= mepc;
            priviledge_mode_reg <= msstatus.mpp;
            msstatus.mie <= msstatus.mpie;
            // msie.mtie <= 1'b1;
          end
          SRET:begin
            flush_tlb_o <= 0;
            pc_next_en <= 1;
            pc_next_o <= sepc;
            priviledge_mode_reg <= msstatus.spp;
            msstatus.sie <= msstatus.spie;
            // msie.stie <= 1'b1; //???
          end
          default:begin
            flush_tlb_o <= 0;
            // Instr page fault
            if(if_exception_code_i)begin
              if(medeleg[if_exception_code_i])begin 
                stval <= if_exception_addr_i;
                scause.interrupt <= 1'b0;
                scause.exception_code <= if_exception_code_i;
                msstatus.spp <= priviledge_mode_reg;
                sepc <= pc_now_i;
                pc_next_en <= 1;
                pc_next_o <= {mtvec[31:2],2'b00};
                priviledge_mode_reg <= PRIVILEDGE_MODE_S;
              end else begin
                mtval <= if_exception_addr_i;
                mcause.interrupt <= 1'b0;
                mcause.exception_code <= if_exception_code_i;
                msstatus.mpp <= priviledge_mode_reg;
                mepc <= pc_now_i;
                pc_next_en <= 1;
                pc_next_o <= {stvec[31:2],2'b00};
                priviledge_mode_reg <= PRIVILEDGE_MODE_M;
              end
            end
            // Invalid instruction
            else if(id_exception_instr_wen)begin
              if(medeleg[2])begin
                stval <= id_exception_instr_i;
                scause.interrupt <= 1'b0;
                scause.exception_code <= id_exception_instr_i;
                msstatus.spp <= priviledge_mode_reg;
                sepc <= pc_now_i;
                pc_next_en <= 1;
                pc_next_o <= {stvec[31:2],2'b00};
                priviledge_mode_reg <= PRIVILEDGE_MODE_S;
              end else begin
                mtval <= id_exception_instr_i;
                // Maybe don't need to set mepc ??? 
                // mepc <= pc_now_i;
                mcause.interrupt <= 1'b0;
                mcause.exception_code <= 31'h2;
                msstatus.mpp <= priviledge_mode_reg;
                mepc <= pc_now_i;
                pc_next_en <= 1;
                pc_next_o <= {mtvec[31:2],2'b00};
                priviledge_mode_reg <= PRIVILEDGE_MODE_M;
              end
            end
            // mem page fault
            else if(mem_exception_code_i)begin
              if(medeleg[mem_exception_code_i])begin 
                stval <= mem_exception_addr_i;
                scause.interrupt <= 1'b0;
                scause.exception_code <= mem_exception_code_i;
                msstatus.spp <= priviledge_mode_reg;
                sepc <= pc_now_i;
                pc_next_en <= 1;
                pc_next_o <= {stvec[31:2],2'b00};
                priviledge_mode_reg <= PRIVILEDGE_MODE_S;
              end else begin
                mtval <= mem_exception_addr_i;
                mcause.interrupt <= 1'b0;
                mcause.exception_code <= mem_exception_code_i;
                msstatus.mpp <= priviledge_mode_reg;
                mepc <= pc_now_i;
                pc_next_en <= 1;
                pc_next_o <= {mtvec[31:2],2'b00};
                priviledge_mode_reg <= PRIVILEDGE_MODE_M;
              end
            end
            // For Interrupt (i.e. Time interruption)
            else if(msip.stip && msie.stie && (priviledge_mode_reg == PRIVILEDGE_MODE_U || (priviledge_mode_reg == PRIVILEDGE_MODE_S && msstatus.sie)))begin
              // Superior mode time-out interrupt
              scause.interrupt <= 1'b1;
              scause.exception_code <= 31'h5;
              pc_next_en <= 1;
              pc_next_o <= {stvec[31:2],2'b00};
              if(flush_exe_i)begin // if time interrupr occure when switch to U-mode from M-mode, we should use if-pc as sepc, rather than exme_pc, because this exme_pc has been flushed!
                sepc <= pc_next_o;
              end else begin
                sepc <= pc_now_i;
              end
              msstatus.spp <= priviledge_mode_reg;
              priviledge_mode_reg <= PRIVILEDGE_MODE_S;
              msstatus.spie <= msstatus.sie;
              msstatus.sie <= 1'b0;
            end else if(msip.mtip && msie.mtie && (priviledge_mode_reg != PRIVILEDGE_MODE_M || msstatus.mie))begin
              // Machine mode time-out interrupt
              mcause.interrupt <= 1'b1;
              mcause.exception_code <= 31'h7;
              pc_next_en <= 1;
              pc_next_o <= {mtvec[31:2],2'b00};
              if(flush_exe_i)begin
                mepc <= pc_next_o;
              end else begin
                if(pc_now_i!=32'h8000_0000)begin
                  mepc <= pc_now_i;
                end else if(idex_pc_now_i!=32'h8000_0000)begin
                  mepc <= idex_pc_now_i;
                end else if(ifid_pc_now_i!=32'h8000_0000)begin
                  mepc <= ifid_pc_now_i;
                end 
                else begin
                  mepc <= wb0_pc_now_i;
                end 
              end
              msstatus.mpp <= priviledge_mode_reg;
              msstatus.mpie <= msstatus.mie;
              msstatus.mie <= 1'b0;
              priviledge_mode_reg <= PRIVILEDGE_MODE_M;
            end 
            else begin
              pc_next_en <= 0;
              pc_next_o <= 32'b0;
            end
            // if(msip.mtip && (priviledge_mode_reg == PRIVILEDGE_MODE_U || mie.mtie && priviledge_mode_reg == PRIVILEDGE_MODE_M))begin // time interrupt exist and machine mode enable all interrupt
            //   if(priviledge_mode_reg == PRIVILEDGE_MODE_U)begin 
            //     mie.mtie <= 0; // unable the mtie, otherwise pc will stuck in mtvec
            //     mcause.interrupt <= 1'b1;
            //     mepc <= pc_now_i + 4;
            //     pc_next_en <= 1;
            //     pc_next_o <= {mtvec[31:2],2'b00};
            //     mcause.exception_code <= 31'h7;
            //     mstatus.mpp <= PRIVILEDGE_MODE_U;
            //     priviledge_mode_reg <= PRIVILEDGE_MODE_M;
            //   end else begin
            //     pc_next_en <= 0;
            //     pc_next_o <= 32'b0;
            //   end
            //   // else if(priviledge_mode_i == PRIVILEDGE_MODE_M)begin
            //   //   mie.mtie <= 0; // unable the mtie, otherwise pc will stuck in mtvec
            //   //   mcause.interrupt <= 1'b1;
            //   //   mcause.exception_code <= 31'h7;
            //   //   mepc <= pc_now_i + 4;
            //   //   mstatus.mpp <= PRIVILEDGE_MODE_M;
            //   //   priviledge_mode_o <= PRIVILEDGE_MODE_M;
            //   //   pc_next_o <= {mtvec[31:2],2'b00};
            //   // end
            // end else begin
            //   pc_next_en <= 0;
            //   pc_next_o <= 32'b0;
            // end 
          end
        endcase
      end
    end
endmodule