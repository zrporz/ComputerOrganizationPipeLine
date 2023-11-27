module PcController#(
   parameter ADDR_WIDTH = 32,
   parameter DATA_WIDTH = 32
)(
    input wire [ADDR_WIDTH-1:0] pc_i,
    input wire [ADDR_WIDTH-1:0] pc_seq_nxt_i,
    input wire [ADDR_WIDTH-1:0] pc_branch_nxt_i,
    input wire [ADDR_WIDTH-1:0] pc_csr_nxt_i,
    output reg [ADDR_WIDTH-1:0] pc_nxt_o
);
    // priority: csr > branch > seq
    // pure combination 
    logic [ADDR_WIDTH-1:0] pc_nxt;
    always_comb begin
       pc_nxt = pc_i;
       if(pc_csr_nxt_i)begin
          pc_nxt = pc_csr_nxt_i;
       end else if(pc_branch_nxt_i)begin
          pc_nxt = pc_branch_nxt_i;
       end else if(pc_seq_nxt_i)begin
          pc_nxt = pc_seq_nxt_i;
       end
    end
    assign pc_nxt_o = pc_nxt;
endmodule