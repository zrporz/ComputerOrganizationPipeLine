module MtimeController #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    // clk and reset
    input wire clk_i,
    input wire rst_i,

    // wishbone slave interface
    input wire wb_cyc_i,
    input wire wb_stb_i,
    output reg wb_ack_o,
    input wire [ADDR_WIDTH-1:0] wb_adr_i,
    input wire [DATA_WIDTH-1:0] wb_dat_i,
    output reg [DATA_WIDTH-1:0] wb_dat_o,
    input wire [DATA_WIDTH/8-1:0] wb_sel_i,
    input wire wb_we_i,

    // mtimer --> csr
    output reg mtime_exceed_o,
    output reg [31:0] mtime_lo_o,
    output reg [31:0] mtime_hi_o
);
    reg[64:0] mtime_reg;
    reg[64:0] mtimecmp_reg;
    reg[4:0] mt_reg;

    logic state;
    always_comb begin
      mtime_lo_o = mtime_reg[31:0];
      mtime_hi_o = mtime_reg[63:32];
    end
    always_ff @ (posedge clk_i) begin
      if (rst_i) begin
        state <= 1;
        mtime_reg <= 64'b0;
        mtimecmp_reg <= 64'b0;
        mt_reg <= 5'b00000;
      end else begin
        if(state)begin
          if (wb_cyc_i && wb_stb_i) begin
            if(wb_we_i)begin
              case(wb_adr_i)
                32'h0200_BFF8:begin
                  mtime_reg[31:0] <= wb_dat_i;
                end
                32'h0200_BFFC:begin
                  mtime_reg[63:32] <= wb_dat_i;
                end
                32'h0200_4000:begin
                  mtimecmp_reg[31:0] <= wb_dat_i;
                end
                32'h0200_4004:begin
                  mtimecmp_reg[63:32] <= wb_dat_i;
                end
              endcase
            end else begin
              case(wb_adr_i)
                32'h0200_BFF8:begin
                  wb_dat_o <= mtime_reg[31:0];
                end
                32'h0200_BFFC:begin
                  wb_dat_o <= mtime_reg[63:32];
                end
                32'h0200_4000:begin
                  wb_dat_o <= mtimecmp_reg[31:0];
                end
                32'h0200_4004:begin
                  wb_dat_o <= mtimecmp_reg[63:32];
                end
              endcase    
            end
            wb_ack_o <= 1;
            state <= 0;
          end else if(mtimecmp_reg)begin
            // mtime_reg <= mtime_reg + 64'h100;
            if(mt_reg == 5'b01111)begin
              mtime_reg <= mtime_reg + 64'h1;
              mt_reg <= 5'b00000;
            end else begin
              mt_reg <= mt_reg + 5'b00001;
            end
            mtime_exceed_o <= (mtime_reg >= mtimecmp_reg);
            wb_ack_o <= 0;
            state <= 1;
          end
        end else begin
          wb_ack_o <= 0;
          state <= 1 ;
        end
      end
    end
endmodule