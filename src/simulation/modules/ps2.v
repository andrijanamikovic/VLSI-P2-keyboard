module ps2(
    input rst_n,
    input clk,
    input ps2clk,
    input ps2data,
    output [15:0] code
);

    localparam 
		idle = 1'b0,
		read   = 1'b1;

    reg [9:0] buffer_reg, buffer_next; //data
    reg [9:0] old_value_reg = 10'd0;
    reg [9:0] old_value_next = 10'd0;
    reg state_reg, state_next; //idle vs read
    reg [3:0] cnt_reg, cnt_next; //bits red
    reg ps2clk_reg, ps2clk_next;




    reg[15:0] hex_code_reg, hex_code_next;
    wire[7:0] data_in; //trenutni kod
    wire[15:0] hex_in;
    assign neg_edge = ps2clk_reg & ~ps2clk_next;
    assign data_in = buffer_reg[8:1];
    assign hex_in = hex_code_reg;
    assign out = hex_in;

    integer i;
    reg parity;
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            hex_code_reg <= 16'h0000;
            buffer_reg <= 10'h000;
            state_reg <= 1'b0;
            cnt_reg <= 4'd0;
            ps2clk_reg <= 1'b0;
            
        end        

        else begin
            hex_code_reg <= hex_code_next;
            buffer_reg <= buffer_next;
            state_reg <= state_next;
            cnt_reg <= cnt_next;
            ps2clk_reg <= ps2clk_next; 
        end
            
    end
    
<<<<<<< Updated upstream
    always @(neg_edge) begin
=======
    always @(*) begin
>>>>>>> Stashed changes
        state_next = state_reg;
        buffer_next = buffer_reg;
        cnt_next = cnt_reg;
        ps2clk_next = ps2clk;
<<<<<<< Updated upstream
=======
        neg_edge = ps2clk_reg & ~ps2clk_next;
>>>>>>> Stashed changes
        case (state_reg)
            idle: begin
                if (neg_edge) begin
                    if (ps2data == 1'b0) begin
                        old_value_reg <= old_value_next;
                        old_value_next <= buffer_reg;
                        cnt_next = 4'b1001;
                        state_next = read;
                        parity = 1'b0;
<<<<<<< Updated upstream
                    end else state_next = idle;
=======
                        //hex_code_next = {ps2data, 15'h7fff};
                    end else begin
                        state_next = idle;
                        //hex_code_next = {ps2data, 15'h7fff};
                    end
>>>>>>> Stashed changes
                end
            end
                
            read: begin
                if(neg_edge) begin
                    buffer_next[4'b1001 - cnt_reg] = ps2data;
                    cnt_next = cnt_reg - 1;
<<<<<<< Updated upstream
=======
                   // hex_code_next = {cnt_reg, 12'hfff};
>>>>>>> Stashed changes
                end
                if (cnt_reg == 4'h0) begin
                    for (i = 0 ; i < 8; i = i + 1 ) begin
                        parity = parity ^ buffer_next[i];
                    end
                   
                    if (parity == buffer_next[9]) begin
<<<<<<< Updated upstream

                        if (buffer_next[7:0] == old_value_next[7:0]) begin
=======
                        if (old_value_next[7:0] == 8'h00) begin
                            hex_code_next = {8'h00, buffer_next[7:0]};  //kad se jednom pritisne od 1
                        end
                        else if (buffer_next[7:0] == old_value_next[7:0]) begin
>>>>>>> Stashed changes
                            hex_code_next = {8'h00, buffer_next[7:0]};  //kad se dugo drzi od 1B
                        end else if((old_value_next[7:0] == 8'he0) && (buffer_next[7:0] == 8'hf0)) begin
                            hex_code_next = hex_code_reg; //Kad se otpusti od dva da preskoci takt
                        end else if (buffer_next[7:0] == 8'hf0) begin
                            hex_code_next = {buffer_next[7:0], old_value_next[7:0]}; //kad se optusti od 1B
                         end else if (buffer_next[7:0] == 8'he0) begin
                            // ceka 1 takt kad dodje 1B od koda od 2B
                         end else if ((old_value_next[7:0] == 8'he0) && (buffer_next[7:0] != 8'hf0)) begin
                             hex_code_next = {old_value_next[7:0], buffer_next[7:0]}; //Drugi 2B koda od 2B a nije otpusni
                         end else if (old_value_next[7:0] == 8'hf0) begin
                            hex_code_next = {old_value_next[7:0], buffer_next[7:0]}; //Drugi B koda od 2B otpusni
                         end
                        
                    end
                    state_next = idle;
                end
            end
                
        endcase  
    end
    
    
endmodule