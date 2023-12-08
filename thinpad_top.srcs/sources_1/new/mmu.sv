// 这个文件 thinpad_top.sv 中被调用
// Disable TLB for now
// Look up to TLB first
// if TLB miss, then look up to Page Table
`include "./headers/exception.svh"
`include "./headers/mem.svh"
module mmu #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input wire clk,
    input wire rst,

    // master: to wishbone
    input wire [31:0] master_addr_in,
    input wire [31:0] master_data_in,
    output reg [31:0] master_data_out,  // 这个�?要读�? mux 中过来的数据
    input wire master_we_in,
    input wire [3:0] master_sel_in,
    input wire master_stb_in,
    input wire master_cyc_in,
    output reg master_ack_out,
    input wire flush_tlb_i,
    
    // mux: from wishbone
    output reg [31:0] mux_addr_out,
    output reg [31:0] mux_data_out,
    input wire [31:0] mux_data_in,       // �?终需要把这个 mux_data_in 数据写到 master_data_out �?
    output reg mux_we_out,
    output reg [3:0] mux_sel_out,
    output reg mux_stb_out,
    output reg mux_cyc_out,
    input wire mux_ack_in,

    // mode
    input wire[1:0] mode_in,
    // satp
    input satp_t satp_in,

    // mmu_if or mmu_em
    input wire is_if_mmu,
    // query write enable
    input wire query_wen,

    // tlb -> mmu, for exception
    output logic tlb_exception,
    output logic [30:0] tlb_exception_code,
    output logic[ADDR_WIDTH-1:0] if_exception_addr_o,  // VA
    output logic[ADDR_WIDTH-1:0] mem_exception_addr_o, // VA
    output logic[DATA_WIDTH-1:0] id_exception_instr_i,
    output logic id_exception_instr_wen
);

logic page_table_en; 
// satp 寄存�?
logic satp_mode;
logic [21:0] satp_ppn;

// 虚地�?
logic [9:0] vpn_1;
logic [9:0] vpn_2;
logic [11:0] offset;

// 实地�?
logic [31:0] pte_1;
logic [31:0] pte_2;
logic [11:0] pte_1_ppn_1;
logic [9:0] pte_1_ppn_0;
logic [11:0] pte_2_ppn_1;
logic [9:0] pte_2_ppn_0;

logic [31:0] master_return_data_out;

logic tlb_en;
logic tlb_ack;
logic [31:0] tlb_addr_out;

// TLB to MMU
logic tlb_translate_en;
logic [ADDR_WIDTH-1:0] tlb_translate_addr;
satp_t tlb_satp_out;
// MMU to TLB
logic tlb_translate_ack;
pte_t tlb_translate_in;

// for exception
logic translation_exception;

typedef enum logic [3:0] { 
    DEVICE_SRAM,
    DEVICE_UART,
    DEVICE_VGA,
    DEVICE_FLASH,
    DEVICE_MTIMER,
    DEVICE_UNKNOWN
} device_t;
device_t device;

// 状�?�机
typedef enum logic [4:0] {
    STATE_INIT = 0,
    STATE_READ_1 = 1,
    STATE_WAIT_1 = 2,
    STATE_READ_2 = 3,
    STATE_WAIT_2 = 4,
    STATE_PPN_ACTION = 5,
    STATE_PPN_WAIT = 6,
    STATE_TLB_ACTION = 7,
    STATE_TLB_WAIT = 8,
    STATE_ERROR = 9
} state_p;
state_p page_table_state;

