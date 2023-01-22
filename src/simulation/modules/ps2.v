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
    wire[15:0] hex_in;
    reg neg_edge = 1'b1;
    // assign neg_edge = ps2clk_reg & ~ps2clk_next;
    assign code = hex_code_reg;

    integer i;
    reg parity = 1'b1;
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
    
    always @(*) begin
        state_next = state_reg;
        buffer_next = buffer_reg;
        cnt_next = cnt_reg;
        ps2clk_next = ps2clk;
       // neg_edge = 1';
        case (state_reg)
            idle: begin
               // if (neg_edge == 1'b1) begin
                    if (ps2data == 1'b0) begin
                        // hex_code_reg = {buffer_reg[7:0], buffer_reg[7:0]};
                        // if (buffer_reg == 8'hf0) begin
                        old_value_reg <= old_value_next;
                        old_value_next <= buffer_reg;
                        // end else begin
                        //     old_value_reg <= old_value_next;
                        //     old_value_next <= 8'h00;
                        // end
                        
                        cnt_next = 4'b1001;
                        state_next = read;
                        parity = 1'b1;
                        //hex_code_next = {ps2data, 15'h7777};
                    end else begin
                        state_next = idle;
                        //hex_code_next = {ps2data, 15'h7fff};
                    end
                //end
            end
                
            read: begin
                if(neg_edge == 1'b1) begin
                    buffer_next[4'b1001 - cnt_reg] = ps2data;
                    cnt_next = cnt_reg - 1;
                end
                
                if (cnt_reg == 4'h0) begin
                    //hex_code_next = {buffer_next[7:0], buffer_next[7:0]};

                    for (i = 0 ; i < 8; i = i + 1 ) begin
                        parity = parity ^ buffer_next[i];
                    end
                   
                    if (parity == buffer_next[8]) begin
                       // hex_code_next = {8'h11, buffer_next[7:0]};
                        if (old_value_next[7:0] == 8'h00) begin
                            hex_code_next = {8'h00, buffer_next[7:0]};  //kad se jednom pritisne od 1
                            //buffer_next = 8'h00;
                        end
                        else if (buffer_next[7:0] == old_value_next[7:0]) begin
                            hex_code_next = {8'h00, buffer_next[7:0]};  //kad se dugo drzi od 1B
                        end else if((old_value_next[7:0] == 8'he0) && (buffer_next[7:0] == 8'hf0)) begin
                            hex_code_next = hex_code_reg; //Kad se otpusti od dva da preskoci takt
                        end else if (buffer_next[7:0] == 8'hf0) begin
                            hex_code_next = {buffer_next[7:0], old_value_next[7:0]}; //kad se optusti od 1B
                         end else if (buffer_next[7:0] == 8'he0) begin
                             hex_code_reg = hex_code_next;
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