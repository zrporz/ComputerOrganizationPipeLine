module pipeline_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input wire clk_i,
    input wire rst_i,

    // wishbone master0
    output reg wb0_cyc_o,
    output reg wb0_stb_o,
    input wire wb0_ack_i,
    output reg [ADDR_WIDTH-1:0] wb0_adr_o,
    output reg [DATA_WIDTH-1:0] wb0_dat_o,
    input wire [DATA_WIDTH-1:0] wb0_dat_i,
    output reg [DATA_WIDTH/8-1:0] wb0_sel_o,
    output reg wb0_we_o,
    // wishbone master1
    output reg wb1_cyc_o,
    output reg wb1_stb_o,
    input wire wb1_ack_i,
    output reg [ADDR_WIDTH-1:0] wb1_adr_o,
    output reg [DATA_WIDTH-1:0] wb1_dat_o,
    input wire [DATA_WIDTH-1:0] wb1_dat_i,
    output reg [DATA_WIDTH/8-1:0] wb1_sel_o,
    output reg wb1_we_o,
    input wire [31:0] dip_sw,
    output wire [15:0] leds
);

  typedef enum logic [2:0] { 
    R_TYPE = 3'b001, 
    I_TYPE = 3'b010, 
    S_TYPE = 3'b011, 
    B_TYPE = 3'b100, 
    U_TYPE = 3'b101, 
    J_TYPE = 3'b110
  } instrction_type_t;
  typedef enum logic [6:0] {
    LUI = 7'b0110111,
    BEQ_BNE = 7'b1100011,
    LB_LW = 7'b0000011,
    SB_SW = 7'b0100011, // SB or SW
    ADDI_ANDI_ORI_SLLI_SRLI = 7'b0010011, // ADDI or ANDI
    ADD_OR_AND_XOR = 7'b0110011,
    JAL = 7'b1101111,
    JALR = 7'b1100111,
    AUIPC = 7'b0010111
  } opcode_type_t;
  typedef enum logic [3:0] {
    ALU_DEFAULT = 4'b0000,
    ALU_ADD = 4'b0001, 
    ALU_SUB = 4'b0010, 
    ALU_AND = 4'b0011,
    ALU_OR = 4'b0100,
    ALU_XOR = 4'b0101,
    ALU_NOT = 4'b0110,
    ALU_SLL = 4'b0111,
    ALU_SRL = 4'b1000,
    ALU_SRA = 4'b1001,
    ALU_ROL = 4'b1010
  } op_type_t;

  // before IF reg
  reg [31:0] pc_reg;
