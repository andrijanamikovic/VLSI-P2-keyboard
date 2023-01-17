module hex(input [15:0] in,
           output reg [27:0] out);
    
    always @(*) begin
        case (in)
            16'h001D: out = ~28'h000035e;
            16'hF01d: out =  ~28'h00000f1;
            16'h0000: out =  ~28'h0000000;
            default: out =  ~28'hfffffff;
        endcase
    end
    
endmodule
//01111110 0 