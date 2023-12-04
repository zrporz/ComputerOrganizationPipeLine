module hazard_controler#(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input wire wb1_cyc_i,
    input wire wb1_ack_i,
    input wire wb0_cyc_i,
    input wire wb0_ack_i,
    input wire [4:0] rf_rdata_a_i,
    input wire [4:0] rf_rdata_b_i,
    input wire [4:0] idex_rf_waddr_reg_i,
    input wire [4:0] exme_rf_waddr_reg_i,
    input wire [4:0] mewb_rf_waddr_reg_i,
    input wire idex_rf_wen_i,
    input wire exme_rf_wen_i,
    input wire mewb_rf_wen_i,
    input wire use_rs2_i,
    // input wire [ADDR_WIDTH-1:0] pc_branch_nxt_i,
    input wire pc_branch_nxt_en,
    // input wire [ADDR_WIDTH-1:0] pc_csr_nxt_i,
    input wire pc_csr_nxt_en,
    output reg bubble_IF_o,
    output reg bubble_ID_o,
    output reg bubble_EXE_o,
    output reg bubble_MEM_o,
    output reg bubble_WB_o,
    output reg flush_IF_o,
    output reg flush_ID_o,
    output reg flush_EXE_o,
    output reg flush_MEM_o,
    output reg flush_WB_o
);
    always_comb begin
      bubble_IF_o = 0;
      bubble_ID_o = 0;
      bubble_EXE_o = 0;
      bubble_MEM_o = 0;
      bubble_WB_o = 0;
      flush_IF_o = 0;
      flush_ID_o = 0;
      flush_EXE_o = 0;
      flush_MEM_o = 0;
      flush_WB_o = 0;
      if(pc_csr_nxt_en)begin // Because MEM is rewrite the PC registor, pipeline should be flushed
        flush_IF_o = 1;
        flush_ID_o = 1;
        flush_EXE_o = 1;
      end else if(pc_branch_nxt_en)begin // Because EXE is rewrite the PC registor, pipeline should be flushed
        flush_IF_o = 1;
        flush_ID_o = 1;
      end else begin
        if(wb1_cyc_i && !wb1_ack_i)begin // MEM is writing/reading and it hasn't complete yet
          bubble_IF_o = 1;
          bubble_ID_o = 1;
          bubble_EXE_o = 1;
          bubble_MEM_o = 1;
        end else if(rf_rdata_a_i)begin
          if(idex_rf_wen_i && rf_rdata_a_i == idex_rf_waddr_reg_i )begin
            bubble_IF_o = 1;
            bubble_ID_o = 1;
          end else if (exme_rf_wen_i && rf_rdata_a_i == exme_rf_waddr_reg_i)begin
            bubble_IF_o = 1;
            bubble_ID_o = 1;
          end else if(mewb_rf_wen_i && rf_rdata_a_i == mewb_rf_waddr_reg_i) begin
            bubble_IF_o = 1;
            bubble_ID_o = 1;
          end else if(wb0_cyc_i && wb0_ack_i!=1)begin // IF is reading and it hasn't complete yet
            bubble_IF_o = 1;
          end 
        end else if(use_rs2_i && rf_rdata_b_i)begin
          if(idex_rf_wen_i && rf_rdata_b_i == idex_rf_waddr_reg_i )begin
            bubble_IF_o = 1;
            bubble_ID_o = 1;
          end else if (exme_rf_wen_i && rf_rdata_b_i == exme_rf_waddr_reg_i)begin
            bubble_IF_o = 1;
            bubble_ID_o = 1;
          end else if(mewb_rf_wen_i && rf_rdata_b_i == mewb_rf_waddr_reg_i) begin
            bubble_IF_o = 1;
            bubble_ID_o = 1;
          end else if(wb0_cyc_i && wb0_ack_i!=1)begin // IF is reading and it hasn't complete yet
            bubble_IF_o = 1;
          end 
        end else if(wb0_cyc_i && wb0_ack_i!=1)begin // IF is reading and it hasn't complete yet
          bubble_IF_o = 1;
        end 
        // if(wb0_cyc_i && wb0_ack_i!=1)begin // IF is reading and it hasn't complete yet
        //   bubble_IF_o = 1;
        // end 
        // // some stage in EXE, MEM, WB will write rd which read in ID stage
        // if(rf_rdata_a_i)begin
        //   if(idex_rf_wen_i && rf_rdata_a_i == idex_rf_waddr_reg_i )begin
        //     bubble_IF_o = 1;
        //     bubble_ID_o = 1;
        //   end else if (exme_rf_wen_i && rf_rdata_a_i == exme_rf_waddr_reg_i)begin
        //     bubble_IF_o = 1;
        //     bubble_ID_o = 1;
        //   end else if(mewb_rf_wen_i && rf_rdata_a_i == mewb_rf_waddr_reg_i) begin
        //     bubble_IF_o = 1;
        //     bubble_ID_o = 1;
        //   end
        // end else if(use_rs2_i && rf_rdata_b_i)begin
        //   if(idex_rf_wen_i && rf_rdata_b_i == idex_rf_waddr_reg_i )begin
        //     bubble_IF_o = 1;
        //     bubble_ID_o = 1;
        //   end else if (exme_rf_wen_i && rf_rdata_b_i == exme_rf_waddr_reg_i)begin
        //     bubble_IF_o = 1;
        //     bubble_ID_o = 1;
        //   end else if(mewb_rf_wen_i && rf_rdata_b_i == mewb_rf_waddr_reg_i) begin
        //     bubble_IF_o = 1;
        //     bubble_ID_o = 1;
        //   end
        // end
      end
    end
endmodule