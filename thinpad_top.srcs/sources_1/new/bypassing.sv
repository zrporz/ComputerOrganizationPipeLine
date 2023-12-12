`include "./headers/exception.svh"
module bypassing #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
) (
    input wire idex_rf_wen_i,
    input wire [4:0] idex_rf_waddr_reg_i,
    input wire [1:0] idex_dm_mux_sel_i,
    input wire [DATA_WIDTH-1:0] idex_pc_addr_i,
    input wire [DATA_WIDTH-1:0] idex_alu_result_i,

    input wire exme_rf_wen_i,
    input wire [4:0] exme_rf_waddr_reg_i,
    input wire [1:0] exme_dm_mux_sel_i,
    input wire [DATA_WIDTH-1:0] exme_pc_addr_i,
    input wire [DATA_WIDTH-1:0] exme_alu_result_i,
    input wire [DATA_WIDTH-1:0] exme_dm_data_i,
    input wire exme_dm_ack_i,
    
    input wire mewb_rf_wen_i,
    input wire [4:0] mewb_rf_waddr_reg_i,
    input wire [DATA_WIDTH-1:0] mewb_rf_wdata_i,


    input wire [4:0] ID_rs1,
    input wire [4:0] ID_rs2,

    output logic [DATA_WIDTH-1:0] ID_data1,
    output logic [DATA_WIDTH-1:0] ID_data2,

    // output logic [4:0] RF_rs1,
    // output logic [4:0] RF_rs2,

    input wire [DATA_WIDTH-1:0] RF_data1,
    input wire [DATA_WIDTH-1:0] RF_data2,

    output logic still_hazard_o
);

    logic hazard1_solved, hazard2_solved;

    always_comb begin
        // RF_rs1 = ID_rs1; RF_rs2 = ID_rs2;

        still_hazard_o = !hazard1_solved || !hazard2_solved;


        // hazard1_solved related logic
        hazard1_solved = 1;
        ID_data1 = RF_data1;

        if(ID_rs1 == 0) begin
            hazard1_solved = 1;
            ID_data1 = 32'h0;
        end
        else if (mewb_rf_wen_i && ID_rs1 == mewb_rf_waddr_reg_i) begin
            hazard1_solved = 1;
            ID_data1 = mewb_rf_wdata_i;
        end
        else if (exme_rf_wen_i && ID_rs1 == exme_rf_waddr_reg_i) begin
            if(exme_dm_mux_sel_i == `DM_MUX_SEL_PC) begin
                hazard1_solved = 1;
                ID_data1 = exme_pc_addr_i + 4;
            end
            else if(exme_dm_mux_sel_i == `DM_MUX_SEL_ALU) begin
                hazard1_solved = 1;
                ID_data1 = exme_alu_result_i;
            end
            else if (exme_dm_mux_sel_i == `DM_MUX_SEL_MEM) begin
                if(exme_dm_ack_i) begin
                    hazard1_solved = 1;
                    ID_data1 = exme_dm_data_i;
                end
                else begin
                    hazard1_solved = 0;
                end
            end
            else begin
                hazard1_solved = 0;
            end
        end
        else if (idex_rf_wen_i && ID_rs1 == idex_rf_waddr_reg_i) begin
            if(idex_dm_mux_sel_i == `DM_MUX_SEL_PC) begin
                hazard1_solved = 1;
                ID_data1 = idex_pc_addr_i + 4;
            end
            else if(idex_dm_mux_sel_i == `DM_MUX_SEL_ALU) begin
                hazard1_solved = 1;
                ID_data1 = idex_alu_result_i;
            end
            else if(idex_dm_mux_sel_i == `DM_MUX_SEL_MEM) begin
                hazard1_solved = 0;
            end
            else begin
                hazard1_solved = 0;
            end
        end


        // hazard2_solved related logic
        hazard2_solved = 1;
        ID_data2 = RF_data2;
        if(ID_rs2 == 0) begin
            hazard2_solved = 1;
            ID_data2 = 32'h0;
        end
        else if (mewb_rf_wen_i && ID_rs2 == mewb_rf_waddr_reg_i) begin
            hazard2_solved = 1;
            ID_data2 = mewb_rf_wdata_i;
        end
        else if (exme_rf_wen_i && ID_rs2 == exme_rf_waddr_reg_i) begin
            if(exme_dm_mux_sel_i == `DM_MUX_SEL_PC) begin
                hazard2_solved = 1;
                ID_data2 = exme_pc_addr_i + 4;
            end
            else if(exme_dm_mux_sel_i == `DM_MUX_SEL_ALU) begin
                hazard2_solved = 1;
                ID_data2 = exme_alu_result_i;
            end
            else if (exme_dm_mux_sel_i == `DM_MUX_SEL_MEM) begin
                if(exme_dm_ack_i) begin
                    hazard2_solved = 1;
                    ID_data2 = exme_dm_data_i;
                end
                else begin
                    hazard2_solved = 0;
                end
            end
            else begin
                hazard2_solved = 0;
            end
        end
        else if (idex_rf_wen_i && ID_rs2 == idex_rf_waddr_reg_i) begin
            if(idex_dm_mux_sel_i == `DM_MUX_SEL_PC) begin
                hazard2_solved = 1;
                ID_data2 = idex_pc_addr_i + 4;
            end
            else if(idex_dm_mux_sel_i == `DM_MUX_SEL_ALU) begin
                hazard2_solved = 1;
                ID_data2 = idex_alu_result_i;
            end
            else if(idex_dm_mux_sel_i == `DM_MUX_SEL_MEM) begin
                hazard2_solved = 0;
            end
            else begin
                hazard2_solved = 0;
            end
        end

    end



endmodule