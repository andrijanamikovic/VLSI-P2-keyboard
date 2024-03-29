`include "uvm_macros.svh"
import uvm_pkg::*;

class ps2_item extends uvm_sequence_item;

	bit ps2clk;
	rand bit[7:0] ps2data;
	bit [15:0] code;

	// constraint c4 {
	// ps2data dist { 224 := 10, 118 := 1, 240 := 10, [1:10]:=1, [48:63]:= 1};
	// }
	
	`uvm_object_utils_begin(ps2_item)
		// `uvm_field_int(ps2clk, UVM_DEFAULT)
		`uvm_field_int(ps2data, UVM_DEFAULT)
		`uvm_field_int(code, UVM_DEFAULT)
	`uvm_object_utils_end
	
	function new(string name = "ps2_item");
		super.new(name);
	endfunction
	
	virtual function string my_print();
		return $sformatf(
			"ps2clk = %1b ps2data = %1b code = %16b",
			ps2clk, ps2data, code
		);
	endfunction

endclass

class generator extends uvm_sequence;

	`uvm_object_utils(generator)
	
	function new(string name = "generator");
		super.new(name);
	endfunction
	
	int num = 20;
	
	virtual task body();
		for (int i = 0; i < num; i++) begin
			ps2_item item = ps2_item::type_id::create("item");
			start_item(item);
			item.randomize();
			`uvm_info("Generator", $sformatf("Item %0d/%0d created", i + 1, num), UVM_LOW)
			finish_item(item);
		end
	endtask
	
endclass

class driver extends uvm_driver #(ps2_item);
	
	`uvm_component_utils(driver)
	
	function new(string name = "driver", uvm_component parent = null);
		super.new(name, parent);
	endfunction
	
	virtual ps2_if vif;
	
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if (!uvm_config_db#(virtual ps2_if)::get(this, "", "ps2_vif", vif))
			`uvm_fatal("Driver", "No interface.")
	endfunction
	
	reg[3:0] i;
	reg[3:0] j;
	reg parity = 1;
	reg zero = 1'b0;
	reg one = 1'b1;
	virtual task run_phase(uvm_phase phase);
		super.run_phase(phase);
		
		forever begin
			ps2_item item;
			seq_item_port.get_next_item(item);

			for (i = 0; i < 4'd11 ; i = i + 4'd1) begin
				@(negedge vif.ps2clk);
				@(posedge vif.clk);
				if (i == 4'd0) begin
					vif.ps2data <= zero;
				end else if (i == 4'd10) begin
					vif.ps2data <= one;
				end else if (i == 4'd9) begin
					for (j = 0; j < 4'd8; j = j + 4'd1) begin
						parity = parity ^ item.ps2data[j];
					end
					vif.ps2data <= parity;
				end else begin
					vif.ps2data <= item.ps2data[i-4'd1];
				end
				
			end
			`uvm_info("DriverTest", $sformatf("ps2data %8b , parity %0b", item.ps2data, parity), UVM_LOW)
			parity = 1;
			seq_item_port.item_done();
		end
	endtask
	
endclass

class monitor extends uvm_monitor;
	
	`uvm_component_utils(monitor)
	
	function new(string name = "monitor", uvm_component parent = null);
		super.new(name, parent);
	endfunction
	
	virtual ps2_if vif;
	uvm_analysis_port #(ps2_item) mon_analysis_port;
	
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if (!uvm_config_db#(virtual ps2_if)::get(this, "", "ps2_vif", vif))
			`uvm_fatal("Monitor", "No interface.")
		mon_analysis_port = new("mon_analysis_port", this);
	endfunction
	
	virtual task run_phase(uvm_phase phase);	
		super.run_phase(phase);
		@(posedge vif.clk);
		forever begin
			ps2_item item = ps2_item::type_id::create("item");
			@(posedge vif.clk);
			item.ps2clk = vif.ps2clk;
			item.ps2data = vif.ps2data;
			item.code = vif.code;
			mon_analysis_port.write(item);
		end
	endtask
	
endclass

class agent extends uvm_agent;
	
	`uvm_component_utils(agent)
	
	function new(string name = "agent", uvm_component parent = null);
		super.new(name, parent);
	endfunction
	
	driver d0;
	monitor m0;
	uvm_sequencer #(ps2_item) s0;
	
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		d0 = driver::type_id::create("d0", this);
		m0 = monitor::type_id::create("m0", this);
		s0 = uvm_sequencer#(ps2_item)::type_id::create("s0", this);
	endfunction
	
	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		d0.seq_item_port.connect(s0.seq_item_export);
	endfunction
	
endclass

class scoreboard extends uvm_scoreboard;
	
	`uvm_component_utils(scoreboard)
	
	function new(string name = "scoreboard", uvm_component parent = null);
		super.new(name, parent);
	endfunction
	
	uvm_analysis_imp #(ps2_item, scoreboard) mon_analysis_imp;
	
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		mon_analysis_imp = new("mon_analysis_imp", this);
	endfunction
	
	bit [15:0] ps2 = 15'h0000;
	reg[31:0] count = 32'h00000000;
	
	reg [9:0] buffer_reg = 10'h000;
	reg [9:0] old_value_reg = 10'd0;
	reg state_reg = 1'b0;
	reg [3:0] cnt_reg = 4'b1001;
	reg ps2clk_reg = 1'b0;
	reg ps2clk_next;
	
	reg[15:0] hex_code_reg = 16'h0000;
	reg neg_edge;
	reg[7:0] data_in; //trenutni kod
	reg[3:0]  i;
	reg parity;
	reg flag = 1'b1;

	bit[15:0] test_cur  = 15'h0000;
	bit[15:0] test_next = 15'h0000;

	virtual function write(ps2_item item);
		ps2 = test_cur;
		test_cur = test_next;
		if (flag == 1'b0) begin
			test_next = checkPS2(ps2, item);
		end else begin
			flag = 1'b0;
		end
			if (ps2 == item.code)
				`uvm_info("Scoreboard", $sformatf("PASS! expected = %16b, got = %16b, bit=%1b", ps2, item.code, item.ps2data), UVM_LOW)
			else
				`uvm_error("Scoreboard", $sformatf("FAIL!"))
			count = 32'h0;
	endfunction
		
	function bit[15:0] checkPS2(bit[15:0] ps2, ps2_item item);
		ps2clk_next = item.ps2clk;
		data_in = buffer_reg[8:1];
			count = count + 32'h1;
			ps2clk_reg = ps2clk_next;
			ps2clk_next = item.ps2clk;
			case (state_reg)
				1'b0: begin
						if (item.ps2data == 1'b0) begin
							old_value_reg = buffer_reg;
							buffer_reg = 10'h000;
							cnt_reg = 4'b1001;
							state_reg = 1'b1;
							parity = 1'b1;
						end else state_reg =  1'b0;
				end
					
				1'b1: begin
						buffer_reg[4'b1001 - cnt_reg] = item.ps2data;
						// `uvm_info("buffer_reg", $sformatf("buffer_reg=%10b", buffer_reg), UVM_LOW)
						cnt_reg = cnt_reg - 1;
					if (cnt_reg == 4'h0) begin
						parity = 1;
						for (i = 0 ; i < 8; i = i + 1 ) begin
							parity = parity ^ buffer_reg[i];
						end
						// `uvm_info("Made", $sformatf("Item %0d created, parity %b, buffer_reg %10b", hex_code_reg, parity, buffer_reg), UVM_LOW)

					
						if (parity == buffer_reg[8]) begin
							// `uvm_info("Parity", $sformatf("Item %10b created", buffer_reg), UVM_LOW)
							if (old_value_reg[7:0] == 8'h00) begin
								hex_code_reg = {8'h00, buffer_reg[7:0]};  //kad se jednom 1B
							end else 
							if  (buffer_reg[7:0] == old_value_reg[7:0]) begin
								hex_code_reg = {8'h00, buffer_reg[7:0]};  //kad se dugo drzi od 1B
							end else if((old_value_reg[7:0] == 8'he0) &&  (buffer_reg[7:0] == 8'hf0)) begin
								hex_code_reg = hex_code_reg; //Kad se otpusti od dva da preskoci takt
							end else if  (buffer_reg[7:0] == 8'hf0) begin
								hex_code_reg =  {buffer_reg[7:0], old_value_reg[7:0]}; //kad se optusti od 1B
							end else if  (buffer_reg[7:0] == 8'he0) begin
								// ceka 1 takt kad dodje 1B od koda od 2B
							end else if ((old_value_reg[7:0] == 8'he0) &&  (buffer_reg[7:0] != 8'hf0)) begin
								hex_code_reg = {old_value_reg[7:0], buffer_reg[7:0]}; //Drugi 2B koda od 2B a nije otpusni
							end else if (old_value_reg[7:0] == 8'hf0) begin
								hex_code_reg = {old_value_reg[7:0], buffer_reg[7:0]}; //Drugi B koda od 2B otpusni
							end
							old_value_reg = buffer_reg;
						end
						state_reg =  1'b0;
					end
				end
					
			endcase  
		ps2clk_reg = ps2clk_next;
		return hex_code_reg;
	endfunction

	
endclass

class env extends uvm_env;
	
	`uvm_component_utils(env)
	
	function new(string name = "env", uvm_component parent = null);
		super.new(name, parent);
	endfunction
	
	agent a0;
	scoreboard sb0;
	
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		a0 = agent::type_id::create("a0", this);
		sb0 = scoreboard::type_id::create("sb0", this);
	endfunction
	
	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		a0.m0.mon_analysis_port.connect(sb0.mon_analysis_imp);
	endfunction
	
endclass

class test extends uvm_test;

	`uvm_component_utils(test)
	
	function new(string name = "test", uvm_component parent = null);
		super.new(name, parent);
	endfunction
	
	virtual ps2_if vif;

	env e0;
	generator g0;
	
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if (!uvm_config_db#(virtual ps2_if)::get(this, "", "ps2_vif", vif))
			`uvm_fatal("Test", "No interface.")
		e0 = env::type_id::create("e0", this);
		g0 = generator::type_id::create("g0");
	endfunction
	
	virtual function void end_of_elaboration_phase(uvm_phase phase);
		// uvm_top.print_topology();
	endfunction
	
	virtual task run_phase(uvm_phase phase);
		phase.raise_objection(this);
		
		vif.rst_n <= 0;
		#20 vif.rst_n <= 1;

		g0.start(e0.a0.s0);
		phase.drop_objection(this);
	endtask

endclass

interface ps2_if (
	input bit clk,
	input bit ps2clk
);

	logic rst_n;
    logic ps2data;
    logic [15:0] code;

endinterface

module testbench;
    reg clk;
	reg ps2clk;

    ps2_if dut_if (
        .clk(clk),
		.ps2clk(ps2clk)
    );

    ps2 dut(
        .clk(clk),
        .rst_n(dut_if.rst_n),
        .ps2clk(ps2clk),
        .ps2data(dut_if.ps2data),
        .code(dut_if.code)
    );

	initial begin
		ps2clk = 1;
		forever begin
			#3 ps2clk = ~ps2clk;
		end
	end

    initial begin
		clk = 0;
		
		forever begin
			#10 clk = ~clk;
		end
	end

	initial begin
		uvm_config_db#(virtual ps2_if)::set(null, "*", "ps2_vif", dut_if);
		run_test("test");
	end


endmodule
