module ps2(
    input rst_n,
    input clk,
    input ps2clk,
    input ps2data,
    output [27:0] code
);

    localparam 
		idle = 1'b0,
		read   = 1'b1;

    reg [10:0] buffer_reg, buffer_next; //data
    reg [10:0] old_value_reg;
    reg state_reg, state_next; //idle vs read
    reg [3:0] cnt_reg, cnt_next; //bits red
    reg ps2clk_reg, ps2clk_next;

    wire clk_deb;

    deb deb_inst (
        .rst_n(rst_n),
        .clk(clk),
        .in(ps2clk),
        .out(clk_deb)
    );

    hex hex_inst(
        .in(hex_in),
        .out(code)
    );

    reg[15:0] hex_code; //dva najniza bita koda
    wire[7:0] data_in; //trenutni kod
    wire[15:0] hex_in;
    assign neg_edge = ps2clk_reg & ~ps2clk_next;
    assign data_in = buffer_reg[8:1];
    assign hex_in = hex_code;

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            buffer_reg <= 11'h000;
            state_reg <= 1'b0;
            cnt_reg <= 4'h0;
            ps2clk_reg <= 1'b0;
        end        

        else begin
           buffer_reg <= buffer_next;
            state_reg <= state_next;
            cnt_reg <= cnt_next;
            ps2clk_reg <= ps2clk_next; 
        end
            
    end
    
    always @(neg_edge) begin
        state_next = state_reg;
        buffer_next = buffer_reg;
        cnt_next = cnt_reg;
        ps2clk_next = clk_deb;
        case (state_reg)
            idle: begin
                if (neg_edge) begin
                    if (ps2data == 1'b1) begin
                        old_value_reg = buffer_reg;
                        cnt_next = 4'b1010;
                        state_next = read;
                    end else state_next = idle;
                end
            end
                
            read: begin
                if(neg_edge) begin
                    buffer_next[cnt_reg] = ps2data;
                    cnt_next = cnt_reg - 1;
                end
                if (cnt_reg == 4'h0) begin
                    //Ne moram da brisem neka ostane na ekranu samo F03C na primer
                    //Treba nam da parity checkira i ako ne valja da ne salje na hex, neko da je ugasen
                    hex_code = {old_value_reg[9:2], buffer_next[9:2]};
                    state_next = idle;
                end
            end
                
        endcase  
    end
    
    
endmodule
