`include "./headers/btb.svh"
module pc_btb_table #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input wire clk,
    input wire rst,

    input wire [ADDR_WIDTH-1:0] pc_now,
    output logic [ADDR_WIDTH-1:0] pc_predict,

    input wire branching, 
    input wire [ADDR_WIDTH-1:0] exe_pc,
    input wire [ADDR_WIDTH-1:0] exe_pc_next
);

    /* pc_now:
       [31:6] tag
       [5:2]  index
       [1:0]  offset = 2'b00
    */
    logic [25:0] pc_now_tag ;
    logic [3:0] pc_now_index ;
    assign pc_now_tag = pc_now[31:6];
    assign pc_now_index = pc_now[5:2];

    /*
    typedef struct packed {
        logic valid;                // whether the BTB entry is valid
        logic [31:0] target_addr;   // target address
        logic [25:0] source_tag;    // source address's tag, for compare
    } btb_entry
    */
    btb_entry btb_table [0:15]; // btb_table, contain 16 btb_entry
    // TODO: init btb_table ?
    btb_entry current_btb_entry;
    assign current_btb_entry = btb_table[pc_now_index];

    logic [25:0] exe_pc_tag  ;
    logic  [3:0] exe_pc_index;
    assign exe_pc_index = exe_pc[5:2];
    assign exe_pc_tag = exe_pc[31:6];


    // get pc_predict, combinational logic
    always_comb begin
        // hit or not?
        if (current_btb_entry.valid & (current_btb_entry.source_tag == pc_now_tag)) begin
            pc_predict = current_btb_entry.target_addr;
        end else begin
            pc_predict = 0;
        end
    end

    // update btb_table
    always_ff @(posedge clk) begin
        if (rst) begin
            btb_table[0] <= 0;
            btb_table[1] <= 0;
            btb_table[2] <= 0;
            btb_table[3] <= 0;
            btb_table[4] <= 0;
            btb_table[5] <= 0;
            btb_table[6] <= 0;
            btb_table[7] <= 0;
            btb_table[8] <= 0;
            btb_table[9] <= 0;
            btb_table[10] <= 0;
            btb_table[11] <= 0;
            btb_table[12] <= 0;
            btb_table[13] <= 0;
            btb_table[14] <= 0;
            btb_table[15] <= 0;
        end

        else begin

            if (branching & (exe_pc != 32'h8000_0000)) begin

               btb_table[exe_pc_index].valid <= 1;
               btb_table[exe_pc_index].target_addr <= exe_pc_next;
               btb_table[exe_pc_index].source_tag <= exe_pc_tag;

            end
        end
    end


endmodule