//   reg [31:0] pc_now_reg;

  // IF-ID reg
  reg [31:0] ifid_inst_reg;
  reg [31:0] ifid_pc_now_reg;
  instrction_type_t ifid_instr_type_reg;

  // ID-EXE reg
  reg [31:0] idex_inst_reg;
  reg [31:0] idex_rf_rdata_a_reg;
  reg [31:0] idex_rf_rdata_b_reg;
  reg [4:0] idex_rf_waddr_reg;
  reg [31:0] idex_imm_gen_reg;
  reg [31:0] idex_pc_now_reg;
  op_type_t idex_alu_op_reg;
  reg idex_use_rs2;
  reg idex_mem_en;
  instrction_type_t idex_instr_type_reg;
  reg idex_rf_wen;

  // EXE-MEM reg
  reg [31:0] exme_inst_reg;
  reg [31:0] exme_rf_rdata_a_reg;
  reg [31:0] exme_rf_rdata_b_reg;
  reg [4:0] exme_rf_waddr_reg;
  reg [31:0] exme_alu_result_reg;
  reg exme_rpc_wen;
  reg exme_mem_en;
  reg exme_use_rs2;
  reg[31:0] exme_pc_now_reg;
  instrction_type_t exme_instr_type_reg;
  reg exme_rf_wen;
  reg exme_state; // this reg just use to store the state of mem_state, not pass down
  reg[1:0] exme_bias; //same to above, save for lb
  reg[31:0] exme_inst_reg_copy;
  reg[5:0] exme_rf_waddr_reg_copy;

  // MEM-WB reg
  reg mewb_rf_wen;
  reg [4:0] mewb_rf_waddr_reg;
  reg [31:0] mewb_rf_wdata_reg;
  reg [31:0] mewb_rpc_wdata_reg;
  reg mewb_rpc_wen;
  instrction_type_t mewb_instr_type_reg;

  //=========== REGFILE MODULE BEGIN ===========
  reg [31:0] rf_writeback_reg; // 写回寄存器的
  reg [31:0] rf_wdata_o;
  reg [4:0] rf_rdata_a_i; //rs1_addr
  reg [4:0] rf_rdata_b_i; //rs2_addr
  reg [31:0] rf_rdata_a_o; //rs1_data
  reg [31:0] rf_rdata_b_o; //rs2_data
  logic [4:0] rf_waddr_o; //rd
  logic rf_we_o; // write enable, 1: write in
  RegFile32 pipeline_regfile(
    .clk(clk_i),
    .reset(rst_i),
    .raddr_a(rf_rdata_a_i),
    .raddr_b(rf_rdata_b_i),
    .rdata_a(rf_rdata_a_o),
    .rdata_b(rf_rdata_b_o),
    .waddr(rf_waddr_o),
    .wdata(rf_wdata_o),
    .we(rf_we_o)
  );
  always_comb begin
    rf_we_o = mewb_rf_wen;
    rf_waddr_o = mewb_rf_waddr_reg;
    rf_wdata_o = mewb_rf_wdata_reg;
  end
  //=========== REGFILE MODULE END ===========
  
  //=========== DECODER MODULE BEGIN ===========
  instrction_type_t imm_gen_type_o;
  logic [31:0] imm_gen_inst_o;
  logic [4:0] rd;
  logic use_rs2;
  always_comb begin
    rf_rdata_a_i = ifid_inst_reg[19:15]; //rs1
    rf_rdata_b_i = ifid_inst_reg[24:20]; //rs2
    rd = ifid_inst_reg[11:7]; //rd
    imm_gen_type_o = U_TYPE;
    imm_gen_inst_o = 32'b0;
    use_rs2 = 0;
    case(ifid_inst_reg[6:0])
      LUI:begin
        imm_gen_type_o = U_TYPE;
        imm_gen_inst_o = {ifid_inst_reg[31:12],12'b0};
        use_rs2 = 0;
      end 
      BEQ_BNE:begin
        imm_gen_type_o = B_TYPE;
        use_rs2 = 1;
        if(ifid_inst_reg[31])begin
            imm_gen_inst_o = {16'hFFFF,3'b111,ifid_inst_reg[31],ifid_inst_reg[7],ifid_inst_reg[30:25],ifid_inst_reg[11:8],1'b0};
        end else begin
            imm_gen_inst_o = {19'b0,ifid_inst_reg[31],ifid_inst_reg[7],ifid_inst_reg[30:25],ifid_inst_reg[11:8],1'b0};
        end 
        // imm_gen_inst_o[12] = inst_reg[31];
        // imm_gen_inst_o[10:5] = inst_reg[30:25];
        // imm_gen_inst_o[4:1] = inst_reg[11:8];
        // imm_gen_inst_o[11] = inst_reg[7];
      end
      LB_LW:begin // imm 做有符号扩展
        use_rs2 = 0;
        imm_gen_type_o = I_TYPE;
        imm_gen_inst_o[11:0] = ifid_inst_reg[31:20];
        if(ifid_inst_reg[31])begin
            imm_gen_inst_o[31:12]=20'hFFFFF;
        end else begin
            imm_gen_inst_o[31:12]=20'h00000;
        end
      end
      SB_SW:begin
        use_rs2 = 1;
        imm_gen_type_o = S_TYPE;
        imm_gen_inst_o[11:5] = ifid_inst_reg[31:25];
        imm_gen_inst_o[4:0] = ifid_inst_reg[11:7];
        if(ifid_inst_reg[31])begin
            imm_gen_inst_o[31:12]=20'hFFFFF;
        end else begin
            imm_gen_inst_o[31:12]=20'h00000;
        end
      end
      ADDI_ANDI_ORI_SLLI_SRLI:begin
        use_rs2 = 0;
        imm_gen_type_o = I_TYPE;
        imm_gen_inst_o[11:0] = ifid_inst_reg[31:20];
        if(ifid_inst_reg[31])begin
            imm_gen_inst_o[31:12]=20'hFFFFF;
        end else begin
            imm_gen_inst_o[31:12]=20'h00000;
        end
      end
      ADD_OR_AND_XOR:begin
        use_rs2 = 1;
        imm_gen_type_o = R_TYPE;
        imm_gen_inst_o = 0;
      end
      JAL:begin
        use_rs2 = 0;
        imm_gen_type_o = J_TYPE;
        imm_gen_inst_o[20:0] = {ifid_inst_reg[31],ifid_inst_reg[19:12],ifid_inst_reg[20],ifid_inst_reg[30:21],1'b0};
        if(ifid_inst_reg[31])begin
          imm_gen_inst_o[31:12]=20'hFFFFF;
        end else begin
          imm_gen_inst_o[31:12]=20'h00000;
        end
      end
      JALR:begin
        use_rs2 = 0;
        imm_gen_type_o = R_TYPE;
        imm_gen_inst_o[20:0] = {ifid_inst_reg[31],ifid_inst_reg[19:12],ifid_inst_reg[20],ifid_inst_reg[30:21],1'b0};
        if(ifid_inst_reg[31])begin
          imm_gen_inst_o[31:12]=20'hFFFFF;
        end else begin
          imm_gen_inst_o[31:12]=20'h00000;
        end
      end
      AUIPC:begin
        use_rs2 = 0;
        imm_gen_type_o = U_TYPE;
        imm_gen_inst_o = {ifid_inst_reg[31:12],12'b0};
      end
    endcase
  end
  //=========== DECODER MODULE END ===========
  
  //=========== Risk and Conflict Solver BEGIN===========
  wire bubble_IF;
  wire bubble_ID;
  wire bubble_EXE;
  wire bubble_MEM;
  wire bubble_WB;
  wire flush_IF;
  wire flush_ID;
  wire flush_EXE;
  wire flush_MEM;
  wire flush_WB;
  hazard_controler u_hazard_controler(
    .wb1_cyc_i(wb1_cyc_o),
    .wb1_ack_i(wb1_ack_i),
    .wb0_cyc_i(wb0_cyc_o),
    .wb0_ack_i(wb0_ack_i),
    .rf_rdata_a_i(rf_rdata_a_i),
    .rf_rdata_b_i(rf_rdata_b_i),
    .idex_rf_waddr_reg_i(idex_rf_waddr_reg),
    .exme_rf_waddr_reg_i(exme_rf_waddr_reg),
    .mewb_rf_waddr_reg_i(mewb_rf_waddr_reg),
    .idex_rf_wen_i(idex_rf_wen),
    .exme_rf_wen_i(exme_rf_wen),
    .mewb_rf_wen_i(mewb_rf_wen),
    .mewb_rpc_wen_i(mewb_rpc_wen),
    .use_rs2_i(use_rs2),
    .bubble_IF_o(bubble_IF),
    .bubble_ID_o(bubble_ID),
    .bubble_EXE_o(bubble_EXE),
    .bubble_MEM_o(bubble_MEM),
    .bubble_WB_o(bubble_WB),
    .flush_IF_o(flush_IF),
    .flush_ID_o(flush_ID),
    .flush_EXE_o(flush_EXE),
    .flush_MEM_o(flush_MEM),
    .flush_WB_o(flush_WB)
  );
  // end
  
  // end
  //=========== Risk and Conflict Solver END===========

  //=========== DEBUG MODULE BEGIN ===========
  logic[15:0] leds_r;
  assign leds = leds_r;
  always_comb begin 
    leds_r = 16'h0000;
    case(dip_sw)
      32'h1: leds_r = {wb0_cyc_o,wb0_stb_o,wb0_ack_i,wb0_we_o,wb0_sel_o,wb1_cyc_o,wb1_stb_o,wb1_ack_i,wb1_we_o,wb1_sel_o};
      // 32'h2: leds_r = wb0_stb_o;
      // 32'h4: leds_r = wb0_ack_i;
      32'h8: leds_r = wb0_adr_o[15:0];
      32'h10: leds_r = wb0_adr_o[31:16];
      32'h20: leds_r = wb0_dat_o[15:0];
      32'h40: leds_r = wb0_dat_o[31:16];
      32'h80: leds_r = wb0_dat_i[15:0];
      32'h100: leds_r = wb0_dat_i[31:16];
      // 32'h200: leds_r = wb0_sel_o;
      // 32'h400: leds_r = wb0_we_o;
      // 32'h800: leds_r = {8'b0,wb1_cyc_o,wb1_stb_o,wb1_ack_i,wb1_we_o,wb1_sel_o};
      // 32'h1000: leds_r = wb1_stb_o;
      // 32'h2000: leds_r = wb1_ack_i;
      32'h4000: leds_r = wb1_adr_o[15:0];
      32'h8000: leds_r = wb1_adr_o[31:16];
      32'h10000: leds_r = wb1_dat_o[15:0];
      32'h20000: leds_r = wb1_dat_o[31:16];
      32'h40000: leds_r = wb1_dat_i[15:0];
      32'h80000: leds_r = wb1_dat_i[31:16];
      // 32'h100000: leds_r = wb1_sel_o;
      // 32'h200000: leds_r = wb1_we_o;
      32'h400000: leds_r = {11'b0,bubble_IF,bubble_ID,bubble_EXE,bubble_MEM,bubble_WB};
      32'h800000: leds_r = {11'b0,flush_IF,flush_ID,flush_EXE,flush_MEM,flush_WB};
      32'h1000000: leds_r = {3'b0,bubble_IF,bubble_ID,bubble_EXE,bubble_MEM,bubble_WB,wb1_cyc_o,wb1_stb_o,wb1_ack_i,wb1_we_o,wb1_sel_o};
      // 32'h2000000: leds_r = bubble_MEM;
      // 32'h4000000: leds_r = bubble_WB;
      // 32'h8000000: leds_r = flush_ID;
      // 32'h10000000: leds_r = flush_IF;
      // 32'h20000000: leds_r = flush_EXE;
      // 32'h40000000: leds_r = flush_MEM;
      // 32'h80000000: leds_r = flush_WB;
    endcase
  end
  ila_1 u_ila(
    .clk(clk_i),
    .probe0(clk_i),
    .probe1(rst_i),
    .probe2(wb0_cyc_o),
    .probe3(wb0_stb_o),
    .probe4(wb0_ack_i),
    .probe5(wb0_adr_o),
    .probe6(wb0_dat_o),
    .probe7(wb0_dat_i),
    .probe8(wb0_sel_o),
    .probe9(wb0_we_o),
    .probe10(wb1_cyc_o),
    .probe11(wb1_stb_o),
    .probe12(wb1_ack_i),
    .probe13(wb1_adr_o),
    .probe14(wb1_dat_o),
    .probe15(wb1_dat_i),
    .probe16(wb1_sel_o),
    .probe17(wb1_we_o),
    .probe18(dip_sw),
    .probe19(leds),
    .probe20(pc_reg),
    .probe21(ifid_inst_reg),
    .probe22(ifid_pc_now_reg),
    .probe23(ifid_instr_type_reg),
    .probe24(idex_inst_reg),
    .probe25(idex_rf_rdata_a_reg),
    .probe26(idex_rf_rdata_b_reg),
    .probe27(idex_rf_waddr_reg),
    .probe28(idex_imm_gen_reg),
    .probe29(idex_pc_now_reg),
    .probe30(idex_alu_op_reg),
    .probe31(idex_use_rs2),
    .probe32(idex_mem_en),
    .probe33(idex_instr_type_reg),
    .probe34(idex_rf_wen),
    .probe35(exme_inst_reg),
    .probe36(exme_rf_rdata_a_reg),
    .probe37(exme_rf_rdata_b_reg),
    .probe38(exme_rf_waddr_reg),
    .probe39(exme_alu_result_reg),
    .probe40(exme_rpc_wen),
    .probe41(exme_mem_en),
    .probe42(exme_use_rs2),
    .probe43(exme_pc_now_reg),
    .probe44(exme_instr_type_reg),
    .probe45(exme_rf_wen),
    .probe46(mewb_rf_waddr_reg),
    .probe47(mewb_rf_wdata_reg),
    .probe48(mewb_rpc_wdata_reg),
    .probe49(mewb_rpc_wen),
    .probe50(mewb_instr_type_reg),
    .probe51(flush_IF),
    .probe52(flush_ID),
    .probe53(flush_EXE),
    .probe54(flush_MEM),
    .probe55(flush_WB),
    .probe56(bubble_IF),
    .probe57(bubble_ID),
    .probe58(bubble_EXE),
    .probe59(bubble_MEM),
    .probe60(bubble_WB)
  );
  //=========== DEBUG MODULE END ===========

  //=========== ALU MODULE BEGIN ===========
  reg [31:0] alu_operand1_o;
  reg [31:0] alu_operand2_o;
  op_type_t alu_op_o;
  reg [31:0] alu_result_i;
  reg [31:0] rs1_data;
  reg [31:0] rs2_data;
  Alu32 pipeline_alu(
    .op(alu_op_o),
    .a(alu_operand1_o),
    .b(alu_operand2_o),
    .result(alu_result_i)
  );
  always_comb begin
    alu_operand1_o = 0;
    alu_operand2_o = 0;
    alu_op_o = ALU_DEFAULT;
    case(idex_instr_type_reg)
      U_TYPE: begin
        if(idex_inst_reg[6:0] == AUIPC)begin //AUIPC
          alu_operand1_o = idex_pc_now_reg;
          alu_operand2_o = idex_imm_gen_reg;
          alu_op_o = idex_alu_op_reg;
        end 
        // LUI don't need to do anything
      end
      R_TYPE: begin
        alu_operand1_o = idex_rf_rdata_a_reg;
        if(idex_inst_reg[6:0]== JALR)begin
          alu_operand2_o = idex_imm_gen_reg;
        end else begin
          alu_operand2_o = idex_rf_rdata_b_reg;
        end
        alu_op_o = idex_alu_op_reg;
      end
      I_TYPE: begin
        alu_operand1_o = idex_rf_rdata_a_reg;
        alu_operand2_o = idex_imm_gen_reg;
        alu_op_o = idex_alu_op_reg;
      end
      S_TYPE: begin
        alu_operand1_o = idex_rf_rdata_a_reg;
        alu_operand2_o = idex_imm_gen_reg;
        alu_op_o = idex_alu_op_reg;
      end
      B_TYPE: begin
        alu_operand1_o = idex_pc_now_reg;
        alu_operand2_o = idex_imm_gen_reg;
        alu_op_o = idex_alu_op_reg;
      end
      J_TYPE: begin //JAL
        alu_operand1_o = idex_pc_now_reg;
        alu_operand2_o = idex_imm_gen_reg;
        alu_op_o = idex_alu_op_reg;
      end
    endcase
  end
  //=========== ALU MODULE END ===========
  always_ff @ (posedge clk_i) begin
    if (rst_i) begin
      wb1_stb_o <= 1'b0;
      wb1_cyc_o <= 1'b0;
      wb1_we_o <= 1'b0;
      wb1_sel_o <= 4'b0000;
      wb0_dat_o <= 32'b0;
      wb1_dat_o <= 32'b0;
      wb1_adr_o <= 32'b0;
      // reset every reg stage to addi x0, x0, 0

      // -IF
      pc_reg <= 32'h8000_0000;
      wb0_stb_o <= 1'b0;
      wb0_cyc_o <= 1'b0;
      wb0_we_o <= 1'b0;
      wb0_sel_o <= 4'b0000;

      // IF-ID
      ifid_inst_reg <= 32'b0010011;
      ifid_pc_now_reg <= 32'h8000_0000;
      ifid_instr_type_reg <= I_TYPE;

      // ID-EXE
      idex_inst_reg <= 32'b0010011;
      idex_rf_rdata_a_reg <= 32'b0;
      idex_rf_rdata_b_reg <= 32'b0;
      idex_rf_waddr_reg <= 5'b0;
      idex_imm_gen_reg <= 32'b0;
      idex_pc_now_reg <= 32'h8000_0000; // No matter what the pc is,  this is an addi instruction, so pc_now is not important!
      idex_alu_op_reg <= ALU_ADD;
      idex_use_rs2 <= 1'b0;
      idex_mem_en <= 0;
      idex_instr_type_reg <= I_TYPE;
      idex_rf_wen <= 1; // Never mind whether to allow to read x0, because it will return zero at anytime, thus it doesn't have conflict problem!
      
      // EXE-MEM
      exme_inst_reg <= 32'b0010011;
      exme_rf_rdata_a_reg <= 32'b0;
      exme_rf_rdata_b_reg <= 32'b0;
      exme_rf_waddr_reg <= 5'b0;
      exme_alu_result_reg <= 32'b0; // x0+0 = 0
      exme_use_rs2 <= 1'b0;
      exme_mem_en <= 0;
      exme_instr_type_reg <= I_TYPE;
      exme_rf_wen <= 1; // Same to above
      exme_rpc_wen <= 0;
      exme_pc_now_reg <= 32'h8000_0000;
      exme_state <= 0;
      exme_bias <= 0;
      exme_inst_reg_copy <= 32'b0010011;
      exme_rf_waddr_reg_copy <= 5'b0;

      // MEM-WB
      mewb_rf_wen <= 1;
      mewb_rf_waddr_reg <= 5'b0;
      mewb_rf_wdata_reg <= 32'b0;
      mewb_rpc_wdata_reg <= 32'b0;
      mewb_instr_type_reg <= I_TYPE;
      mewb_rpc_wen <= 0;

    // reset signal to none
    end else begin
      // IF
      if(flush_IF)begin
        if(flush_ID)begin
          // IF-ID reset to addi x0, x0, 0
          ifid_inst_reg <= 32'b0010011;
          ifid_pc_now_reg <= 32'h8000_0000;
          ifid_instr_type_reg <= I_TYPE;
          wb0_stb_o <= 1'b0;
          wb0_cyc_o <= 1'b0;
          wb0_we_o <= 1'b0;
          wb0_sel_o <= 4'b0000;
        end
      end else if (bubble_IF) begin
        wb0_adr_o <= pc_reg;
        // if(!bubble_ID)begin
          // IF-ID reset to addi x0, x0, 0
        ifid_inst_reg <= 32'b0010011;
        ifid_pc_now_reg <= 32'h8000_0000;
        ifid_instr_type_reg <= I_TYPE;
        wb0_dat_o <= {bubble_ID,31'b1};
        if(bubble_ID)begin
          wb0_stb_o <= 1'b0;
          wb0_cyc_o <= 1'b0;
          wb0_we_o <= 1'b0;
          wb0_sel_o <= 4'b0000;
        end
        // end
      end else begin
        wb0_dat_o <= 32'b10;
        wb0_adr_o <= pc_reg;
        if (wb0_ack_i) begin
          pc_reg <= pc_reg+4; 
          wb0_stb_o <= 1'b0;
          wb0_cyc_o <= 1'b0;
          wb0_we_o <= 1'b0;
          wb0_sel_o <= 4'b0000;
          ifid_inst_reg <= wb0_dat_i;
          ifid_pc_now_reg <= pc_reg;
          ifid_instr_type_reg <= imm_gen_type_o;
        end else begin
          ifid_inst_reg <= 32'b0010011;
          wb0_stb_o <= 1'b1;
          wb0_cyc_o <= 1'b1;
          wb0_we_o <= 1'b0;
          wb0_sel_o <= 4'b1111;
        end
      end
      // ID
      if(flush_ID)begin
        if(flush_EXE)begin
          // ID-EXE
          idex_inst_reg <= 32'b0010011;
          idex_rf_rdata_a_reg <= 32'b0;
          idex_rf_rdata_b_reg <= 32'b0;
          idex_rf_waddr_reg <= 5'b0;
          idex_imm_gen_reg <= 32'b0;
          idex_pc_now_reg <= 32'h8000_0000; // No matter what the pc is,  this is an addi instruction, so pc_now is not important!
          idex_alu_op_reg <= ALU_ADD;
          idex_use_rs2 <= 1'b0;
          idex_mem_en <= 0;
          idex_instr_type_reg <= I_TYPE;
          idex_rf_wen <= 1; // Never mind whether to allow to read x0, because it will return zero at anytime, thus it doesn't have conflict problem!
        end
      end else if(bubble_ID) begin
        if(!bubble_EXE) begin
          // ID-EXE
          idex_inst_reg <= 32'b0010011;
          idex_rf_rdata_a_reg <= 32'b0;
          idex_rf_rdata_b_reg <= 32'b0;
          idex_rf_waddr_reg <= 5'b0;
          idex_imm_gen_reg <= 32'b0;
          idex_pc_now_reg <= 32'h8000_0000; // No matter what the pc is,  this is an addi instruction, so pc_now is not important!
          idex_alu_op_reg <= ALU_ADD;
          idex_use_rs2 <= 1'b0;
          idex_mem_en <= 0;
          idex_instr_type_reg <= I_TYPE;
          idex_rf_wen <= 1; // Never mind whether to allow to read x0, because it will return zero at anytime, thus it doesn't have conflict problem!
        end end 
      else begin
        idex_inst_reg <= ifid_inst_reg;
        idex_rf_rdata_a_reg <= rf_rdata_a_o;
        idex_rf_rdata_b_reg <= rf_rdata_b_o;
        idex_rf_waddr_reg <= rd;
        idex_imm_gen_reg <= imm_gen_inst_o;
        idex_pc_now_reg <= ifid_pc_now_reg;
        idex_use_rs2 <= use_rs2;
        idex_instr_type_reg <= imm_gen_type_o;
        case(ifid_inst_reg[6:0])
          LUI:begin // do nothing
            idex_alu_op_reg <= ALU_ADD;
            idex_mem_en <= 0;
            idex_rf_wen <= 1;
          end
          BEQ_BNE:begin // PC+imm
            idex_alu_op_reg <= ALU_ADD;
            idex_mem_en <= 0;
            idex_rf_wen <= 0;
          end
          LB_LW:begin // PC+imm
            idex_alu_op_reg <= ALU_ADD;
            idex_mem_en <= 1;
            idex_rf_wen <= 1;
          end
          SB_SW:begin // rs1+imm
            
            idex_alu_op_reg <= ALU_ADD;
            idex_mem_en <= 1;
            idex_rf_wen <= 0;
          end
          ADDI_ANDI_ORI_SLLI_SRLI:begin // rs1+imm
            idex_rf_wen <= 1;
            idex_mem_en <= 0;
            case(ifid_inst_reg[14:12])
              3'b000:idex_alu_op_reg <= ALU_ADD;
              3'b111:idex_alu_op_reg <= ALU_AND;
              3'b110:idex_alu_op_reg <= ALU_OR;
              3'b001:idex_alu_op_reg <= ALU_SLL;
              3'b101:idex_alu_op_reg <= ALU_SRL;
            endcase
          end
          ADD_OR_AND_XOR:begin // rs1+rs2
            idex_rf_wen <= 1;
            case(ifid_inst_reg[14:12])
              3'b000:idex_alu_op_reg <= ALU_ADD;
              3'b111:idex_alu_op_reg <= ALU_AND;
              3'b110:idex_alu_op_reg <= ALU_OR;
              3'b100:idex_alu_op_reg <= ALU_XOR;
            endcase
            idex_mem_en <= 0;
          end
          JAL:begin
            idex_rf_wen <= 1;
            idex_alu_op_reg <= ALU_ADD;
            idex_mem_en <= 0;
          end
          JALR:begin
            idex_rf_wen <= 1;
            idex_alu_op_reg <= ALU_ADD;
            idex_mem_en <= 0;
          end
          AUIPC:begin
            idex_rf_wen <= 1;
            idex_alu_op_reg <= ALU_ADD;
            idex_mem_en <= 0;
          end
          default:begin
            idex_rf_wen <= 0;
            idex_alu_op_reg <= ALU_DEFAULT;
            idex_mem_en <= 0;
          end
        endcase
      end
      // EXE
      if(flush_EXE)begin
        if(flush_MEM)begin
          // EXE-MEM
          exme_inst_reg <= 32'b0010011;
          exme_rf_rdata_a_reg <= 32'b0;
          exme_rf_rdata_b_reg <= 32'b0;
          exme_rf_waddr_reg <= 5'b0;
          exme_alu_result_reg <= 32'b0; // x0+0 = 0
          exme_use_rs2 <= 1'b0;
          exme_mem_en <= 0;
          exme_instr_type_reg <= I_TYPE;
          exme_rf_wen <= 1; // Same to above
          exme_rpc_wen <= 0;
          exme_pc_now_reg <= 32'b0;
          
        end
      end else if(bubble_EXE)begin
        if(!bubble_MEM)begin
          // EXE-MEM
          exme_inst_reg <= 32'b0010011;
          exme_rf_rdata_a_reg <= 32'b0;
          exme_rf_rdata_b_reg <= 32'b0;
          exme_rf_waddr_reg <= 5'b0;
          exme_alu_result_reg <= 32'b0; // x0+0 = 0
          exme_use_rs2 <= 1'b0;
          exme_mem_en <= 0;
          exme_instr_type_reg <= I_TYPE;
          exme_rf_wen <= 1; // Same to above
          exme_rpc_wen <= 0;
          exme_pc_now_reg <= 32'b0;
        end
      end else begin
        exme_inst_reg <= idex_inst_reg;
        exme_rf_rdata_a_reg <= idex_rf_rdata_a_reg;
        exme_rf_rdata_b_reg <= idex_rf_rdata_b_reg;
        exme_rf_waddr_reg <= idex_rf_waddr_reg;
        // if(idex_inst_reg!=32'b0010011)begin
        exme_mem_en <= idex_mem_en;
        // end
        exme_use_rs2 <= idex_use_rs2;
        exme_instr_type_reg <= idex_instr_type_reg;
        exme_pc_now_reg <= idex_pc_now_reg;
        case(idex_instr_type_reg)
          U_TYPE: begin
          // don't need to do anything
            if(idex_inst_reg[6:0] == AUIPC)begin
              exme_alu_result_reg <= alu_result_i;
            end else begin
              exme_alu_result_reg <= idex_imm_gen_reg;
            end
            exme_rf_wen <= idex_rf_wen;
          end
          R_TYPE: begin
            exme_alu_result_reg <= alu_result_i;
            exme_rf_wen <= idex_rf_wen;
            if(idex_inst_reg[6:0] == JALR)begin
              exme_rpc_wen <= 1;
            end
            else begin
              exme_rpc_wen <= 0;
            end
          end
          I_TYPE: begin
            exme_alu_result_reg <= alu_result_i;
            exme_rf_wen <= idex_rf_wen;
          end
          S_TYPE: begin
            exme_alu_result_reg <= alu_result_i;
            exme_rf_wen <= idex_rf_wen;
          end
          B_TYPE: begin
            exme_alu_result_reg <= alu_result_i;
            exme_rf_wen <= idex_rf_wen;
            if((idex_inst_reg[12] && idex_rf_rdata_a_reg != idex_rf_rdata_b_reg ) || (!idex_inst_reg[12] && idex_rf_rdata_a_reg == idex_rf_rdata_b_reg ))begin
              exme_rpc_wen <= 1;
            end
            else begin
              exme_rpc_wen <= 0;
            end
          end
          J_TYPE: begin
            exme_alu_result_reg <= alu_result_i;
            exme_rf_wen <= idex_rf_wen;
            exme_rpc_wen <= 1;
          end
          default:begin
            exme_alu_result_reg <= alu_result_i;
            exme_rf_wen <= idex_rf_wen;
          end
        endcase
      end
      // MEM
      if(flush_MEM)begin
        // if(flush_WB)begin
        // MEM-WB
        mewb_rf_wen <= 1;
        mewb_rf_waddr_reg <= 5'b0;
        mewb_rf_wdata_reg <= 32'b0;
        mewb_rpc_wdata_reg <= 32'b0;

        mewb_instr_type_reg <= I_TYPE;
        mewb_rpc_wen <= 0;

        // end
      end else if(bubble_MEM)begin
        if(!bubble_WB)begin
          // MEM-WB
          mewb_rf_wen <= 1;
          mewb_rf_waddr_reg <= 5'b0;
          mewb_rf_wdata_reg <= 32'b0;
          mewb_rpc_wdata_reg <= 32'b0;
          mewb_instr_type_reg <= I_TYPE;
          mewb_rpc_wen <= 0;

        end
      end else begin
        mewb_rf_wen <= exme_rf_wen;
        mewb_instr_type_reg <= exme_instr_type_reg;
        
        if(exme_mem_en || exme_state)begin // need to visit the memory include LB,LW,SB,SW
          if(wb1_ack_i)begin
            wb1_cyc_o <= 1'b0;
            wb1_stb_o <= 1'b0;
            wb1_sel_o <= 4'b0000;
            wb1_we_o <= 1'b0;
            exme_state <= 1'b0;
            exme_inst_reg_copy <= exme_inst_reg;
            exme_bias <= 2'b0;
            case(exme_inst_reg_copy[6:0])
              LB_LW: begin
                if(exme_inst_reg_copy[14:12] == 3'b000)begin //LB
                  if(exme_bias[1:0]==2'b0) begin
                    mewb_rf_wdata_reg <= {24'b0, wb1_dat_i[7:0]};
                  end else if(exme_bias[1:0]==2'b01) begin
                    mewb_rf_wdata_reg <= {24'b0, wb1_dat_i[15:8]};
                  end else if(exme_bias[1:0]==2'b10) begin
                    mewb_rf_wdata_reg <= {24'b0, wb1_dat_i[23:16]};
                  end else begin
                    mewb_rf_wdata_reg <= {24'b0, wb1_dat_i[31:24]};
                  end
                end else begin //LW
                  mewb_rf_wdata_reg <= wb1_dat_i;
                end
                // mewb_rf_wdata_reg <= {24'b0,(wb1_dat_i>>exme_alu_result_reg[1:0])[7:0]};
                mewb_rf_waddr_reg <= exme_rf_waddr_reg_copy;
              end
            endcase
          end else begin
            wb1_cyc_o <= 1'b1;
            wb1_stb_o <= 1'b1;
            wb1_adr_o <= exme_alu_result_reg;
            exme_state <= 1'b1;
            exme_bias <= exme_alu_result_reg[1:0];
            exme_inst_reg_copy <= exme_inst_reg;
            exme_rf_waddr_reg_copy <= exme_rf_waddr_reg;
            case(exme_inst_reg[6:0])
              LB_LW: begin
                wb1_we_o <= 1'b0;
                if(exme_inst_reg[14:12] == 3'b000)begin //LB
                  wb1_sel_o <= (4'b0001 << exme_alu_result_reg[1:0]);
                  // wb1_sel_o <= 4'b0001;
                end else if(exme_inst_reg[14:12] == 3'b010) begin //LW
                  wb1_sel_o <= 4'b1111;
                end else begin
                  wb1_sel_o <= 4'b0000;
                end
              end
              SB_SW: begin
                if(exme_inst_reg[14:12] == 3'b000)begin //SB
                  wb1_dat_o <= exme_rf_rdata_b_reg;
                  wb1_sel_o <= (4'b0001 << exme_alu_result_reg[1:0]);
                  // wb1_sel_o <= 4'b0001;
                  wb1_we_o <= 1'b1;
                end else if(exme_inst_reg[14:12] == 3'b010)begin //SW
                  wb1_dat_o <= exme_rf_rdata_b_reg;
                  wb1_sel_o <= 4'b1111;
                  wb1_we_o <= 1'b1;
                end else begin
                  wb1_dat_o <= 0;
                  wb1_sel_o <= 4'b0000;
                  wb1_we_o <= 1'b0;
                end
              end
            endcase
          end
        end else begin
          mewb_rf_waddr_reg <= exme_rf_waddr_reg;
          if(exme_rpc_wen)begin
            mewb_rpc_wdata_reg <=  exme_alu_result_reg;
            mewb_rf_wdata_reg <= exme_pc_now_reg + 4;
          end else begin
            mewb_rf_wdata_reg <= exme_alu_result_reg;
          end
          mewb_rpc_wen <= exme_rpc_wen;
        end
      end
      // WB
      if(mewb_rpc_wen)begin
        pc_reg <= mewb_rpc_wdata_reg;
      end

      // end
      end
  end
endmodule