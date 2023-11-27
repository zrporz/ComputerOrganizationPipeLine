`include "../headers/exception.svh"
module Csr#(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input wire clk_i,
    input wire rst_i,
    input wire [ADDR_WIDTH-1:0]inst_i, // instruction
    input wire [DATA_WIDTH-1:0]rf_rdata_a_i, // rs1 data
    input wire [1:0] priviledge_mode_i, // 00:User, 01:Supervisor, 10:Reserved, 11:Machine
    input wire [ADDR_WIDTH-1:0] pc_now_i,
    output reg [DATA_WIDTH-1:0]rf_wdata_o, // rd
    output reg [1:0] priviledge_mode_o,
    output reg [ADDR_WIDTH-1:0] pc_next_o,
    // mtimer -> cpu -> csr
    input wire mtime_exceed_i
);
    parameter  CSRRC= 32'b????_????_????_????_?011_????_?111_0011;
    parameter  CSRRS= 32'b????_????_????_????_?010_????_?111_0011;
    parameter  CSRRW= 32'b????_????_????_????_?001_????_?111_0011;
    parameter  EBREAK= 32'b0000_0000_0000_0001_0000_0000_0111_0011;
    parameter  ECALL= 32'b0000_0000_0000_0000_0000_0000_0111_0011;
    parameter  MRET= 32'b0011_0000_0010_0000_0000_0000_0111_0011;
    typedef enum logic [11:0]{
        MSTATUS= 12'h300,
        MIE= 12'h304,
        MTVEC= 12'h305,
        MSCRATCH= 12'h340,
        MEPC= 12'h341,
        MCAUSE= 12'h342,
        MIP= 12'h344
    } csr_reg_t;

    mtvec_t mtvec;
    mscratch_t mscratch;
    mepc_t mepc;
    mcause_t mcause;
    mstatus_t mstatus;
    mie_t mie;
    mip_t mip;
    // always_comb begin
    //   if(mip.mtip && mie.mtie)begin // time interrupt exist and machine mode enable all interrupt
        
    //   end 
    // end
    always_comb begin
      rf_wdata_o = 32'b0;
      casez(inst_i)
        CSRRC,CSRRS,CSRRW: begin
          case(inst_i[31:20])
            MSTATUS:begin
              rf_wdata_o = mstatus ;
            end
            MTVEC:begin
              rf_wdata_o = mtvec;
            end
            MCAUSE:begin
              rf_wdata_o = mcause;
            end
            MIP:begin
              rf_wdata_o = mip;
            end
            MIE:begin
              rf_wdata_o = mie;
            end
            MSCRATCH:begin
              rf_wdata_o = mscratch;
            end
            MEPC:begin
              rf_wdata_o = mepc;
            end            
          endcase
        end
          
      endcase
    end
    always_ff @ (posedge clk_i) begin
      if (rst_i) begin
        mtvec <= 32'b0;
        mscratch <= 32'b0;
        mepc <= 32'b0;
        mcause <= 32'b0;
        mstatus <= 32'b0;
        mie <= 32'b0;
        mip <= 32'b0;
      end else begin
        if(mtime_exceed_i && mie.mtie )begin // time interrupt exist and machine mode enable all interrupt
          mip.mtip <= 1'b1;
          mcause.interrupt = 1'b1;
          if(priviledge_mode_i == PRIVILEDGE_MODE_U)begin
            mcause.exception_code = 31'h4;
            priviledge_mode_o = PRIVILEDGE_MODE_M;
          end else if(priviledge_mode_i == PRIVILEDGE_MODE_M)begin
            mcause.exception_code = 31'h7;
            priviledge_mode_o = PRIVILEDGE_MODE_U;
          end
        end else begin
          casez(inst_i)
            CSRRC:begin
              priviledge_mode_o <= priviledge_mode_i;
              if(inst_i[19:15])begin // only write csr when rs1 is not x0
                case(inst_i[31:20])
                  MSTATUS:begin
                    mstatus <= mstatus & ~rf_rdata_a_i;
                  end
                  MTVEC:begin
                    mtvec <= mtvec & ~rf_rdata_a_i;
                  end
                  MCAUSE:begin
                    mcause <= mcause & ~rf_rdata_a_i;
                  end
                  MIP:begin
                    mip <= mip & ~rf_rdata_a_i;
                  end
                  MIE:begin
                    mie <= mie & ~rf_rdata_a_i;
                  end
                  MSCRATCH:begin
                    mscratch <= mscratch & ~rf_rdata_a_i;
                  end
                  MEPC:begin
                    mepc <= mepc & ~rf_rdata_a_i;
                  end            
                endcase
              end
            end
            CSRRS:begin
              priviledge_mode_o <= priviledge_mode_i;
              if(inst_i[19:15])begin
                case(inst_i[31:20])
                  MSTATUS:begin
                    mstatus <= mstatus | rf_rdata_a_i;
                  end
                  MTVEC:begin
                    mtvec <= mtvec | rf_rdata_a_i;
                  end
                  MCAUSE:begin
                    mcause <= mcause | rf_rdata_a_i;
                  end
                  MIP:begin
                    mip <= mip | rf_rdata_a_i;
                  end
                  MIE:begin
                    mie <= mie | rf_rdata_a_i;
                  end
                  MSCRATCH:begin
                    mscratch <= mscratch | rf_rdata_a_i;
                  end
                  MEPC:begin
                    mepc <= mepc | rf_rdata_a_i;
                  end            
                endcase
              end
            end
            CSRRW:begin
              priviledge_mode_o <= priviledge_mode_i;
              if(inst_i[19:15])begin
                case(inst_i[31:20])
                  MSTATUS:begin
                    mstatus <= rf_rdata_a_i ;
                  end
                  MTVEC:begin
                    mtvec <= rf_rdata_a_i ;
                  end
                  MCAUSE:begin
                    mcause <= rf_rdata_a_i ;
                  end
                  MIP:begin
                    mip <= rf_rdata_a_i ;
                  end
                  MIE:begin
                    mie <= rf_rdata_a_i ;
                  end
                  MSCRATCH:begin
                    mscratch <= rf_rdata_a_i ;
                  end
                  MEPC:begin
                    mepc <= rf_rdata_a_i ;
                  end
                endcase
              end
            end
            EBREAK:begin
              mepc <= pc_now_i; 
              mcause.interrupt <= 1'b0;
              mcause.exception_code <= 31'h3;
              mstatus.mpp <= priviledge_mode_i;
              priviledge_mode_o <= PRIVILEDGE_MODE_M;
              pc_next_o <= {mtvec[31:2],2'b00};
            end
            ECALL:begin
              mepc <= pc_now_i; // ECALL is a exception, not interruption, thus mepc should save current pc , not pc+4
              mcause.interrupt <= 2'b0;
              mstatus.mpp <= priviledge_mode_i;
              pc_next_o <= {mtvec[31:2],2'b00};
              if(priviledge_mode_i == PRIVILEDGE_MODE_U)begin // Environment call from user mode
                mcause.exception_code <= 31'h8;
                priviledge_mode_o <= PRIVILEDGE_MODE_M;
              end else if(priviledge_mode_i == PRIVILEDGE_MODE_M)begin //Environment call from machine mode
                mcause.exception_code <= 31'hb;
                priviledge_mode_o <= PRIVILEDGE_MODE_U;
              end
            end
            MRET:begin
              pc_next_o <= mepc;
              priviledge_mode_o <= mstatus.mpp;
            end
            default:begin
              pc_next_o <= 32'b0;
              priviledge_mode_o <= priviledge_mode_i;
            end
          endcase
        end
      end
    end
endmodule