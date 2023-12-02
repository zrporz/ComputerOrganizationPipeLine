`include "./headers/exception.svh"
`include "./headers/mem.svh"
module mmu_tlb #(
    parameter ADDR_WIDTH = 32, 
    parameter DATA_WIDTH = 32
) (
    input wire clk,
    input wire rst,

    // CPU to TLB
    input wire [1:0] mode_in,
    input satp_t satp_in,
    input wire query_en,
    input wire [ADDR_WIDTH-1:0] query_addr,

    // TLB to CPU
    output logic tlb_ack,
    output logic [DATA_WIDTH-1:0] tlb_addr_out,

    // TLB to MMU
    output logic translate_en,
    output logic [ADDR_WIDTH-1:0] translate_addr,
    output satp_t satp_out,

    // MMU to TLB
    input wire translate_ack,
    input pte_t translate_pte_in
);

    tlbe_t tlb [31:0];
    tlbe_t tlbe;
    pte_t pte;
    logic [1:0] rsw;
    tlb_addr_t tlb_virt_addr;
    assign tlb_virt_addr = query_addr;
    logic [ADDR_WIDTH-1:0] last_query_addr;

    always_comb begin
        if(mode_in == 2'b11 || satp_in.mode == 0) begin
            tlbe.tlbi = tlb_virt_addr.tlbi;
            tlbe.asid = satp_in.asid;

            rsw = 2'b00;
            pte = {2'b00, query_addr[31:12], rsw, 8'b00001111};  // TODO: check 
            tlbe.pte = pte;

            tlbe.valid = 1;            
        end else begin
            tlbe = tlb[tlb_virt_addr.tlbt];
        end

    end

    logic hit_tlb;
    logic is_translating;

    always_comb begin
        // TODO
        if(query_en && tlbe.valid == 1 && tlbe.tlbi == tlb_virt_addr.tlbi && (tlbe.asid == satp_in.asid || tlbe.pte.G)) begin
        //if(query_en && tlbe.valid == 1 && tlbe.tlbi == tlb_virt_addr.tlbi && (tlbe.asid == satp_in.asid || tlbe.pte.G)) begin
            hit_tlb = 1;
        end else begin
            hit_tlb = 0;
        end
    end

    logic same_translate_query;
    assign same_translate_query = (last_query_addr == query_addr);

    always_comb begin
        translate_en = 0;
        translate_addr = 32'hffffffff;
        // tlb_ack = hit_tlb || !query_en;
        tlb_ack = hit_tlb && !is_translating; // TODO: check
        satp_out = satp_in;
        if(query_en) begin
            if(hit_tlb) begin 
                translate_en = 0;
                translate_addr = 32'hffffffff;
                tlb_addr_out = {tlbe.pte.ppn1[9:0], tlbe.pte.ppn0, tlb_virt_addr.offset};
            // end else if(!translate_ack) begin
            // end else if(!same_translate_query) begin
            end else begin
                translate_en = 1;
                translate_addr = query_addr;
                satp_out = satp_in;
            end
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            tlb[0] <= 0;
            tlb[1] <= 0;
            tlb[2] <= 0;
            tlb[3] <= 0;
            tlb[4] <= 0;
            tlb[5] <= 0;
            tlb[6] <= 0;
            tlb[6] <= 0;
            tlb[7] <= 0;
            tlb[8] <= 0;
            tlb[9] <= 0;
            tlb[10] <= 0;
            tlb[11] <= 0;
            tlb[12] <= 0;
            tlb[13] <= 0;
            tlb[14] <= 0;
            tlb[15] <= 0;
            tlb[16] <= 0;
            tlb[17] <= 0;
            tlb[18] <= 0;
            tlb[19] <= 0;
            tlb[20] <= 0;
            tlb[21] <= 0;
            tlb[22] <= 0;
            tlb[23] <= 0;
            tlb[24] <= 0;
            tlb[25] <= 0;
            tlb[26] <= 0;
            tlb[27] <= 0;
            tlb[28] <= 0;
            tlb[29] <= 0;
            tlb[30] <= 0;
            tlb[31] <= 0;
            last_query_addr <= 0;
            is_translating <= 0;
        end else begin
            last_query_addr <= query_addr;

            if (translate_ack) begin
                is_translating <= 0;
            end else if (translate_en) begin
                is_translating <= 1;
            end

            if(query_en && translate_ack) begin
                tlb[tlb_virt_addr.tlbt] <= {
                    tlb_virt_addr.tlbi,
                    satp_in.asid,
                    translate_pte_in,
                    1'b1
                };
            end
        end
    end



endmodule