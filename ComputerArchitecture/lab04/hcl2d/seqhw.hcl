/*Neha Telhan (nt7ab) */

register pP {  
    # our own internal register. P_pc is its output, p_pc is its input.
	pc:64 = 0; # 64-bits wide; 0 is its default value.	
}

register cC {
    SF:1 = 0;
    ZF:1 = 0;
}

pc = P_pc;

stall_C = (icode != OPQ);
c_ZF = (valE == 0);
c_SF = (valE >= 0x8000000000000000);


# we can define our own input/output "wires" of any number of 0<bits<=80
wire opcode:8, icode:4, ifun:4, rB:4, rA:4, valC:64, valE:64, increment:64;
wire conditionsMet:1; 

##FETCH##
opcode = i10bytes[0..8];   # first byte read from instruction memory
ifun = i10bytes[0..4];
icode = opcode[4..8];      # top nibble of that byte

rB = [
   icode == JXX : REG_NONE;
   1 	    	: i10bytes[8..12];
];

rA = [
   icode == JXX	  : REG_NONE;
   1	       	  : i10bytes[12..16];
];

valC = [
     icode == JXX : i10bytes[8..72];
     1 	      	  : i10bytes[16..80];
];


# named constants can help make code readable
const TOO_BIG = 0xC; # the first unused icode in Y86-64

# Stat is a built-in output; STAT_HLT means "stop", STAT_AOK means 
# "continue".  The following uses the mux syntax described in the textbook
Stat = [
	icode == HALT : STAT_HLT;
	icode > 0xb   : STAT_INS;
	1             : STAT_AOK;
];

conditionsMet = [
	      ifun == ALWAYS : 1;
	      ifun == LE : C_SF || C_ZF;
	      ifun == LT : C_SF;
	      ifun == EQ : C_ZF;
	      ifun == NE : !C_ZF;
	      ifun == GE : !C_SF;
	      ifun == GT : !C_SF && !C_ZF;
	      1	      	 : 0;  
];

##EXECUTE##
# let's also increment a register in the register file; to do that we
# first pick a register to read
valE = [
	   icode == OPQ && ifun == XORQ : reg_outputA ^ reg_outputB;
	   icode == OPQ && ifun == ADDQ : reg_outputA + reg_outputB;
	   icode == OPQ && ifun == SUBQ : reg_outputB - reg_outputA;
	   icode == OPQ && ifun == ANDQ : reg_outputA & reg_outputB;
	   icode in {RMMOVQ, MRMOVQ} 	: reg_outputB + valC; #Memory Address
	   icode in {PUSHQ, CALL} 	: reg_outputB - 8;
	   icode in {POPQ, RET}   	: reg_outputB + 8;
];

reg_inputE =[
	   icode == IRMOVQ			: valC;
	   icode == RRMOVQ			: reg_outputA;
	   icode == MRMOVQ			: mem_output;
	   icode in {OPQ, POPQ, CALL, RET}      : valE;
];
	
reg_dstE = [
	 !conditionsMet && icode == CMOVXX : REG_NONE;
	 icode in {IRMOVQ, RRMOVQ, OPQ}    : rB;
	 icode in {MRMOVQ}   	    	   : rA;	
	 icode in {POPQ, CALL, RET}	   : REG_RSP;
	 1 	   			   : REG_NONE;
];

reg_inputM = [
	 icode in {POPQ} : mem_output;
];

reg_dstM = [
	 icode in {POPQ} : rA;
	 1     	  	 : REG_NONE;
];

##DECODE##
reg_srcA = [
	 (icode in {RRMOVQ, OPQ, RMMOVQ, PUSHQ}): rA;
	 1	   	  			: REG_NONE;
];

reg_srcB = [
	 (icode in {RRMOVQ, OPQ, RMMOVQ, MRMOVQ}): rB;
	 (icode in {PUSHQ, POPQ, CALL, RET})   	 : REG_RSP;	
	 1     	  				 : REG_NONE;
];

## Memory ##
mem_readbit = [
	    icode in {MRMOVQ, POPQ, RET}: 1;
	    1 	     	   : 0;
];

mem_writebit = [
	    icode in {RMMOVQ, PUSHQ, CALL} : 1;
	    icode == MRMOVQ   	     : 0;
	    1			     : 0;
];

mem_input = [
	  icode in {RMMOVQ, PUSHQ}  : reg_outputA;
	  icode in {CALL}   	    : P_pc + increment;
];

mem_addr =[
	 icode in {RMMOVQ, MRMOVQ, PUSHQ, CALL}  : valE;
	 icode in {POPQ, RET}   	   	 : reg_outputB;
];

# to make progress, we have to update the PC...
increment = [
          (icode in {HALT, NOP, RET})			: 1;
          (icode in {RRMOVQ, OPQ, CMOVXX, PUSHQ, POPQ}) : 2;
          (icode in {IRMOVQ, RMMOVQ, MRMOVQ}) 	 	: 10;
          (icode in {CALL, JXX})     			: 9;
          1                				: 10;
];
p_pc = [
     icode == JXX && conditionsMet : valC;
     icode in {CALL} 		   : valC;
     icode in {RET}		   : mem_output;   
     1	      	     		   : P_pc + increment;
]; 
