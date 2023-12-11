`include "./headers/exception.svh"
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
    input wire wb0_exc_i,
    output wire [ADDR_WIDTH-1:0] wb0_adr_o,
    output reg [DATA_WIDTH-1:0] wb0_dat_o,
    input wire [DATA_WIDTH-1:0] wb0_dat_i,
    output reg [DATA_WIDTH/8-1:0] wb0_sel_o,
    output reg wb0_we_o,
    // wishbone master1
    output reg wb1_cyc_o,
    output reg wb1_stb_o,
    input wire wb1_ack_i,
    input wire wb1_exc_i,
    output reg [ADDR_WIDTH-1:0] wb1_adr_o,
    output reg [DATA_WIDTH-1:0] wb1_dat_o,
    input wire [DATA_WIDTH-1:0] wb1_dat_i,
    output reg [DATA_WIDTH/8-1:0] wb1_sel_o,
    output reg wb1_we_o,
    input wire mtime_exceed_i,
    input wire[DATA_WIDTH-1:0] mtime_lo_i,
    input wire[DATA_WIDTH-1:0] mtime_hi_i,
    input wire [31:0] dip_sw,
    output wire [15:0] leds,
    // mmu<-cpu<-csr
    output wire [31:0] satp_o,
    output wire[1:0]  priviledge_mode_o,

    // output reg exme_query_wen,

    // input for page fault exception
    input wire [30:0] if_exception_code_i,
    input wire [ADDR_WIDTH-1:0] if_exception_addr_i,  // VA
    input wire [30:0] mem_exception_code_i,
    input wire [ADDR_WIDTH-1:0] mem_exception_addr_i, // VA
    input wire [DATA_WIDTH-1:0] id_exception_instr_i,
    input wire id_exception_instr_wen,
    // cpu->mmu
    output wire flush_tlb_o
);
/*============= ila debug module begin ==================*/
  wire[31:0] msstatus;
  wire[31:0] msie;
  wire[31:0] mideleg;
  wire[31:0] msip;
  wire[31:0] mtvec;
  wire[31:0] stvec;
  wire[31:0] mepc;
  wire[31:0] sepc;
  wire[31:0] mcause;
  wire[31:0] scause;
  // ila_2 u_ila(
  //   .clk(clk_i),
  //   .probe0(wb0_cyc_o),
  //   .probe1(wb0_stb_o),
  //   .probe2(wb0_ack_i),
  //   .probe3(wb0_exc_i),
  //   .probe4(wb0_adr_o),
  //   .probe5(wb0_dat_o),
  //   .probe6(wb0_dat_i),
  //   .probe7(wb0_sel_o),
  //   .probe8(wb0_we_o),
  //   .probe9(wb1_cyc_o),
  //   .probe10(wb1_stb_o),
  //   .probe11(wb1_ack_i),
  //   .probe12(wb1_exc_i),
  //   .probe13(wb1_adr_o),
  //   .probe14(wb1_dat_o),
  //   .probe15(wb1_dat_i),
  //   .probe16(wb1_sel_o),
  //   .probe17(wb1_we_o),
  //   .probe18(mtime_exceed_i),
  //   .probe19(satp_o),
  //   .probe20(priviledge_mode_o),
  //   .probe21(if_exception_code_i),
  //   .probe22(if_exception_addr_i),
  //   .probe23(mem_exception_code_i),
  //   .probe24(mem_exception_addr_i),
  //   .probe25(id_exception_instr_i),
  //   .probe26(id_exception_instr_wen),
  //   .probe27(flush_tlb_o),
  //   .probe28(msstatus),
  //   .probe29(msie),
  //   .probe30(mideleg),
  //   .probe31(msip),
  //   .probe32(mtvec),
  //   .probe33(stvec),
  //   .probe34(mepc),
  //   .probe35(sepc),
  //   .probe36(mcause),
  //   .probe37(scause)
  // );
/*============= ila debug module end ==================*/
  reg[31:0] wb0_adr_o_reg;
  assign wb0_adr_o = wb0_adr_o_reg;
  typedef enum logic [2:0] { 
    R_TYPE = 3'b001, 
    I_TYPE = 3'b010, 
    S_TYPE = 3'b011, 
    B_TYPE = 3'b100, 
    U_TYPE = 3'b101, 
    J_TYPE = 3'b110,
    SYS_TYPE = 3'b111
  } instrction_type_t;

  // NOTE
  typedef enum logic [6:0] {
    LUI = 7'b0110111,
    BEQ_BNE_BLT_BGE_BLTU_BGTU = 7'b1100011,
    LB_LW_LH_LBU_LHU = 7'b0000011,
    SB_SW_SH = 7'b0100011, 
    ADDI_ANDI_ORI_SLLI_SRLI_CLZ_CTZ_SLTI_SLTIU_XORI_SRAI = 7'b0010011, 
    ADD_SUB_OR_AND_XOR_MINU_SLTU_SLL_SLT_SRA = 7'b0110011, 
    JAL = 7'b1101111,
    JALR = 7'b1100111,
    AUIPC = 7'b0010111,
    CSR_EBREAK_ECALL_MRET_SRET_SFENCEVMA = 7'b1110011 // CSR(C,S,W),EBREAK, ECALL, MRET, SRET, SFENCE.VMA
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
    ALU_ROL = 4'b1010,
    ALU_CLZ = 4'b1011,
    ALU_CTZ = 4'b1100,
    ALU_MINU = 4'b1101,
    ALU_LTU = 4'b1110,
    ALU_LT = 4'b1111
  } op_type_t;
  // before IF reg
  /*=========== PC Controller Module Begin ===========*/
  reg [31:0] pc_reg;
  reg [31:0] pc_seq_nxt;
  reg [31:0] pc_branch_nxt;
  reg [31:0] pc_csr_nxt;
  reg [31:0] pc_nxt_reg;
  reg [31:0] pc_predict; // for BTB 
  reg pc_csr_nxt_en;
  reg pc_branch_nxt_en;
  logic pc_if_state; //0:IDLE 1:Fetching Instruction
  logic branching;
  PcController u_pc_controller(
    .pc_i(pc_reg),
    .pc_seq_nxt_i(pc_seq_nxt),
    .pc_branch_nxt_i(pc_branch_nxt),
    .pc_branch_nxt_en(pc_branch_nxt_en),
    .pc_csr_nxt_i(pc_csr_nxt),
    .pc_csr_nxt_en(pc_csr_nxt_en),
    .pc_nxt_o(pc_nxt_reg),
    .branching_o(branching),
    // add px_predict
    .pc_predict_nxt_i(pc_predict)
  );
  
  pc_btb_table u_pc_btb_table(
    .clk(clk_i),
    .rst(rst_i),
    // for read 
    .pc_now(pc_reg),          // CHECK: whether to use ifid_pc_now_reg ? 
    .pc_predict(pc_predict),
    // for write
    .branching(branching),    // Computed by PCController. CHECK: whether to use pc_branch_nxt_en (w.o. CSR) ?
    .exe_pc(idex_pc_now_reg), // alu use idex_pc_now_reg, exme_pc_now_reg <= idex_pc_now_reg
    .exe_pc_next(pc_nxt_reg) // Computed by PCController.
  );
  /*=========== PC Controller Module End ===========*/

  // IF-ID reg
  reg [31:0] ifid_inst_reg;
  reg [31:0] ifid_pc_now_reg;
  reg [30:0] ifid_if_exception_code_reg;
  instrction_type_t ifid_instr_type_reg;

  // ID-EXE reg
  reg [31:0] idex_inst_reg;
  reg [31:0] idex_rf_rdata_a_reg;
  reg [31:0] idex_rf_rdata_b_reg;
  reg [4:0] idex_rf_waddr_reg;
  reg [31:0] idex_imm_gen_reg;
  reg [31:0] idex_pc_now_reg;
  reg [30:0] idex_if_exception_code_reg;
  reg [31:0] idex_exception_instr_reg;
  reg idex_exception_instr_wen_reg;
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
  reg [30:0] exme_if_exception_code_reg;
  reg [31:0] exme_exception_instr_reg;
  reg exme_exception_instr_wen_reg;
  // reg exme_rpc_wen;
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
  // reg [31:0] mewb_rpc_wdata_reg;
  // reg mewb_rpc_wen;
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
  // NOTE
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
      BEQ_BNE_BLT_BGE_BLTU_BGTU:begin
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
      LB_LW_LH_LBU_LHU:begin // imm 做有符号扩展
        use_rs2 = 0;
        imm_gen_type_o = I_TYPE;
        imm_gen_inst_o[11:0] = ifid_inst_reg[31:20];
        if(ifid_inst_reg[31])begin
            imm_gen_inst_o[31:12]=20'hFFFFF;
        end else begin
            imm_gen_inst_o[31:12]=20'h00000;
        end
      end
      SB_SW_SH:begin
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
      ADDI_ANDI_ORI_SLLI_SRLI_CLZ_CTZ_SLTI_SLTIU_XORI_SRAI:begin
        use_rs2 = 0;
        imm_gen_type_o = I_TYPE;
        imm_gen_inst_o[11:0] = ifid_inst_reg[31:20];
        if(ifid_inst_reg[31])begin
            imm_gen_inst_o[31:12]=20'hFFFFF;
        end else begin
            imm_gen_inst_o[31:12]=20'h00000;
        end
      end
      ADD_SUB_OR_AND_XOR_MINU_SLTU_SLL_SLT_SRA:begin
        use_rs2 = 1;
        imm_gen_type_o = R_TYPE;
        imm_gen_inst_o = 0;
      end
      JAL:begin
        use_rs2 = 0;
        imm_gen_type_o = J_TYPE;
        imm_gen_inst_o[20:0] = {ifid_inst_reg[31],ifid_inst_reg[19:12],ifid_inst_reg[20],ifid_inst_reg[30:21],1'b0};
        if(ifid_inst_reg[31])begin
          imm_gen_inst_o[31:20]=12'hFFF; // zrp is a sb qaq
        end else begin
          imm_gen_inst_o[31:21]=12'h000; // zrp is a sb qaq
        end
      end
      JALR:begin
        use_rs2 = 0;
        imm_gen_type_o = R_TYPE;
        imm_gen_inst_o[11:0] = ifid_inst_reg[31:20]; // zrp is a shabi qaq
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
      CSR_EBREAK_ECALL_MRET_SRET_SFENCEVMA:begin
        use_rs2 = 0;
        imm_gen_type_o = SYS_TYPE;
        imm_gen_inst_o = 32'b0;
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
  wire flush_csr_IF;
  wire flush_csr_ID;
  wire flush_csr_EXE;
  wire flush_csr_MEM;
  wire flush_csr_WB;
  wire flush_branch_IF;
  wire flush_branch_ID;
  wire flush_branch_EXE;
  wire flush_branch_MEM;
  wire flush_branch_WB;
  wire flush_IF;
  wire flush_ID;
  wire flush_EXE;
  wire flush_MEM;
  wire flush_WB;
  assign flush_IF = flush_csr_IF || flush_branch_IF;
  assign flush_ID = flush_csr_ID || flush_branch_ID;
  assign flush_EXE = flush_csr_EXE || flush_branch_EXE;
  assign flush_MEM = flush_csr_MEM || flush_branch_MEM;
  assign flush_WB = flush_csr_WB || flush_branch_WB;
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
    .pc_branch_nxt_en(pc_branch_nxt_en),
    .pc_csr_nxt_en(pc_csr_nxt_en),
    .use_rs2_i(use_rs2),
    .bubble_IF_o(bubble_IF),
    .bubble_ID_o(bubble_ID),
    .bubble_EXE_o(bubble_EXE),
    .bubble_MEM_o(bubble_MEM),
    .bubble_WB_o(bubble_WB),
    .flush_IF_csr_o(flush_csr_IF),
    .flush_ID_csr_o(flush_csr_ID),
    .flush_EXE_csr_o(flush_csr_EXE),
    .flush_MEM_csr_o(flush_csr_MEM),
    .flush_WB_csr_o(flush_csr_WB),
    .flush_IF_branch_o(flush_branch_IF),
    .flush_ID_branch_o(flush_branch_ID),
    .flush_EXE_branch_o(flush_branch_EXE),
    .flush_MEM_branch_o(flush_branch_MEM),
    .flush_WB_branch_o(flush_branch_WB)
  );
  // end
  
  // end
  //=========== Risk and Conflict Solver END===========

  //=========== DEBUG MODULE BEGIN ===========
  // logic[15:0] leds_r;
  // assign leds = leds_r;
  // always_comb begin 
  //   leds_r = 16'h0000;
    // case(dip_sw)
      // 32'h1: leds_r = {wb0_cyc_o,wb0_stb_o,wb0_ack_i,wb0_we_o,wb0_sel_o,wb1_cyc_o,wb1_stb_o,wb1_ack_i,wb1_we_o,wb1_sel_o};
      // 32'h2: leds_r = wb0_stb_o;
      // 32'h4: leds_r = wb0_ack_i;
      // 32'h8: leds_r = wb0_adr_o_reg[15:0];
      // 32'h10: leds_r = wb0_adr_o_reg[31:16];
      // 32'h20: leds_r = wb0_dat_o[15:0];
      // 32'h40: leds_r = wb0_dat_o[31:16];
      // 32'h80: leds_r = wb0_dat_i[15:0];
      // 32'h100: leds_r = wb0_dat_i[31:16];
      // 32'h200: leds_r = {15'b0,mtime_exceed_i};
      // 32'h200: leds_r = wb0_sel_o;
      // 32'h400: leds_r = wb0_we_o;
      // 32'h800: leds_r = {8'b0,wb1_cyc_o,wb1_stb_o,wb1_ack_i,wb1_we_o,wb1_sel_o};
      // 32'h1000: leds_r = wb1_stb_o;
      // 32'h2000: leds_r = wb1_ack_i;
      // 32'h4000: leds_r = wb1_adr_o[15:0];
      // 32'h8000: leds_r = wb1_adr_o[31:16];
      // 32'h10000: leds_r = wb1_dat_o[15:0];
      // 32'h20000: leds_r = wb1_dat_o[31:16];
      // 32'h40000: leds_r = wb1_dat_i[15:0];
      // 32'h80000: leds_r = wb1_dat_i[31:16];
      // 32'h100000: leds_r = wb1_sel_o;
      // 32'h200000: leds_r = wb1_we_o;
      // 32'h400000: leds_r = {11'b0,bubble_IF,bubble_ID,bubble_EXE,bubble_MEM,bubble_WB};
      // 32'h800000: leds_r = {11'b0,flush_IF,flush_ID,flush_EXE,flush_MEM,flush_WB};
      // 32'h1000000: leds_r = {3'b0,bubble_IF,bubble_ID,bubble_EXE,bubble_MEM,bubble_WB,wb1_cyc_o,wb1_stb_o,wb1_ack_i,wb1_we_o,wb1_sel_o};
      // 32'h2000000: leds_r = bubble_MEM;
      // 32'h4000000: leds_r = bubble_WB;
      // 32'h8000000: leds_r = flush_ID;
      // 32'h10000000: leds_r = flush_IF;
      // 32'h20000000: leds_r = flush_EXE;
      // 32'h40000000: leds_r = flush_MEM;
      // 32'h80000000: leds_r = flush_WB;
  //   endcase
  // end
  // ila_1 u_ila(
  //   .clk(clk_i),
  //   .probe0(clk_i),
  //   .probe1(rst_i),
  //   .probe2(wb0_cyc_o),
  //   .probe3(wb0_stb_o),
  //   .probe4(wb0_ack_i),
  //   .probe5(wb0_adr_o_reg),
  //   .probe6(wb0_dat_o),
  //   .probe7(wb0_dat_i),
  //   .probe8(wb0_sel_o),
  //   .probe9(wb0_we_o),
  //   .probe10(wb1_cyc_o),
  //   .probe11(wb1_stb_o),
  //   .probe12(wb1_ack_i),
  //   .probe13(wb1_adr_o),
  //   .probe14(wb1_dat_o),
  //   .probe15(wb1_dat_i),
  //   .probe16(wb1_sel_o),
  //   .probe17(wb1_we_o),
  //   .probe18(dip_sw),
  //   .probe19(leds),
  //   .probe20(pc_reg),
  //   .probe21(ifid_inst_reg),
  //   .probe22(ifid_pc_now_reg),
  //   .probe23(ifid_instr_type_reg),
  //   .probe24(idex_inst_reg),
  //   .probe25(idex_rf_rdata_a_reg),
  //   .probe26(idex_rf_rdata_b_reg),
  //   .probe27(idex_rf_waddr_reg),
  //   .probe28(idex_imm_gen_reg),
  //   .probe29(idex_pc_now_reg),
  //   .probe30(idex_alu_op_reg),
  //   .probe31(idex_use_rs2),
  //   .probe32(idex_mem_en),
  //   .probe33(idex_instr_type_reg),
  //   .probe34(idex_rf_wen),
  //   .probe35(exme_inst_reg),
  //   .probe36(exme_rf_rdata_a_reg),
  //   .probe37(exme_rf_rdata_b_reg),
  //   .probe38(exme_rf_waddr_reg),
  //   .probe39(exme_alu_result_reg),
  //   .probe40(0),
  //   // .probe40(exme_rpc_wen),
  //   .probe41(exme_mem_en),
  //   .probe42(exme_use_rs2),
  //   .probe43(exme_pc_now_reg),
  //   .probe44(exme_instr_type_reg),
  //   .probe45(exme_rf_wen),
  //   .probe46(mewb_rf_waddr_reg),
  //   .probe47(mewb_rf_wdata_reg),
  //   .probe48(0),
  //   // .probe48(mewb_rpc_wdata_reg),
  //   // .probe49(mewb_rpc_wen),
  //   .probe49(0),
  //   .probe50(mewb_instr_type_reg),
  //   .probe51(flush_IF),
  //   .probe52(flush_ID),
  //   .probe53(flush_EXE),
  //   .probe54(flush_MEM),
  //   .probe55(flush_WB),
  //   .probe56(bubble_IF),
  //   .probe57(bubble_ID),
  //   .probe58(bubble_EXE),
  //   .probe59(bubble_MEM),
  //   .probe60(bubble_WB)
  // );
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
    // NOTE
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
  /*=========== CSR MODULE BEGIN ===========*/
  /* CSR's read/write is carried out in MEM */
  wire[31:0] rf_wdata_csr;
  wire mem_state_i;
  assign mem_state_i = exme_mem_en || exme_state; 
  Csr u_csr(
    .clk_i(clk_i),
    .rst_i(rst_i),
    .inst_i(exme_inst_reg),
    .rf_rdata_a_i(exme_rf_rdata_a_reg),
    .rf_wdata_o(rf_wdata_csr),
    .priviledge_mode_o(priviledge_mode_o),
    .pc_now_i(exme_pc_now_reg),
    .idex_pc_now_i(idex_pc_now_reg),
    .ifid_pc_now_i(ifid_pc_now_reg),
    .wb0_pc_now_i(wb0_adr_o_reg),
    .pc_next_o(pc_csr_nxt),
    .pc_next_en(pc_csr_nxt_en),
    .mtime_exceed_i(mtime_exceed_i),
    .mtime_i(mtime_lo_i),
    .mtimeh_i(mtime_hi_i),
    .satp_o(satp_o),
    .flush_tlb_o(flush_tlb_o),
    // instruciont fetch page fault
    .if_exception_code_i(exme_if_exception_code_reg),
    .if_exception_addr_i(exme_pc_now_reg),
    // mem fetch page fault
    .mem_exception_code_i(mem_exception_code_i),
    .mem_exception_addr_i(mem_exception_addr_i),
    .mem_state_i(mem_state_i),
    // Illegal instruction
    .id_exception_instr_i(exme_exception_instr_reg),
    .id_exception_instr_wen(exme_exception_instr_wen_reg),
    .flush_exe_i(flush_csr_EXE),
    .leds(leds),
    .dip_sw_i(dip_sw),
    .msstatus_o(msstatus),
    .msie_o(msie),
    .mideleg_o(mideleg),
    .msip_o(msip),
    .mtvec_o(mtvec),
    .stvec_o(stvec),
    .mepc_o(mepc),
    .sepc_o(sepc),
    .mcause_o(mcause),
    .scause_o(scause)
  );
  /*=========== CSR MODULE END ===========*/
  always_ff @ (posedge clk_i) begin
    if (rst_i) begin
      //reset PRIVILEDGE_MODE to USER TYPE
      pc_if_state <= 0;

      wb1_stb_o <= 1'b0;
      wb1_cyc_o <= 1'b0;
      wb1_we_o <= 1'b0;
      wb1_sel_o <= 4'b0000;
      wb0_dat_o <= 32'b0;
      wb0_adr_o_reg <= 32'h8000_0000;
      wb1_dat_o <= 32'b0;
      wb1_adr_o <= 32'b0;
      // reset every reg stage to addi x0, x0, 0

      // -IF
      pc_branch_nxt_en <= 0;
      pc_reg <= 32'h8000_0000;
      wb0_stb_o <= 1'b0;
      wb0_cyc_o <= 1'b0;
      wb0_we_o <= 1'b0;
      wb0_sel_o <= 4'b0000;

      // IF-ID
      ifid_inst_reg <= 32'b0010011;
      ifid_pc_now_reg <= 32'h8000_0000;
      ifid_instr_type_reg <= I_TYPE;
      ifid_if_exception_code_reg <= 31'b0;

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
      idex_if_exception_code_reg <= 31'b0;
      idex_exception_instr_reg <= 31'b0;
      idex_exception_instr_wen_reg <= 0;
      

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
      // exme_rpc_wen <= 0;
      exme_pc_now_reg <= 32'h8000_0000;
      exme_state <= 0;
      exme_bias <= 0;
      exme_inst_reg_copy <= 32'b0010011;
      exme_rf_waddr_reg_copy <= 5'b0;
      exme_if_exception_code_reg <= 31'b0;
      exme_exception_instr_reg <= 31'b0;
      exme_exception_instr_wen_reg <= 0;

      // MEM-WB
      mewb_rf_wen <= 1;
      mewb_rf_waddr_reg <= 5'b0;
      mewb_rf_wdata_reg <= 32'b0;
      // mewb_rpc_wdata_reg <= 32'b0;
      mewb_instr_type_reg <= I_TYPE;
      // mewb_rpc_wen <= 0;

    // reset signal to none
    end else begin
      // IF
      if(flush_IF)begin
        if(flush_ID)begin

          // 这里判断一下 pc_nxt_reg 与多步之前判断出来的 pc_predict 是否一致，若一致就不需要冲刷
          // IF-ID reset to addi x0, x0, 0
          pc_if_state <=1;
          wb0_adr_o_reg <= pc_nxt_reg;
          pc_reg <= pc_nxt_reg;
          ifid_inst_reg <= 32'b0010011;
          ifid_pc_now_reg <= 32'h8000_0000;
          ifid_instr_type_reg <= I_TYPE;
          ifid_if_exception_code_reg <= 31'b0;
          wb0_stb_o <= 1'b0;
          wb0_cyc_o <= 1'b0;
          wb0_we_o <= 1'b0;
          wb0_sel_o <= 4'b0000;
        end
      end else if (bubble_IF) begin
        // wb0_adr_o_reg <= pc_nxt_reg;
        // if(!bubble_ID)begin
          // IF-ID reset to addi x0, x0, 0
        ifid_inst_reg <= 32'b0010011;
        ifid_pc_now_reg <= 32'h8000_0000;
        ifid_instr_type_reg <= I_TYPE;
        ifid_if_exception_code_reg <= 31'b0;
        wb0_dat_o <= {bubble_ID,31'b1};
        if(bubble_ID)begin
          wb0_stb_o <= 1'b0;
          wb0_cyc_o <= 1'b0;
          wb0_we_o <= 1'b0;
          wb0_sel_o <= 4'b0000;
        end
        // end
      end else begin
        wb0_dat_o <= 32'b0;
        if(!pc_if_state)begin // IDLE
          wb0_adr_o_reg <= pc_nxt_reg;
          pc_reg <= pc_nxt_reg;
          pc_if_state<=1;
          ifid_inst_reg <= 32'b0010011;
          wb0_stb_o <= 1'b1;
          wb0_cyc_o <= 1'b1;
          wb0_we_o <= 1'b0;
          wb0_sel_o <= 4'b1111;
        end else begin // Fetching Instruction
          if (wb0_ack_i) begin
            pc_if_state <= 0;
            pc_seq_nxt <= pc_reg+4;
            wb0_stb_o <= 1'b0;
            wb0_cyc_o <= 1'b0;
            wb0_we_o <= 1'b0;
            wb0_sel_o <= 4'b0000;
            ifid_inst_reg <= wb0_dat_i;
            ifid_pc_now_reg <= pc_reg;
            ifid_instr_type_reg <= imm_gen_type_o;
          end else if(if_exception_code_i)begin // IF state page fault
            pc_if_state <= 0;
            pc_seq_nxt <= pc_reg+4;
            wb0_stb_o <= 1'b0;
            wb0_cyc_o <= 1'b0;
            wb0_we_o <= 1'b0;
            wb0_sel_o <= 4'b0000;
            ifid_inst_reg <= 32'b0010011; // change the instr into addi x0,x0,0
            ifid_if_exception_code_reg <= if_exception_code_i; // pass the exception code to next stage
            ifid_pc_now_reg <= pc_reg;
            ifid_instr_type_reg <= I_TYPE;
          end else begin
            ifid_inst_reg <= 32'b0010011;
            wb0_stb_o <= 1'b1;
            wb0_cyc_o <= 1'b1;
            wb0_we_o <= 1'b0;
            wb0_sel_o <= 4'b1111;
            ifid_if_exception_code_reg <= 31'b0;
          end
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
          idex_if_exception_code_reg <= 31'b0;
          idex_exception_instr_reg <= 31'b0;
          idex_exception_instr_wen_reg <= 0;
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
          idex_if_exception_code_reg <= 31'b0;
          idex_exception_instr_reg <= 31'b0;
          idex_exception_instr_wen_reg <= 0;
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
        idex_if_exception_code_reg <= ifid_if_exception_code_reg;

        // NOTE
        case(ifid_inst_reg[6:0])
          LUI:begin // do nothing
            idex_exception_instr_wen_reg <= 0;
            idex_alu_op_reg <= ALU_ADD;
            idex_mem_en <= 0;  // 会不会在 MEM 阶段对内存进行读写请�???????, �???????级一级传下去
            idex_rf_wen <= 1;  // 会不会在 WB 阶段写回寄存�???????
          end
          BEQ_BNE_BLT_BGE_BLTU_BGTU:begin // PC+imm
            idex_exception_instr_wen_reg <= 0;
            idex_alu_op_reg <= ALU_ADD;
            idex_mem_en <= 0;
            idex_rf_wen <= 0;
          end
          LB_LW_LH_LBU_LHU:begin // PC+imm
            idex_exception_instr_wen_reg <= 0;
            idex_alu_op_reg <= ALU_ADD;
            idex_mem_en <= 1;
            idex_rf_wen <= 1;
          end
          SB_SW_SH:begin // rs1+imm
            idex_exception_instr_wen_reg <= 0;
            idex_alu_op_reg <= ALU_ADD;
            idex_mem_en <= 1;
            idex_rf_wen <= 0;
          end
          ADDI_ANDI_ORI_SLLI_SRLI_CLZ_CTZ_SLTI_SLTIU_XORI_SRAI:begin // rs1+imm
            idex_rf_wen <= 1;
            idex_mem_en <= 0;
            idex_exception_instr_wen_reg <= 0;
            case(ifid_inst_reg[14:12])
              3'b000:idex_alu_op_reg <= ALU_ADD;
              3'b010:idex_alu_op_reg <= ALU_LT;     // SLTI
              3'b011:idex_alu_op_reg <= ALU_LTU;    // SLTIU
              3'b111:idex_alu_op_reg <= ALU_AND;
              3'b110:idex_alu_op_reg <= ALU_OR;
              3'b101:
                if (ifid_inst_reg[30]) begin
                  idex_alu_op_reg <= ALU_SRA;
                end else begin
                  idex_alu_op_reg <= ALU_SRL;
                end
              3'b001:
                if (ifid_inst_reg[31:25] == 7'b0000000) begin
                  idex_alu_op_reg <= ALU_SLL;
                end else if (ifid_inst_reg[31:25] == 7'b0110000) begin
                  // 分为 CTZ, CLZ 两种情况
                  if (ifid_inst_reg[24:20] == 5'b00000) begin
                    idex_alu_op_reg <= ALU_CLZ;
                  end else if (ifid_inst_reg[24:20] == 5'b00001) begin
                    idex_alu_op_reg <= ALU_CTZ;
                  end
                end
              3'b100:idex_alu_op_reg <= ALU_XOR;   // XORI
            endcase
          end
          ADD_SUB_OR_AND_XOR_MINU_SLTU_SLL_SLT_SRA:begin // rs1+rs2
            idex_rf_wen <= 1;
            idex_exception_instr_wen_reg <= 0;
            case(ifid_inst_reg[14:12])
              3'b000:idex_alu_op_reg <= ifid_inst_reg[30] ? ALU_SUB : ALU_ADD;
              3'b011:idex_alu_op_reg <= ALU_LTU; // SLTU
              3'b111:idex_alu_op_reg <= ALU_AND;
              3'b110:begin
                if (ifid_inst_reg[31:25] == 7'b0000000) begin
                  // or
                  idex_alu_op_reg <= ALU_OR;
                end else if (ifid_inst_reg[31:25] == 7'b0000101) begin
                  // minu
                  idex_alu_op_reg <= ALU_MINU;
                end
              end

              3'b100:idex_alu_op_reg <= ALU_XOR;
              3'b010:idex_alu_op_reg <= ALU_LT;
              3'b001:idex_alu_op_reg <= ALU_SLL; // SLL
              3'b101:begin
                if (ifid_inst_reg[30]) begin
                  idex_alu_op_reg <= ALU_SRA;
                end else begin
                  idex_alu_op_reg <= ALU_SRL;
                end
              end
            endcase
            idex_mem_en <= 0;
          end
          JAL:begin
            idex_rf_wen <= 1;
            idex_alu_op_reg <= ALU_ADD;
            idex_mem_en <= 0;
            idex_exception_instr_wen_reg <= 0;
          end
          JALR:begin
            idex_rf_wen <= 1;
            idex_alu_op_reg <= ALU_ADD;
            idex_mem_en <= 0;
            idex_exception_instr_wen_reg <= 0;
          end
          AUIPC:begin
            idex_rf_wen <= 1;
            idex_alu_op_reg <= ALU_ADD;
            idex_mem_en <= 0;
            idex_exception_instr_wen_reg <= 0;
          end
          CSR_EBREAK_ECALL_MRET_SRET_SFENCEVMA:begin
            if(ifid_inst_reg[14:12]!=3'b000)begin // CSR(c,s,w)
              idex_rf_wen <= 1;
            end
            else begin //EBREAK,ECALL,MRET
              idex_rf_wen <= 0;
            end
            idex_alu_op_reg <= ALU_ADD;
            idex_mem_en <= 0;
          end
          default:begin
            idex_rf_wen <= 0;
            idex_alu_op_reg <= ALU_DEFAULT;
            idex_mem_en <= 0;
            idex_exception_instr_reg <= ifid_inst_reg;
            idex_exception_instr_wen_reg <= 1;
          end
        endcase
      end
      // EXE
      if(flush_EXE)begin
        pc_branch_nxt_en <= 0;
        pc_branch_nxt <= 32'b0;
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
          // exme_rpc_wen <= 0;
          exme_pc_now_reg <= 32'b0;
          exme_if_exception_code_reg <= 31'b0;
          exme_exception_instr_reg <= 31'b0;
          exme_exception_instr_wen_reg <= 0;
          
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
          // exme_rpc_wen <= 0;
          exme_pc_now_reg <= 32'b0;
          exme_if_exception_code_reg <= 31'b0;
          exme_exception_instr_reg <= 31'b0;
          exme_exception_instr_wen_reg <= 0;
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
        exme_if_exception_code_reg <= idex_if_exception_code_reg;
        exme_exception_instr_reg <= idex_exception_instr_reg;
        exme_exception_instr_wen_reg <= idex_exception_instr_wen_reg;


        // NOTE
        case(idex_instr_type_reg)
          U_TYPE: begin
          // don't need to do anything
            if(idex_inst_reg[6:0] == AUIPC)begin
              exme_alu_result_reg <= alu_result_i;
            end else begin
              exme_alu_result_reg <= idex_imm_gen_reg;
            end
            exme_rf_wen <= idex_rf_wen;

            // if (ifid_pc_now_reg == idex_pc_now_reg + 4) begin
            //   // no jump, continue predict
            //   pc_branch_nxt_en <= 0;
            //   pc_branch_nxt <= 32'b0;
            // end else begin
            //   // jump to pc+4
            //   pc_branch_nxt_en <= 1;
            //   pc_branch_nxt <= idex_pc_now_reg + 4;
            // end
            pc_branch_nxt_en <= 0;
            pc_branch_nxt <= 32'b0;

          end
          R_TYPE: begin
            exme_alu_result_reg <= alu_result_i;
            exme_rf_wen <= idex_rf_wen;
            if(idex_inst_reg[6:0] == JALR)begin
              // exme_rpc_wen <= 1;
              pc_branch_nxt <= alu_result_i;
              if (ifid_pc_now_reg != alu_result_i) begin
                pc_branch_nxt_en <= 1;
              end else begin
                pc_branch_nxt_en <= 0;
              end
              
            end
            else begin
              // if (ifid_pc_now_reg == idex_pc_now_reg + 4) begin
              //   pc_branch_nxt_en <= 0;
              //   pc_branch_nxt <= 32'b0;
              // end else begin
              //   pc_branch_nxt_en <= 1;
              //   pc_branch_nxt <= idex_pc_now_reg + 4;
              // end
              pc_branch_nxt_en <= 0;
              pc_branch_nxt <= 32'b0;
            end
          end
          I_TYPE: begin
            exme_alu_result_reg <= alu_result_i;
            exme_rf_wen <= idex_rf_wen;
            // if (ifid_pc_now_reg == idex_pc_now_reg + 4) begin
            //   pc_branch_nxt_en <= 0;
            //   pc_branch_nxt <= 32'b0;
            // end else begin
            //   pc_branch_nxt_en <= 1;
            //   pc_branch_nxt <= idex_pc_now_reg + 4;
            // end

            pc_branch_nxt_en <= 0;
            pc_branch_nxt <= 32'b0;
          end
          S_TYPE: begin
            exme_alu_result_reg <= alu_result_i;
            exme_rf_wen <= idex_rf_wen;
            // if (ifid_pc_now_reg == idex_pc_now_reg + 4) begin
            //   pc_branch_nxt_en <= 0;
            //   pc_branch_nxt <= 32'b0;
            // end else begin
            //   pc_branch_nxt_en <= 1;
            //   pc_branch_nxt <= idex_pc_now_reg + 4;
            // end
            pc_branch_nxt_en <= 0;
            pc_branch_nxt <= 32'b0;
          end
          B_TYPE: begin
            exme_alu_result_reg <= alu_result_i;
            exme_rf_wen <= idex_rf_wen;
            if ((idex_inst_reg[14:12] == 3'b001) && idex_rf_rdata_a_reg != idex_rf_rdata_b_reg ) begin
              // BNE
              // exme_rpc_wen <= 1;
              pc_branch_nxt_en <= 1;
              pc_branch_nxt <= alu_result_i;

              if (ifid_pc_now_reg == alu_result_i) begin
                pc_branch_nxt_en <= 0;
              end

            end else if ((idex_inst_reg[14:12] == 3'b000) && idex_rf_rdata_a_reg == idex_rf_rdata_b_reg ) begin
              // BEQ
              pc_branch_nxt_en <= 1;
              pc_branch_nxt <= alu_result_i;

              if (ifid_pc_now_reg == alu_result_i) begin
                pc_branch_nxt_en <= 0;
              end

            end else if ((idex_inst_reg[14:12] == 3'b100) && ($signed(idex_rf_rdata_a_reg) < $signed(idex_rf_rdata_b_reg))) begin
              // BLT
              pc_branch_nxt_en <= 1;
              pc_branch_nxt <= alu_result_i;

              if (ifid_pc_now_reg == alu_result_i) begin
                pc_branch_nxt_en <= 0;
              end
            end else if ((idex_inst_reg[14:12] == 3'b101) && !($signed(idex_rf_rdata_a_reg) < $signed(idex_rf_rdata_b_reg))) begin
              // BGE
              pc_branch_nxt_en <= 1;
              pc_branch_nxt <= alu_result_i;

              if (ifid_pc_now_reg == alu_result_i) begin
                pc_branch_nxt_en <= 0;
              end
            end else if ((idex_inst_reg[14:12] == 3'b110) && (idex_rf_rdata_a_reg < idex_rf_rdata_b_reg)) begin
              // BLTU
              pc_branch_nxt_en <= 1;
              pc_branch_nxt <= alu_result_i;

              if (ifid_pc_now_reg == alu_result_i) begin
                pc_branch_nxt_en <= 0;
              end
            end else if ((idex_inst_reg[14:12] == 3'b111) && !(idex_rf_rdata_a_reg < idex_rf_rdata_b_reg)) begin
              // BGEU
              pc_branch_nxt_en <= 1;
              pc_branch_nxt <= alu_result_i;

              if (ifid_pc_now_reg == alu_result_i) begin
                pc_branch_nxt_en <= 0;
              end
            end else begin

              if (ifid_pc_now_reg == idex_pc_now_reg + 4) begin
                pc_branch_nxt_en <= 0;
                pc_branch_nxt <= 32'b0;
              end else begin
                pc_branch_nxt_en <= 1;
                pc_branch_nxt <= idex_pc_now_reg + 4;
              end
              // exme_rpc_wen <= 0;
            end
          end
          J_TYPE: begin
            exme_alu_result_reg <= alu_result_i;
            exme_rf_wen <= idex_rf_wen;
            // exme_rpc_wen <= 1;

            pc_branch_nxt <= alu_result_i;

            if (idex_pc_now_reg != alu_result_i) begin
              pc_branch_nxt_en <= 1;
            end else begin
              pc_branch_nxt_en <= 0;
            end
          end
          default:begin
            exme_alu_result_reg <= alu_result_i;
            exme_rf_wen <= idex_rf_wen;
            // if (ifid_pc_now_reg == idex_pc_now_reg + 4) begin
            //   pc_branch_nxt_en <= 0;
            //   pc_branch_nxt <= 32'b0;
            // end else begin
            //   pc_branch_nxt_en <= 1;
            //   pc_branch_nxt <= idex_pc_now_reg + 4;
            // end
            pc_branch_nxt_en <= 0;
            pc_branch_nxt <= 32'b0;
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
        // mewb_rpc_wdata_reg <= 32'b0;
        // wb1_cyc_o <= 1'b0;
        // wb1_stb_o <= 1'b0;
        // exme_state <= 1'b0;

        mewb_instr_type_reg <= I_TYPE;
        // mewb_rpc_wen <= 0;

        // end
      end else if(bubble_MEM)begin
        if(!bubble_WB)begin
          // MEM-WB
          mewb_rf_wen <= 1;
          mewb_rf_waddr_reg <= 5'b0;
          mewb_rf_wdata_reg <= 32'b0;
          // mewb_rpc_wdata_reg <= 32'b0;
          mewb_instr_type_reg <= I_TYPE;
          // mewb_rpc_wen <= 0;

        end
      end else begin
        if(exme_instr_type_reg==SYS_TYPE)begin // SYS instruction should be done at here
          // TODO SYS instruction should be done at here
          mewb_rf_wen <= exme_rf_wen;
          mewb_rf_waddr_reg <= exme_rf_waddr_reg;
          mewb_rf_wdata_reg <= rf_wdata_csr;
          // mewb_rpc_wdata_reg <= 0;
          // mewb_rpc_wen <= exme_rpc_wen;
        end
        else begin
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
              if(wb1_exc_i)begin
                mewb_rf_wdata_reg <= 32'b0;
                mewb_rf_waddr_reg <= 5'b0; // write to 0, which means not write
              end else begin
                case(exme_inst_reg_copy[6:0])
                  LB_LW_LH_LBU_LHU: begin
                    if(exme_inst_reg_copy[14:12] == 3'b000)begin //LB
                      // 进行符号位扩�??
                      if(exme_bias[1:0]==2'b0) begin
                        if (wb1_dat_i[7]) begin
                          mewb_rf_wdata_reg <= {24'hffffff, wb1_dat_i[7:0]};
                        end else begin
                          mewb_rf_wdata_reg <= {24'b0, wb1_dat_i[7:0]};
                        end
                      end else if(exme_bias[1:0]==2'b01) begin
                        if (wb1_dat_i[15]) begin
                          mewb_rf_wdata_reg <= {24'hffffff, wb1_dat_i[15:8]};
                        end else begin
                          mewb_rf_wdata_reg <= {24'b0, wb1_dat_i[15:8]};
                        end
                      end else if(exme_bias[1:0]==2'b10) begin
                        if (wb1_dat_i[23]) begin
                          mewb_rf_wdata_reg <= {24'hffffff, wb1_dat_i[23:16]};
                        end else begin 
                          mewb_rf_wdata_reg <= {24'b0, wb1_dat_i[23:16]};
                        end
                      end else begin
                        if (wb1_dat_i[31]) begin
                          mewb_rf_wdata_reg <= {24'hffffff, wb1_dat_i[31:24]};
                        end else begin
                          mewb_rf_wdata_reg <= {24'b0, wb1_dat_i[31:24]};
                        end
                      end
                    end else if(exme_inst_reg_copy[14:12] == 3'b100) begin
                      // LBU, 零扩�??
                      if(exme_bias[1:0]==2'b0) begin
                        mewb_rf_wdata_reg <= {24'b0, wb1_dat_i[7:0]};
                      end else if(exme_bias[1:0]==2'b01) begin
                        mewb_rf_wdata_reg <= {24'b0, wb1_dat_i[15:8]};
                      end else if(exme_bias[1:0]==2'b10) begin
                        mewb_rf_wdata_reg <= {24'b0, wb1_dat_i[23:16]};
                      end else begin
                        mewb_rf_wdata_reg <= {24'b0, wb1_dat_i[31:24]};
                      end
                    end else if(exme_inst_reg_copy[14:12] == 3'b001)begin
                      // LH, 符号位扩�??
                      if(exme_bias[1:0]==2'b0) begin
                        if (wb1_dat_i[15]) begin
                          mewb_rf_wdata_reg <= {16'hffff, wb1_dat_i[15:0]};
                        end else begin
                          mewb_rf_wdata_reg <= {16'b0, wb1_dat_i[15:0]};
                        end
                      end else begin
                        if (wb1_dat_i[31]) begin
                          mewb_rf_wdata_reg <= {16'hffff, wb1_dat_i[31:16]};
                        end else begin
                          mewb_rf_wdata_reg <= {16'b0, wb1_dat_i[31:16]};
                        end
                      end
                    end else if(exme_inst_reg_copy[14:12] == 3'b101)begin
                      // LHU, 零扩�??
                      if(exme_bias[1:0]==2'b0) begin
                        mewb_rf_wdata_reg <= {16'b0, wb1_dat_i[15:0]};
                      end else begin
                        mewb_rf_wdata_reg <= {16'b0, wb1_dat_i[31:16]};
                      end
                    end else begin //LW
                      mewb_rf_wdata_reg <= wb1_dat_i;
                    end
                    // mewb_rf_wdata_reg <= {24'b0,(wb1_dat_i>>exme_alu_result_reg[1:0])[7:0]};
                    mewb_rf_waddr_reg <= exme_rf_waddr_reg_copy;
                  end
                endcase
              end
            end else begin
              wb1_cyc_o <= 1'b1;
              wb1_stb_o <= 1'b1;
              wb1_adr_o <= exme_alu_result_reg;
              exme_state <= 1'b1;
              exme_bias <= exme_alu_result_reg[1:0];
              exme_inst_reg_copy <= exme_inst_reg;
              exme_rf_waddr_reg_copy <= exme_rf_waddr_reg;

              // NOTE
              case(exme_inst_reg[6:0])
                LB_LW_LH_LBU_LHU: begin
                  wb1_we_o <= 1'b0;
                  if((exme_inst_reg[14:12] == 3'b000) || (exme_inst_reg[14:12] == 3'b100))begin //LB, LBU
                    wb1_sel_o <= (4'b0001 << exme_alu_result_reg[1:0]);  // 左移 0,1,2,3 �??
                    // wb1_sel_o <= 4'b0001;
                  end else if ((exme_inst_reg[14:12] == 3'b001) || (exme_inst_reg[14:12] == 3'b101)) begin
                    // LH, LHU
                    if(exme_alu_result_reg[1:0]==2'b0) begin
                      wb1_sel_o <= 4'b0011;
                    end else begin
                      wb1_sel_o <= 4'b1100;
                    end
                  end else if(exme_inst_reg[14:12] == 3'b010) begin //LW
                    wb1_sel_o <= 4'b1111;
                  end else begin
                    wb1_sel_o <= 4'b0000;
                  end
                end
                SB_SW_SH: begin
                  if(exme_inst_reg[14:12] == 3'b000)begin //SB
                    // wb1_dat_o <= exme_rf_rdata_b_reg;

                    if (exme_alu_result_reg[1:0] == 2'b00) begin
                      wb1_dat_o <= exme_rf_rdata_b_reg;
                    end else if (exme_alu_result_reg[1:0] == 2'b01) begin
                      wb1_dat_o <= (exme_rf_rdata_b_reg << 8);
                    end else if (exme_alu_result_reg[1:0] == 2'b10) begin
                      wb1_dat_o <= (exme_rf_rdata_b_reg << 16);
                    end else begin
                      wb1_dat_o <= (exme_rf_rdata_b_reg << 24);
                    end

                    wb1_sel_o <= (4'b0001 << exme_alu_result_reg[1:0]);
                    // wb1_sel_o <= 4'b0001;
                    wb1_we_o <= 1'b1;
                  end else if(exme_inst_reg[14:12] == 3'b010)begin //SW
                    wb1_dat_o <= exme_rf_rdata_b_reg;
                    wb1_sel_o <= 4'b1111;
                    wb1_we_o <= 1'b1;
                  end else if(exme_inst_reg[14:12] == 3'b001)begin  // SH
                    // wb1_dat_o <= exme_rf_rdata_b_reg;

                    if (exme_alu_result_reg[1:0] == 2'b00) begin
                      wb1_dat_o <= exme_rf_rdata_b_reg;
                    end else begin
                      wb1_dat_o <= (exme_rf_rdata_b_reg << 16);
                    end

                    if (exme_alu_result_reg[1:0] == 2'b00)begin
                      wb1_sel_o <= 4'b0011;
                    end else begin
                      wb1_sel_o <= 4'b1100;
                    end
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
            if(exme_inst_reg[6:0]==JAL || exme_inst_reg[6:0]==JALR)begin // zrp is a sb qaq
              // mewb_rpc_wdata_reg <=  exme_alu_result_reg;
              mewb_rf_wdata_reg <= exme_pc_now_reg + 4;
            end else begin
              mewb_rf_wdata_reg <= exme_alu_result_reg;
            end
            // mewb_rpc_wen <= exme_rpc_wen;
          end
        end
      end
      // WB
      // if(mewb_rpc_wen)begin
      //   pc_reg <= mewb_rpc_wdata_reg;
      // end

      // end
      end
  end
endmodule