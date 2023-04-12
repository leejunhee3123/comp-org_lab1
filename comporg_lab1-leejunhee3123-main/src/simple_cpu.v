// simple_cpu.v
// a single-cycle RISC-V microarchitecture (RV32I)

module simple_cpu
#(parameter DATA_WIDTH = 32)(
  input clk,
  input rstn
);


////////////////////////////////////////////////////
// Instruction Fetch (IF)
////////////////////////////////////////////////////


/* inst_memory: memory where instruction lies */
localparam NUM_INSTS = 64;

reg [31:0] inst_memory[0:NUM_INSTS-1];
initial $readmemb("data/inst.mem", inst_memory);


/* instruction: current instruction */
wire [DATA_WIDTH-1:0] instruction;
assign instruction = inst_memory[PC[7:2]]; // 64 inst


////////////////////////////////////////////////////
// Instruction Decode (ID)
////////////////////////////////////////////////////


// from register file 
wire [31:0] rs1_out, rs2_out;
wire [31:0] alu_out;
wire [31:0] sextimm;
wire [31:0] in_b;
// 5 bits for each (because there exist 32 registers)
wire [4:0] rs1, rs2, rd;

wire [6:0] opcode;
wire [6:0] funct7;
wire [2:0] funct3;

// instruction fields
assign opcode = instruction[6:0];

assign funct7 = instruction[31:25];
assign funct3 = instruction[14:12];

// R type
assign rs1 = instruction[19:15];
assign rs2 = instruction[24:20];
assign rd  = instruction[11:7];

/* m_control: control unit */
wire branch;
wire mem_read;
wire mem_to_reg;
wire [1:0] alu_op;
wire mem_write;
wire alu_src;
wire reg_write;
wire [1:0] jump;

control m_control(
  .opcode(opcode),

  .jump(jump),
  .branch(branch),
  .mem_read(mem_read),
  .mem_to_reg(mem_to_reg),
  .alu_op(alu_op),
  .mem_write(mem_write),
  .alu_src(alu_src),
  .reg_write(reg_write)
);

/* m_register_file: register file */
wire [DATA_WIDTH-1:0] write_data; 
wire [DATA_WIDTH-1:0] read_data;

register_file m_register_file(
  .clk(clk),
  .rs1(rs1),
  .rs2(rs2),
  .rd(rd),
  .reg_write(reg_write),
  .write_data(write_data),
  
  .rs1_out(rs1_out),
  .rs2_out(rs2_out)
);

///////////////////////////////////////////////////////////////////////////////
// TODO : Immediate Generator
imm_generator m_imm_generator(
  .instruction(instruction),

  .sextimm(sextimm)
);


//////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////
// Execute (EX) 
////////////////////////////////////////////////////


/* m_ALU_control: ALU control unit */
wire [3:0] alu_func;

ALU_control m_ALU_control(
  .alu_op(alu_op), 
  .funct7(funct7),
  .funct3(funct3),

  .alu_func(alu_func)
);

wire [31:0] alu_in2;

///////////////////////////////////////////////////////////////////////////////
// TODO : Need a fix
mux_2x1 m_mux_2x1(
  .select(alu_src),
  .in1(rs2_out),
  .in2(sextimm),
  
  .out(alu_in2)
);
//////////////////////////////////////////////////////////////////////////////
//assign alu_in2 = in_b;

//////////////////////////////////////////////////////////////////////////////

/* m_ALU: ALU */
wire [31:0] alu_in1;
wire alu_check;

assign alu_in1 = rs1_out;

ALU m_ALU(
  .in_a(alu_in1), 
  .in_b(alu_in2), // is input with reg allowed?? 
  .alu_func(alu_func),

  // output
  .result(alu_out),
  .check(alu_check)
);


////////////////////////////////////////////////////
// Memory (MEM) 
////////////////////////////////////////////////////

/* m_branch_control: generate taken for branch instruction */
wire taken;

branch_control m_branch_control(
  .branch(branch),
  .check(alu_check),

  .taken(taken)
);

///////////////////////////////////////////////////////////////////////////////
// TODO : Currently, NEXT_PC is always PC_PLUS_4. Using adders and muxes & 
// control signals, compute & assign the correct NEXT_PC.
/* m_next_pc_adder */
wire [DATA_WIDTH-1:0] PC_PLUS_4;
reg [DATA_WIDTH-1:0] PC;    // program counter (32 bits)

adder m_next_pc_adder(
  .in_a(PC),
  .in_b(32'h0000_0004),

  .result(PC_PLUS_4)
);

/* pc: update program counter */
wire [DATA_WIDTH-1:0] NEXT_PC;

always @(posedge clk) begin
  if (rstn == 1'b0) PC <= 32'h00000000;
  else PC <= NEXT_PC;
end

wire [DATA_WIDTH-1:0] PC_BRANCH;
adder m_pc_branch_adder(
  .in_a(PC),
  .in_b(sextimm),

  .result(PC_BRANCH)
);
wire [31:0] branch_out;
wire [31:0] jalr_out;

adder m_adder_for_jalr(
  .in_a(32'h0000_0004),
  .in_b(rs1_out),

  .result(jalr_out)
);
mux_2x1 m_mux_2x1_branch(
  .select(taken),
  .in1(PC_PLUS_4),
  .in2(PC_BRANCH),
  
  .out(branch_out)
);

mux_4x1 m_mux_4x1(
  .select(jump),
  .in1(branch_out),
  .in2(branch_out),
  .in3(PC_BRANCH),
  .in4(jalr_out),
  
  .out(NEXT_PC)
);
//////////////////////////////////////////////////////////////////////////////
//assign NEXT_PC = PC_PLUS_4;


///////////////////////////////////////////////////////////////////////////////
// TODO : Feed the appropriate inputs to the data memory
wire [1:0] maskmode ;
assign maskmode = funct3[1:0];
//////////////////////////////////////////////////////////////////////////////
/* m_data_memory: data memory */
data_memory m_data_memory(
  .clk(clk),
  .mem_write(mem_write),
  .mem_read(mem_read),
  .maskmode(maskmode),
  .sext(funct3[2]),
  .address(alu_out),
  .write_data(rs2_out),

  .read_data(read_data)
);
//////////////////////////////////////////////////////////////////////////////
mux_2x1 m_mux_2x1_2(
  .select(mem_to_reg),
  .in1(alu_out),
  .in2(read_data),
  
  .out(write_data)
);

////////////////////////////////////////////////////
// Write Back (WB) 
////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
// TODO : Need a fix
//////////////////////////////////////////////////////////////////////////////
//assign write_data = alu_out;

//////////////////////////////////////////////////////////////////////////////
endmodule