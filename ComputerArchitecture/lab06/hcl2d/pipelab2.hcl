/* Neha Telhan (nt7ab) */
#built off of the seq_memory.hcl file provided

######### The PC #############
register xF { pc:64 = 0; }


########## Fetch #############
########## Fetch #############
pc = F_pc;

#wire icode:4, ifun:4, rA:4, rB:4, valC:64;

f_icode = i10bytes[4..8];
f_ifun = i10bytes[0..4];
f_rA = i10bytes[12..16];
f_rB = i10bytes[8..12];


f_valC = [
	f_icode in { JXX } : i10bytes[8..72];
	1 : i10bytes[16..80];
];


f_Stat = [
       f_icode == HALT : STAT_HLT;
       f_icode in {NOP, RRMOVQ, IRMOVQ} : STAT_AOK;
       1 : STAT_INS;
];

wire offset:64, valP:64;
offset = [
	f_icode in { HALT, NOP, RET } : 1;
	f_icode in { RRMOVQ, OPQ, PUSHQ, POPQ } : 2;
	f_icode in { JXX, CALL } : 9;
	1 : 10;
];
valP = F_pc + offset;

########## Decode #############
register fD {
         Stat:3 = STAT_AOK;
         icode:4 = NOP;
         ifun:4 = 0;
         rA:4 = REG_NONE;
         rB:4 = REG_NONE;
         valC:64 = 0;
         valP:64 = 0;
}
reg_srcA = [
	D_icode in {RMMOVQ} : D_rA;
	1 : REG_NONE;
];
reg_srcB = [
	D_icode in {RMMOVQ, MRMOVQ} : D_rB;
	1 : REG_NONE;
];
d_dstM = [ 
    D_icode in {MRMOVQ} : D_rA;
    1: REG_NONE;
];
d_dstE = [
       D_icode in {IRMOVQ, RRMOVQ} : D_rB;
       1 : REG_NONE;
];

d_valA = [
    reg_srcA == REG_NONE : 0;
    reg_srcA == m_dstM : m_valM; ## Forward this to the post_memory
    reg_srcA == W_dstM : W_valM; ##Forward this to pre-writeback stage
    1 : reg_outputA; ##DEFAULT## #returned by register file based on reg_srcA
];

d_valB = [
    reg_srcB == REG_NONE : 0;
    reg_srcB == m_dstM : m_valM; ## Forward this to the post_memory
    reg_srcB == W_dstM : W_valM; ##Forward this to pre-writeback stage
    1 : reg_outputB;
];


d_Stat = D_Stat;
d_icode = D_icode;
d_ifun = D_ifun;
d_valC = D_valC;

########## Execute #############
register dE {
         Stat:3 = STAT_AOK;
         icode:4 = NOP;
         ifun:4 =  0;
         valC:64 = 0;
	 valB:64 = 0;
         valA:64 = 0;
         dstE:4 = REG_NONE;
         dstM:4 = REG_NONE;
}

wire loadUse:1;
wire operand1:64, operand2:64;

operand1 = [
	E_icode in { MRMOVQ, RMMOVQ } : E_valC;
	1: 0;
];
operand2 = [
	E_icode in { MRMOVQ, RMMOVQ } : reg_outputB;
	1: 0;
];

wire valE:64;

e_valE = [
	E_icode in { MRMOVQ, RMMOVQ } : operand1 + operand2;
	1 : 0;
];

stall_F = loadUse;
stall_D = loadUse;
bubble_E = loadUse;

e_Stat = E_Stat;
e_dstE = E_dstE;
e_dstM = E_dstM;
e_icode = E_icode;
e_valA = E_valA;

########## Memory #############
register eM {
         Stat:3 = STAT_AOK;
         icode:4 = NOP;
         valE:64 = 0;
         valA:64 = 0;
         dstE:4 = REG_NONE;
         dstM:4= REG_NONE;
}


mem_readbit = m_icode in { MRMOVQ };
mem_writebit = m_icode in { RMMOVQ };
mem_addr = [
	m_icode in { MRMOVQ, RMMOVQ } : M_valE;
];
mem_input = [
	m_icode in { RMMOVQ } : reg_outputA;
];

m_Stat = M_Stat;
m_icode = M_icode;
m_dstE = M_dstE;
m_dstM = M_dstM;
m_valE = M_valE;
m_valM = M_valA;

########## Writeback #############
register mW {
         Stat:3 = STAT_AOK;
         icode:4 = NOP;
         valE:64 = 0;
         valM:64 = 0;
         dstE:4 = REG_NONE;
         dstM:4 = REG_NONE;
}
reg_dstM = [ 
	M_icode in {MRMOVQ} : M_dstM;
	1: REG_NONE;
];
reg_inputM = [
	m_icode in {MRMOVQ} : mem_output;
];


Stat = [
	W_icode == HALT : STAT_HLT;
	W_icode > 0xb : STAT_INS;
	x_pc > 0xfff : STAT_ADR;
	1 : STAT_AOK;
];


reg_inputE =  W_valE;

reg_dstE = W_dstE;


x_pc = valP;