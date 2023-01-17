module ps2(
    input rst_n,
    input clk,
    input ps2clk,
    input ps2data,
    output [7:0] code,
);

    localparam 
		idle = 1'b0,
		read   = 1'b1;

    reg [10:0] buffer_reg, buffer_next; //data
    reg state_reg, state_next; //idle vs read
    reg [3:0] cnt_reg, cnt_next; //bits red
    reg ps2clk_reg, ps2clk_next;


    assign neg_edge = ps2clk_reg & ~ps2clk_next;
    assign code = buffer_reg[8:1];


    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) 
            buffer_reg <= 11'h000;
            state_reg <= 1'b0;
            cnt_reg <= 4'h0;

        else 
            buffer_reg <= buffer_next;
            state_reg <= state_next;
            cnt_reg <= cnt_next;
    end
    
    always @(*) begin
        state_next = state_reg;
        buffer_next = buffer_reg;
        cnt_next = cnt_reg;
        case (state_reg)
            idle:
                if (neg_edge) begin
                    cnt_next = 4'b1010;
                    state_next = read;
                end
            read:
                if(neg_edge) begin
                    buffer_next = {ps2data, buffer_reg[10:1]};
                    cnt_next = cnt_reg - 1;
                end
                if (cnt_reg == 4'h0) begin
                    state_next = idle;
                end
        endcase  
    end
    
    
endmodule
