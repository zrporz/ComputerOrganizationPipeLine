module Alu32 (
    input wire [3:0] op, // 操作�??????
    input wire [31:0] a, // 输入 a
    input wire [31:0] b, // 输入 b
    output reg [31:0] result // 输出结果

);

always @(*) begin
    case (op)
        4'b0001: result = a + b; // 加法操作
        4'b0010: result = a - b; // 减法操作
        4'b0011: result = a & b; // 按位�???
        4'b0100: result = a | b; // 按位�???
        4'b0101: result = a ^ b; // 按位异或
        4'b0110: result = ~a ; // 按位取非
        4'b0111: result = a << (b&31); // 逻辑左移 B 
        4'b1000: result = a >> (b&31); // 逻辑右移 B 
        4'b1001: result = $signed(a) >>> (b&31); // 算术右移 B 
        4'b1010: result = a<<(b%32)|a>>(32-b%32); // 循环左移 B
        default: result = 8'b0; // 其他操作码，输出默认值为 0
    endcase
end

endmodule