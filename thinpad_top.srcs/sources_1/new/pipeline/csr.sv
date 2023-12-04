`include "../headers/exception.svh"
module Csr#(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input wire clk_i,
    input wire rst_i,
    input wire [ADDR_WIDTH-1:0]inst_i, // instruction
    input wire [DATA_WIDTH-1:0]rf_rdata_a_i, // rs1 data
    input wire [ADDR_WIDTH-1:0] pc_now_i,
    output reg [DATA_WIDTH-1:0]rf_wdata_o, // rd
    output reg [1:0] priviledge_mode_o,
    output reg [ADDR_WIDTH-1:0] pc_next_o,
    output reg pc_next_en,
    // mtimer -> cpu -> csr
    input wire mtime_exceed_i,
    // mmu -> cpu -> csr
    output wire [ADDR_WIDTH-1:0] satp_o,
     
    // debug
    input wire [31:0] dip_sw_i,
    output reg [31:0] leds
);
    parameter  CSRRC= 32'b????_????_????_????_?011_????_?111_0011;
    parameter  CSRRS= 32'b????_????_????_????_?010_????_?111_0011;
    parameter  CSRRW= 32'b????_????_????_????_?001_????_?111_0011;
    parameter  CSRRCI= 32'b????_????_????_????_?111_????_?111_0011;
    parameter  CSRRSI= 32'b????_????_????_????_?110_????_?111_0011;
    parameter  CSRRWI= 32'b????_????_????_????_?101_????_?111_0011;
    parameter  EBREAK= 32'b0000_0000_0001_0000_0000_0000_0111_0011;
    parameter  ECALL= 32'b0000_0000_0000_0000_0000_0000_0111_0011;
    parameter  MRET= 32'b0011_0000_0010_0000_0000_0000_0111_0011;
    typedef enum logic [11:0]{
      MSTATUS= 12'h300,
      MIE= 12'h304,
      MTVEC= 12'h305,
      MSCRATCH= 12'h340,
      MEPC= 12'h341,
      MCAUSE= 12'h342,
      MIP= 12'h344,
      SATP= 12'h180
    } csr_reg_t;

    mtvec_t mtvec;
    mscratch_t mscratch;
    mepc_t mepc;
    mcause_t mcause;
    mstatus_t mstatus;
    mie_t mie;
    mip_t mip;
    satp_t satp;
    reg[1:0] priviledge_mode_reg; // 00:User, 01:Supervisor, 10:Reserved, 11:Machine
    logic[31:0] uimm;
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
        32'h0000_0004: leds_r = mstatus[15:0];
        32'h0000_0005: leds_r = mstatus[31:16];
        32'h0000_0006: leds_r = mie[15:0];
        32'h0000_0007: leds_r = mie[31:16];
        32'h0000_0008: leds_r = mip[15:0];
        32'h0000_0009: leds_r = mip[31:16];
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
        CSRRC,CSRRS,CSRRW,CSRRCI,CSRRSI,CSRRWI: begin
          case(inst_i[31:20])
            MSTATUS: rf_wdata_o = mstatus ;
            MTVEC: rf_wdata_o = mtvec;
            MCAUSE: rf_wdata_o = mcause;
            MIP: rf_wdata_o = mip;
            MIE: rf_wdata_o = mie;
            MSCRATCH: rf_wdata_o = mscratch;
            MEPC: rf_wdata_o = mepc;
            SATP: rf_wdata_o = satp;           
          endcase
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
        mstatus <= 32'b0;
        mie <= 32'b0;
        mip <= 32'b0;
        satp <= 32'b0;
        priviledge_mode_reg <= 2'b11;
        pc_next_en <= 0;
        pc_next_o <= 32'b0;
      end else begin
        mip.mtip <= mtime_exceed_i;
        casez(inst_i)
          CSRRC:begin
            pc_next_en <= 0;
            pc_next_o <= 32'b0;
            if(inst_i[19:15])begin // only write csr when rs1 is not x0
              case(inst_i[31:20])
                MSTATUS: mstatus <= mstatus & ~rf_rdata_a_i;
                MTVEC: mtvec <= mtvec & ~rf_rdata_a_i;
                MCAUSE: mcause <= mcause & ~rf_rdata_a_i;
                MIP: mip <= mip & ~rf_rdata_a_i;
                MIE: mie <= mie & ~rf_rdata_a_i;
                MSCRATCH: mscratch <= mscratch & ~rf_rdata_a_i;
                MEPC: mepc <= mepc & ~rf_rdata_a_i;
                SATP: satp <= satp & ~rf_rdata_a_i;          
              endcase
            end
          end
          CSRRCI:begin
            pc_next_en <= 0;
            pc_next_o <= 32'b0;
            if(inst_i[19:15])begin // only write csr when rs1 is not x0
              case(inst_i[31:20])
                MSTATUS: mstatus <= mstatus & ~uimm;
                MTVEC: mtvec <= mtvec & ~uimm;
                MCAUSE: mcause <= mcause & ~uimm;
                MIP: mip <= mip & ~uimm;
                MIE: mie <= mie & ~uimm;
                MSCRATCH: mscratch <= mscratch & ~uimm;
                MEPC: mepc <= mepc & ~uimm;
                SATP: satp <= satp & ~uimm;    
              endcase
            end
          end
          CSRRS:begin
            pc_next_en <= 0;
            pc_next_o <= 32'b0;
            if(inst_i[19:15])begin
              case(inst_i[31:20])
                MSTATUS: mstatus <= mstatus | rf_rdata_a_i;
                MTVEC: mtvec <= mtvec | rf_rdata_a_i;
                MCAUSE: mcause <= mcause | rf_rdata_a_i;
                MIP: mip <= mip | rf_rdata_a_i;
                MIE: mie <= mie | rf_rdata_a_i;
                MSCRATCH: mscratch <= mscratch | rf_rdata_a_i;
                MEPC: mepc <= mepc | rf_rdata_a_i;
                SATP: satp <= satp | rf_rdata_a_i;                
              endcase
            end
          end
          CSRRSI:begin
            pc_next_en <= 0;
            pc_next_o <= 32'b0;
            if(inst_i[19:15])begin
              case(inst_i[31:20])
                MSTATUS: mstatus <= mstatus | uimm;
                MTVEC: mtvec <= mtvec | uimm;
                MCAUSE: mcause <= mcause | uimm;
                MIP: mip <= mip | uimm;
                MIE: mie <= mie | uimm;
                MSCRATCH: mscratch <= mscratch | uimm;
                MEPC: mepc <= mepc | uimm;
                SATP: satp <= satp | uimm;              
              endcase
            end
          end
          CSRRW:begin
            pc_next_en <= 0;
            pc_next_o <= 32'b0;
            if(inst_i[19:15])begin
              case(inst_i[31:20])
                MSTATUS: mstatus <= rf_rdata_a_i;
                MTVEC: mtvec <= rf_rdata_a_i;
                MCAUSE: mcause <= rf_rdata_a_i;
                MIP: mip <= rf_rdata_a_i;
                MIE: mie <= rf_rdata_a_i;
                MSCRATCH: mscratch <= rf_rdata_a_i;
                MEPC: mepc <= rf_rdata_a_i;
                SATP: satp <= rf_rdata_a_i;           
              endcase
            end
          end
          CSRRWI:begin
            pc_next_en <= 0;
            pc_next_o <= 32'b0;
            if(inst_i[19:15])begin
              case(inst_i[31:20])
                MSTATUS: mstatus <= uimm;
                MTVEC: mtvec <= uimm;
                MCAUSE: mcause <= uimm;
                MIP: mip <= uimm;
                MIE: mie <= uimm;
                MSCRATCH: mscratch <= uimm;
                MEPC: mepc <= uimm;
                SATP: satp <= uimm;           
              endcase
            end
          end
          EBREAK:begin
            mepc <= pc_now_i; 
            mcause.interrupt <= 1'b0;
            mcause.exception_code <= 31'h3;
            mstatus.mpp <= priviledge_mode_reg;
            priviledge_mode_reg <= PRIVILEDGE_MODE_M;
            pc_next_en <= 1;
            pc_next_o <= {mtvec[31:2],2'b00};
          end
          ECALL:begin
            mepc <= pc_now_i; // ECALL is a exception, not interruption, thus mepc should save current pc , not pc+4
            mcause.interrupt <= 2'b0;
            mstatus.mpp <= priviledge_mode_reg;
            pc_next_en <= 1;
            pc_next_o <= {mtvec[31:2],2'b00};
            if(priviledge_mode_reg == PRIVILEDGE_MODE_U)begin // Environment call from user mode
              mcause.exception_code <= 31'h8;
              priviledge_mode_reg <= PRIVILEDGE_MODE_M;
            end else if(priviledge_mode_reg == PRIVILEDGE_MODE_M)begin //Environment call from machine mode
              mcause.exception_code <= 31'hb;
              priviledge_mode_reg <= PRIVILEDGE_MODE_U;
            end
          end
          MRET:begin
            pc_next_en <= 1;
            pc_next_o <= mepc;
            priviledge_mode_reg <= mstatus.mpp;
            mie.mtie <= 1'b1;
          end
          default:begin
            
            if(mip.mtip && (priviledge_mode_reg == PRIVILEDGE_MODE_U || mie.mtie && priviledge_mode_reg == PRIVILEDGE_MODE_M))begin // time interrupt exist and machine mode enable all interrupt
              if(priviledge_mode_reg == PRIVILEDGE_MODE_U)begin 
                mie.mtie <= 0; // unable the mtie, otherwise pc will stuck in mtvec
                mcause.interrupt <= 1'b1;
                mepc <= pc_now_i + 4;
                pc_next_en <= 1;
                pc_next_o <= {mtvec[31:2],2'b00};
                mcause.exception_code <= 31'h7;
                mstatus.mpp <= PRIVILEDGE_MODE_U;
                priviledge_mode_reg <= PRIVILEDGE_MODE_M;
              end else begin
                pc_next_en <= 0;
                pc_next_o <= 32'b0;
              end
              // else if(priviledge_mode_i == PRIVILEDGE_MODE_M)begin
              //   mie.mtie <= 0; // unable the mtie, otherwise pc will stuck in mtvec
              //   mcause.interrupt <= 1'b1;
              //   mcause.exception_code <= 31'h7;
              //   mepc <= pc_now_i + 4;
              //   mstatus.mpp <= PRIVILEDGE_MODE_M;
              //   priviledge_mode_o <= PRIVILEDGE_MODE_M;
              //   pc_next_o <= {mtvec[31:2],2'b00};
              // end
            end else begin
              pc_next_en <= 0;
              pc_next_o <= 32'b0;
            end 
          end
        endcase
      end
    end
endmodule