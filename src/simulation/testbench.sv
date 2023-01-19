`include "uvm_macros.svh"
import uvm_pkg::*;

class ps2_item extends uvm_sequence_item;

	rand bit ps2clk;
	randc bit ps2data;
	bit [7:0] code;
	
	`uvm_object_utils_begin(ps2_item)
		`uvm_field_int(ps2clk, UVM_DEFAULT)
		`uvm_field_int(ps2data, UVM_DEFAULT)
		`uvm_field_int(code, UVM_DEFAULT)
	`uvm_object_utils_end
	
	function new(string name = "ps2_item");
		super.new(name);
	endfunction
	
	virtual function string my_print();
		return $sformatf(
			"ps2clk = %1b ps2data = %1b code = %8b",
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
            //ovo mozda mora da se menja
			ps2_item item = ps2_item::type_id::create("item");
			start_item(item);
			item.randomize();
			`uvm_info("Generator", $sformatf("Item %0d/%0d created", i + 1, num), UVM_LOW)
			item.print();
			finish_item(item);
		end
	endtask
	
endclass

class driver extends uvm_driver #(reg8_item);
	
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
	
	virtual task run_phase(uvm_phase phase);
		super.run_phase(phase);
		forever begin
			reg8_item item;
			seq_item_port.get_next_item(item);
			`uvm_info("Driver", $sformatf("%s", item.my_print()), UVM_LOW)
			vif.ps2clk <= item.ps2clk;
			vif.ps2data <= item.ps2data;
			@(posedge vif.clk);
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
			reg8_item item = ps2_item::type_id::create("item");
			@(posedge vif.clk);
			item.ps2clk = vif.ps2clk;
			item.ps2data = vif.ps2data;
			item.code = vif.code;
			`uvm_info("Monitor", $sformatf("%s", item.my_print()), UVM_LOW)
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
	
	bit [7:0] ps2 = 8'h00;
	
	virtual function write(ps2_item item);
		if (ps2 == item.code)
			`uvm_info("Scoreboard", $sformatf("PASS!"), UVM_LOW)
		else
			`uvm_error("Scoreboard", $sformatf("FAIL! expected = %8b, got = %8b", ps2, item.code))
		
		//tu nam ide logika ps2










        //ne znamo sta je


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
		if (!uvm_config_db#(virtual reg8_if)::get(this, "", "ps2_vif", vif))
			`uvm_fatal("Test", "No interface.")
		e0 = env::type_id::create("e0", this);
		g0 = generator::type_id::create("g0");
	endfunction
	
	virtual function void end_of_elaboration_phase(uvm_phase phase);
		uvm_top.print_topology();
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
	input bit clk
);

	logic rst_n;
	logic ps2clk;
    logic ps2data;
    logic [7:0] out;

endinterface

module testbench;
    reg clk;

    ps2_if dut_if (
        .clk(clk)
    );

    ps2 dut (
        .clk(clk),
        .rst_n(dut_if.rst_n),
        .ps2clk(dut_if.ps2clk),
        .ps2data(dut_if.ps2data),
        .code(dut_if.code)
    )

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
