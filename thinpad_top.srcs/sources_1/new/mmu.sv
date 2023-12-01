// 这个文件�? thinpad_top.sv 中被调用
// 目前是没�? TLB 的版�?
`include "./headers/exception.svh"
`include "./headers/mem.svh"
module mmu (
    input wire clk,
    input wire rst,

    // master
    input wire [31:0] master_addr_in,
    input wire [31:0] master_data_in,
    output reg [31:0] master_data_out,  // 这个�?要读�? mux 中过来的数据
    input wire master_we_in,
    input wire [3:0] master_sel_in,
    input wire master_stb_in,
    input wire master_cyc_in,
    output reg master_ack_out,
    
    // mux
    output reg [31:0] mux_addr_out,
    output reg [31:0] mux_data_out,
    input wire [31:0] mux_data_in,       // �?终需要把这个 mux_data_in 数据写到 master_data_out �?
    output reg mux_we_out,
    output reg [3:0] mux_sel_out,
    output reg mux_stb_out,
    output reg mux_cyc_out,
    input wire mux_ack_in,

    // mode
    // input priviledge_mode_t mode_in,
    input wire[1:0] mode_in,
    // satp
    input satp_t satp_in
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

typedef enum logic [3:0] { 
    DEVICE_SRAM,
    DEVICE_UART,
    DEVICE_VGA,
    DEVICE_FLASH,
    DEVICE_MTIMER,
    DEVICE_UNKNOWN
} device_t;
device_t device;

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
    vpn_1 = master_addr_in[31:22];
    vpn_2 = master_addr_in[21:12];
    offset = master_addr_in[11:0];

    // 取出页表项中的实地址
    pte_1_ppn_1 = pte_1[31:20];
    pte_1_ppn_0 = pte_1[19:10];
    pte_2_ppn_1 = pte_2[31:20];
    pte_2_ppn_0 = pte_2[19:10];

    if ((satp_mode && (mode_in != 2'b11) && (device == DEVICE_SRAM) && master_stb_in) || (page_table_state != STATE_INIT)) begin
        page_table_en <= 1;
    end else begin
        page_table_en <= 0;
    end
end

// 状�?�机
typedef enum logic [2:0] {
    STATE_INIT = 0,
    STATE_READ_1 = 1,
    STATE_WAIT_1 = 2,
    STATE_READ_2 = 3,
    STATE_WAIT_2 = 4,
    STATE_PPN_ACTION = 5,
    STATE_PPN_WAIT = 6
} state_p;

state_p page_table_state;

always_ff @ (posedge clk) begin
    if (rst) begin
        // 如果�? reset, 就全部置�? 0
        page_table_state <= STATE_INIT;
        pte_1 <= 32'b0;
        pte_2 <= 32'b0;
        master_return_data_out <= 32'b0;
    end else begin
        if (page_table_en) begin
            case (page_table_state)
                STATE_INIT: begin
                    pte_1 <= 32'b0;
                    pte_2 <= 32'b0;
                    master_return_data_out <= 32'b0;
                    page_table_state <= STATE_READ_1;
                end

                STATE_READ_1 : begin
                    if (mux_ack_in) begin
                        // 读取第一级页�?
                        pte_1 <= mux_data_in;
                        page_table_state <= STATE_WAIT_1;
                    end
                end

                STATE_WAIT_1: begin
                    page_table_state <=  STATE_READ_2;
                end

                STATE_READ_2 : begin
                    if (mux_ack_in) begin
                        // 读取第二级页�?
                        pte_2 <= mux_data_in;
                        page_table_state <= STATE_WAIT_2;
                    end
                end

                STATE_WAIT_2: begin
                    page_table_state <= STATE_PPN_ACTION;
                end

                STATE_PPN_ACTION : begin
                    if (mux_ack_in) begin
                        master_return_data_out <= mux_data_in;
                        page_table_state <= STATE_PPN_WAIT;
                    end
                end

                STATE_PPN_WAIT: begin
                    page_table_state <= STATE_INIT;
                end
            endcase

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
    master_data_out = mux_data_in;
    master_ack_out = mux_ack_in;

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
            STATE_PPN_ACTION : begin
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
                master_ack_out = 1;
                master_data_out = master_return_data_out;
            end
        endcase
    end
end
    
endmodule