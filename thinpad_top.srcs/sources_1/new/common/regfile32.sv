module RegFile32(
    input wire clk,
    input wire reset,
    input wire [4:0] raddr_a,
    input wire [4:0] raddr_b,
    output reg [31:0] rdata_a,
    output reg [31:0] rdata_b,
    input wire [4:0] waddr,
    input wire [31:0] wdata,
    input wire we
);
    reg [31:0] register [31:0]; // 定义 32 �? 32 位寄存器
    always_comb begin
        rdata_a = register[raddr_a];
        rdata_b = register[raddr_b];
    end
    always_ff @(posedge clk) begin
        if(reset) begin
            for(integer i =0; i<32; i++) begin
                register[i] <= 0;
            end
        end
        if (we && waddr) begin
          register[waddr] <= wdata;
        end
    end
endmodule
