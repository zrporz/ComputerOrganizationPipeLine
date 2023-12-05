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
        // CLZ
        4'b1011: begin
        if (a[31]==1) begin
            result = 0;
        end 
        else if (a[30]==1) begin result = 1; end
        else if (a[29]==1) begin result = 2; end
        else if (a[28]==1) begin result = 3; end
        else if (a[27]==1) begin result = 4; end
        else if (a[26]==1) begin result = 5; end
        else if (a[25]==1) begin result = 6; end
        else if (a[24]==1) begin result = 7; end
        else if (a[23]==1) begin result = 8; end
        else if (a[22]==1) begin result = 9; end
        else if (a[21]==1) begin result = 10; end
        else if (a[20]==1) begin result = 11; end
        else if (a[19]==1) begin result = 12; end
        else if (a[18]==1) begin result = 13; end
        else if (a[17]==1) begin result = 14; end
        else if (a[16]==1) begin result = 15; end
        else if (a[15]==1) begin result = 16; end
        else if (a[14]==1) begin result = 17; end
        else if (a[13]==1) begin result = 18; end
        else if (a[12]==1) begin result = 19; end
        else if (a[11]==1) begin result = 20; end
        else if (a[10]==1) begin result = 21; end
        else if (a[9]==1) begin result = 22; end
        else if (a[8]==1) begin result = 23; end
        else if (a[7]==1) begin result = 24; end
        else if (a[6]==1) begin result = 25; end
        else if (a[5]==1) begin result = 26; end
        else if (a[4]==1) begin result = 27; end
        else if (a[3]==1) begin result = 28; end
        else if (a[2]==1) begin result = 29; end
        else if (a[1]==1) begin result = 30; end
        else if (a[0]==1) begin result = 31; end
        else begin
                result = 32;
        end
        end
        // CTZ
        4'b1100: begin
        if (a[0]==1) begin
            result = 0;
        end 
        else if (a[1]==1) begin result = 1; end
        else if (a[2]==1) begin result = 2; end
        else if (a[3]==1) begin result = 3; end
        else if (a[4]==1) begin result = 4; end
        else if (a[5]==1) begin result = 5; end
        else if (a[6]==1) begin result = 6; end
        else if (a[7]==1) begin result = 7; end
        else if (a[8]==1) begin result = 8; end
        else if (a[9]==1) begin result = 9; end
        else if (a[10]==1) begin result = 10; end
        else if (a[11]==1) begin result = 11; end
        else if (a[12]==1) begin result = 12; end
        else if (a[13]==1) begin result = 13; end
        else if (a[14]==1) begin result = 14; end
        else if (a[15]==1) begin result = 15; end
        else if (a[16]==1) begin result = 16; end
        else if (a[17]==1) begin result = 17; end
        else if (a[18]==1) begin result = 18; end
        else if (a[19]==1) begin result = 19; end
        else if (a[20]==1) begin result = 20; end
        else if (a[21]==1) begin result = 21; end
        else if (a[22]==1) begin result = 22; end
        else if (a[23]==1) begin result = 23; end
        else if (a[24]==1) begin result = 24; end
        else if (a[25]==1) begin result = 25; end
        else if (a[26]==1) begin result = 26; end
        else if (a[27]==1) begin result = 27; end
        else if (a[28]==1) begin result = 28; end
        else if (a[29]==1) begin result = 29; end
        else if (a[30]==1) begin result = 30; end
        else if (a[31]==1) begin result = 31; end
        else begin
                result = 32;
        end
        end
        // MINU
        4'b1101: begin
            if (a < b) begin
                result = a;
            end else begin
                result = b;
            end
        end
        // LTU
        4'b1110: result = (a < b);
        // LT
        4'b1111: result = ($signed(a) < $signed(b));
        default: result = 8'b0; // 其他操作码，输出默认值为 0
    endcase
end

endmodule