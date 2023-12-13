module PcController#(
   parameter ADDR_WIDTH = 32,
   parameter DATA_WIDTH = 32
)(
    input wire [ADDR_WIDTH-1:0] pc_i,
    input wire [ADDR_WIDTH-1:0] pc_seq_nxt_i,
    input wire [ADDR_WIDTH-1:0] pc_branch_nxt_i,
    input wire pc_branch_nxt_en,
    input wire [ADDR_WIDTH-1:0] pc_csr_nxt_i,
    input wire pc_csr_nxt_en,
    output reg [ADDR_WIDTH-1:0] pc_nxt_o,

    input wire [ADDR_WIDTH-1:0] pc_predict_nxt_i,

    // add branching signal
    output logic branching_o
);
    // priority: csr > branch > seq
    // pure combination 
    logic [ADDR_WIDTH-1:0] pc_nxt;
    always_comb begin
       pc_nxt = pc_i;
       branching_o = 1;    // bubble
       if(pc_csr_nxt_en)begin
          pc_nxt = pc_csr_nxt_i;
          branching_o = 1; // csr
       end else if(pc_branch_nxt_en)begin
          pc_nxt = pc_branch_nxt_i;
          branching_o = 1; // normal branch
       end else if(pc_predict_nxt_i)begin
          pc_nxt = pc_predict_nxt_i;
          branching_o = 0;
       end else if(pc_seq_nxt_i)begin
          pc_nxt = pc_seq_nxt_i;
          branching_o = 0; // +4 or bubble ?
       end
    end
    assign pc_nxt_o = pc_nxt;
endmodule