always_comb begin
    // �? satp 寄存器中取出 mode �? ppn 信息
    satp_mode = satp_in.mode;
    satp_ppn = satp_in.ppn;

    device = DEVICE_SRAM;
    // TODO：根据地址决定 device
    // 不太确定这个东西是否是对的

    if (32'h10000000 <= master_addr_in && master_addr_in <= 32'h10000007) begin
        device = DEVICE_UART;
    end

    else if ((master_addr_in == 32'h0200bff8 || master_addr_in == 32'h0200bffc || master_addr_in == 32'h02004000 || master_addr_in == 32'h02004004)) begin
        device = DEVICE_MTIMER;
    end

    // if ((32'h7FC10000 <= master_addr_in) && ( master_addr_in <= 32'h7FFFF000)) begin
    //     device = DEVICE_SRAM; // BaseRAM
    // end else if ((32'h00000000 <= master_addr_in) && ( master_addr_in <= 32'h002FF000)) begin
    //     device = DEVICE_SRAM; // ExtRAM
    // end

    // 取出虚地�?
    // vpn_1 = master_addr_in[31:22];
    // vpn_2 = master_addr_in[21:12];
    // offset = master_addr_in[11:0];
    
    // same meaning as above
    vpn_1 = tlb_translate_addr[31:22];
    vpn_2 = tlb_translate_addr[21:12];
    offset = tlb_translate_addr[11:0];

    // 取出页表项中的实地址
    pte_1_ppn_1 = pte_1[31:20];
    pte_1_ppn_0 = pte_1[19:10];
    pte_2_ppn_1 = pte_2[31:20];
    pte_2_ppn_0 = pte_2[19:10];

    if ((satp_mode && (mode_in != 2'b11) && (device == DEVICE_SRAM) && master_stb_in) || (page_table_state != STATE_INIT)) begin
        //tlb_en = 1;  // TODO: check its correctness
        
        tlb_en = 1;
        page_table_en = 1;
    end else begin
        tlb_en = 0;
        page_table_en = 0;
    end
end

logic is_translating;
assign is_translating = (page_table_state != STATE_INIT) && (page_table_state != STATE_TLB_ACTION) && (page_table_state != STATE_TLB_WAIT);
logic is_tlb;
assign is_tlb = (page_table_state == STATE_TLB_ACTION) || (page_table_state == STATE_TLB_WAIT);


logic [ADDR_WIDTH-1:0] last_master_addr_in;
logic same_master_addr_in;
assign same_master_addr_in = (last_master_addr_in == master_addr_in);

assign translation_exception = (page_table_state == STATE_ERROR);

always_ff @ (posedge clk) begin
    if (rst) begin
        // 如果�? reset, 就全部置�? 0
        page_table_state <= STATE_INIT;
        pte_1 <= 32'b0;
        pte_2 <= 32'b0;
        master_return_data_out <= 32'b0;
        tlb_translate_ack <= 0;
        last_master_addr_in <= 0;
    end else begin
        last_master_addr_in <= master_addr_in;
        if ((page_table_state != STATE_INIT && !same_master_addr_in) || flush_tlb_i) begin
            page_table_state <= STATE_INIT;
        end else begin
            if (page_table_en && ((tlb_en && tlb_ack) || is_tlb)) begin
                case (page_table_state)
                    STATE_INIT: begin
                        page_table_state <= STATE_TLB_ACTION;
                    end
                    STATE_TLB_ACTION: begin
                        if (mux_ack_in) begin
                            master_return_data_out <= mux_data_in;
                            page_table_state <= STATE_TLB_WAIT;
                        end
                    end

                    STATE_TLB_WAIT: begin
                        page_table_state <= STATE_INIT;
                    end
                endcase 
                
            end

            //if (page_table_en && !tlb_ack && tlb_translate_en) begin
            if (page_table_en && (!tlb_en || !tlb_ack || is_translating)) begin
                case (page_table_state)
                    STATE_INIT: begin
                        if (tlb_translate_en) begin
                            pte_1 <= 32'b0;
                            pte_2 <= 32'b0;
                            master_return_data_out <= 32'b0;
                            page_table_state <= STATE_READ_1;
                        end
                    end
                    STATE_READ_1 : begin
                        if (mux_ack_in) begin
                            // 读取第一级页�?
                            pte_1 <= mux_data_in;
                            page_table_state <= STATE_WAIT_1;
                        end
                    end

                    STATE_WAIT_1: begin
                        // check pte_1, add STATE_ERROR
                        // V: pte_1[0]
                        // R: pte_1[1]
                        // W: pte_1[2]
                        
                        if ((~pte_1[0]) || (~pte_1[1] && pte_1[2])) begin
                            page_table_state <= STATE_ERROR;
                        end else begin
                            page_table_state <=  STATE_READ_2;
                        end
                    end

                    STATE_READ_2 : begin
                        if (mux_ack_in) begin
                            // 读取第二级页�?
                            pte_2 <= mux_data_in;
                            page_table_state <= STATE_WAIT_2;
                        end
                    end

                    STATE_WAIT_2: begin
                        // correct at here
                        tlb_translate_ack <= 1;
                        tlb_translate_in <= pte_2;
                        page_table_state <= STATE_PPN_ACTION;
                    end

                    STATE_PPN_ACTION : begin
                        tlb_translate_ack <= 0;
                        if(tlb_exception)begin
                            page_table_state <= STATE_ERROR;
                        end
                        if (mux_ack_in) begin
                            master_return_data_out <= mux_data_in;
                            page_table_state <= STATE_PPN_WAIT;
                        end
                    end

                    STATE_PPN_WAIT: begin
                        page_table_state <= STATE_INIT;
                    end

                    STATE_ERROR: begin
                        page_table_state <= STATE_INIT;
                    end
                endcase

            end
        end
    end
end

assign mux_cyc_out = mux_stb_out;

// output signals
always_comb begin
    mux_addr_out = master_addr_in;
    mux_data_out = master_data_in;
    mux_we_out = master_we_in;
    mux_sel_out = master_sel_in;
    mux_stb_out = master_stb_in;
    // mux_cyc_out = master_cyc_in;
    if (master_stb_in) begin
        master_data_out = mux_data_in;
        master_ack_out = mux_ack_in;
    end else begin
        master_data_out = 0;
        master_ack_out = 0;
    end

    // tlb_translate_ack = 0;

    if (satp_mode && (mode_in != 2'b11) && (device == DEVICE_SRAM) && master_stb_in && master_cyc_in) begin
        case (page_table_state)
            STATE_INIT: begin
                mux_addr_out = 0;
                mux_data_out = 0;
                mux_we_out = 0;
                mux_sel_out = 0;
                mux_stb_out = 0;
                master_data_out = 0;
                master_ack_out = 0;
            end
            STATE_READ_1 : begin
                mux_addr_out = {satp_ppn[19:0], vpn_1, 2'b00};
                mux_data_out = 0;
                mux_we_out = 0; // read
                mux_sel_out = 4'b1111;
                mux_stb_out = 1;
                master_ack_out = 0;
                master_data_out = 0;
            end
            STATE_WAIT_1: begin
                mux_addr_out = 0;
                mux_data_out = 0;
                mux_we_out = 0;
                mux_sel_out = 0;
                mux_stb_out = 0;
                master_ack_out = 0;
                master_data_out = 0;
            end
            STATE_READ_2: begin
                mux_addr_out = {pte_1_ppn_1[9:0], pte_1_ppn_0, vpn_2, 2'b00};
                mux_data_out = 0;
                mux_we_out = 0; // read
                mux_sel_out = 4'b1111;
                mux_stb_out = 1;
                master_ack_out = 0;
                master_data_out = 0;
            end
            STATE_WAIT_2: begin
                mux_addr_out = 0;
                mux_data_out = 0;
                mux_we_out = 0;
                mux_sel_out = 0;
                mux_stb_out = 0;
                master_ack_out = 0;
                master_data_out = 0;
            end
            STATE_PPN_ACTION: begin
                mux_addr_out = {pte_2_ppn_1[9:0], pte_2_ppn_0, offset};
                mux_data_out = master_data_in;
                mux_we_out = master_we_in; // read
                mux_sel_out = master_sel_in;
                mux_stb_out = 1;
                master_ack_out = 0;
                master_data_out = 0;

                

            end
            STATE_PPN_WAIT: begin
                mux_addr_out = 0;
                mux_data_out = 0;
                mux_we_out = 0;
                mux_sel_out = 0;
                mux_stb_out = 0;
                // Check whether signals used

                // NOT DATA, ADDR!
                // tlb_translate_ack = 1;
                // tlb_translate_data_in = master_return_data_out;
                // end else begin
                //     tlb_translate_ack = 0;
                //     tlb_translate_data_in = 32'hffffffff;

                master_ack_out = 1;
                master_data_out = master_return_data_out;
            end
            STATE_TLB_ACTION: begin
                mux_addr_out = tlb_addr_out;
                mux_data_out = master_data_in;
                mux_we_out = master_we_in; // read
                mux_sel_out = master_sel_in;
                mux_stb_out = 1;
                master_ack_out = 0;
                master_data_out = 0;
            end
            STATE_TLB_WAIT: begin
                mux_addr_out = 0;
                mux_data_out = 0;
                mux_we_out = 0;
                mux_sel_out = 0;
                mux_stb_out = 0;
                // Check whether signals used

                master_ack_out = 1;
                master_data_out = master_return_data_out;
            end
            STATE_ERROR: begin
                mux_addr_out = 0;
                mux_data_out = 0;
                mux_we_out = 0;
                mux_sel_out = 0;
                mux_stb_out = 0;
                master_data_out = 0;
                master_ack_out = 1; // TRY
            end
        endcase
    end
end



mmu_tlb TLB(
    .clk(clk),
    .rst(rst),

    .mode_in(mode_in),
    .satp_in(satp_in),
    .query_en(tlb_en),
    .query_addr(master_addr_in),

    .tlb_ack(tlb_ack),
    .tlb_addr_out(tlb_addr_out),

    .translate_en(tlb_translate_en),
    .translate_addr(tlb_translate_addr),
    .satp_out(tlb_satp_out),

    .translate_ack(tlb_translate_ack),
    .translate_pte_in(tlb_translate_in),

    .tlb_is_mmu_if(is_if_mmu),
    .mux_we_out(mux_we_out),
    .translation_exception(translation_exception),
    .query_wen(query_wen),

    .tlb_exception(tlb_exception),
    .tlb_exception_code(tlb_exception_code),
    .if_exception_addr_o(if_exception_addr_o),
    .mem_exception_addr_o(mem_exception_addr_o),
    .id_exception_instr_i(id_exception_instr_i),
    .id_exception_instr_wen(id_exception_instr_wen),
    .flush_tlb_i(flush_tlb_i)
);

    
endmodule