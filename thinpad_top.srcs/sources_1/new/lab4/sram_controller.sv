module sram_controller #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,

    parameter SRAM_ADDR_WIDTH = 20,
    parameter SRAM_DATA_WIDTH = 32,

    localparam SRAM_BYTES = SRAM_DATA_WIDTH / 8,
    localparam SRAM_BYTE_WIDTH = $clog2(SRAM_BYTES)
) (
    // clk and reset
    input wire clk_i,
    input wire rst_i,

    // wishbone slave interface
    input wire wb_cyc_i,  // CYC_I 总线使能
    input wire wb_stb_i,  // STB_I master 发送请求
    output reg wb_ack_o,  // ACK_O salve 完成请求
    input wire [ADDR_WIDTH-1:0] wb_adr_i, // master想写入的地址 ADR_I
    input wire [DATA_WIDTH-1:0] wb_dat_i, // master想写入的数据 DAT_I
    output reg [DATA_WIDTH-1:0] wb_dat_o, // slave 写入的数据 DAT_O
    input wire [DATA_WIDTH/8-1:0] wb_sel_i, // master 读写字节使能 SEL_I
    input wire wb_we_i, // master 读写使能 WE_I

    // sram interface
    output reg [SRAM_ADDR_WIDTH-1:0] sram_addr, // 读写地址
    inout wire [SRAM_DATA_WIDTH-1:0] sram_data, // 读写数据
    output reg sram_ce_n, // 片选使能
    output reg sram_oe_n, // 输出使能
    output reg sram_we_n, // 写入使能
    output reg [SRAM_BYTES-1:0] sram_be_n // 字节使能
);
  
  // TODO: 实现 SRAM 控制器
  typedef enum logic [2:0] {
    STATE_IDLE = 0,
    STATE_READ = 1,
    STATE_READ_2 = 2,
    STATE_WRITE = 3,
    STATE_WRITE_2 = 4,
    STATE_WRITE_3 = 5,
    STATE_DONE = 6
  } state_t;
  state_t state;

  // 三态门逻辑定义 sram_data_t_reg=1 时，表示进入高阻态，对应读操作，sram_data_t_reg=0 时，表示进入输出状态，对应写操作
  wire [31:0] sram_data_i_comb;
  reg [31:0] sram_data_o_reg;
  reg sram_data_t_reg;

  assign sram_data = sram_data_t_reg ? 32'bz : sram_data_o_reg;
  assign sram_data_i_comb = sram_data;


  // SRAM 控制信号初始化
  reg sram_ce_n_reg;
  reg sram_oe_n_reg;
  reg sram_we_n_reg;
  
  // 不要在 initial 块和 always_ff 里面对同一个信号赋值，既然已经有 reset 的判断了，initial 是没有意义的，
  // 而且 initial 也不能综合，不应该出现在代码里面。如果已经写了正确的 reset 逻辑的话，直接去掉 initial 块就好了，
  // 寄存器不是变量，不需要声明的时候给初值。
  // initial begin
  //     sram_ce_n_reg = 1'b1;
  //     sram_oe_n_reg = 1'b1;
  //     sram_we_n_reg = 1'b1;
  // end

  assign sram_ce_n = sram_ce_n_reg;
  assign sram_oe_n = sram_oe_n_reg;
  assign sram_we_n = sram_we_n_reg;

  always_ff @ (posedge clk_i) begin
      if (rst_i) begin
          // SRAM 控制信号重置
          sram_ce_n_reg <= 1'b1;
          sram_oe_n_reg <= 1'b1;
          sram_we_n_reg <= 1'b1;
          wb_ack_o <= 1'b0;

          sram_data_t_reg <= 1'b1;
          sram_data_o_reg <= 32'b0;
          state <= STATE_IDLE;
      end else begin
          case (state)
              STATE_IDLE: begin
                  if (wb_stb_i && wb_cyc_i) begin
                      if (wb_we_i) begin // 写操作
                          sram_data_t_reg <= 1'b0; // sram_data_t_reg 表示进入输出状态，对应写操作
                          sram_data_o_reg <= wb_dat_i; 
                          sram_addr <= (wb_adr_i>>2); // Wishbone 的地址的单位是字节，而 SRAM 的地址的单位是 4 字节，所以地址有一个四倍的关系。
                          sram_ce_n_reg <= 1'b0;
                          sram_oe_n_reg <= 1'b1;
                          sram_we_n_reg <= 1'b1;
                          sram_be_n <= ~wb_sel_i;

                          state <= STATE_WRITE;
                      end else begin // 读操作
                          sram_data_t_reg <= 1'b1; // sram_data_t_reg 表示进入输入状态，对应读操作
                          sram_addr <= (wb_adr_i>>2); // Wishbone 的地址的单位是字节，而 SRAM 的地址的单位是 4 字节，所以地址有一个四倍的关系。
                          sram_ce_n_reg <= 1'b0;
                          sram_oe_n_reg <= 1'b0;
                          sram_we_n_reg <= 1'b1;
                          sram_be_n <= ~wb_sel_i;
                          state <= STATE_READ;
                      end
                  end
              end
              STATE_READ: begin
                  if (wb_stb_i && wb_cyc_i) begin
                    state <= STATE_READ_2;
                  end else begin
                    state <= STATE_IDLE; 
                  end
              end
              STATE_READ_2: begin
                  if (wb_stb_i && wb_cyc_i) begin
                    wb_dat_o <= sram_data_i_comb;
                    sram_ce_n_reg <= 1'b1;
                    sram_oe_n_reg <= 1'b1;
                    wb_ack_o <= 1'b1;
                    state <= STATE_DONE;
                  end else begin
                    sram_ce_n_reg <= 1'b1;
                    sram_oe_n_reg <= 1'b1;
                    state <= STATE_DONE; 
                  end
              end
              STATE_WRITE: begin
                  sram_we_n_reg <= 1'b0;
                  state <= STATE_WRITE_2;
              end
              STATE_WRITE_2: begin
                  sram_we_n_reg <= 1'b1;
                  state <= STATE_WRITE_3;
              end
              STATE_WRITE_3: begin
                  sram_ce_n_reg <= 1'b1;
                  wb_ack_o <= 1'b1;
                  state <= STATE_DONE;
              end
              STATE_DONE: begin
                  wb_ack_o <= 1'b0;
                  state <= STATE_IDLE;
              end
              default: begin
                  state <= STATE_IDLE;
              end
          endcase
      end
  end

endmodule
