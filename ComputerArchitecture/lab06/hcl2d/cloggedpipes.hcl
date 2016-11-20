/* Neha Telhan (nt7ab) */
 # -*-sh-*- # this line enables partial syntax highlighting in emacs

######### The PC #############
#register xF { pc:64 = 0; }
register pP {
    predPC:64 =0;
}

register cC {
    SF:1 = 0;
    ZF:1 = 0;
}

########## Fetch #############
pc = [
    M_icode == JXX && !M_cond : M_valA;
    M_icode == CALL && !M_cond : D_valC;
    W_icode == RET : W_valM;
    1: P_predPC;
];

#wire icode:4, rA:4, rB:4, valC:64;

f_icode = i10bytes[4..8];
f_ifun = i10bytes[0..4];
f_rA = i10bytes[12..16];
f_rB = i10bytes[8..12];

f_valC = [
     f_icode in { JXX, CALL } : i10bytes[8..72];
     1 : i10bytes[16..80];
];

f_stat = [
       f_icode == HALT : STAT_HLT;
       f_icode > 0xb : STAT_INS;       
       1 : STAT_AOK;
];

wire offset:64;#, f_valP:64;
offset = [
       f_icode in { HALT, NOP, RET } : 1;
       f_icode in { RRMOVQ, OPQ, PUSHQ, POPQ, CMOVXX } : 2;
       f_icode in { JXX, CALL } : 9;
       1 : 10;
];
f_valP = pc + offset;

p_predPC = [
    f_stat != STAT_AOK : pc;
    f_icode in {CALL, JXX} : f_valC;
    1 : f_valP;
];



#x_pc = f_valP;

#icode = f_icode;
#rA = f_rA;
#rB = f_rB;
#valC = f_valC;
#stat = f_stat;

########## Decode #############
# figure 4.56 on page 426

register fD {
	 stat:3 = STAT_BUB;
	 icode:4 = NOP;
	 ifun:4 = 0;
	 rA:4 = REG_NONE;
	 rB:4 = REG_NONE;
	 valC:64 = 0;
	 valP:64 = 0;
}



reg_srcA = [ # send to register file as read port; creates reg_outputA
	 D_icode in {RMMOVQ, OPQ, PUSHQ, CMOVXX} : D_rA;
	 D_icode in {POPQ, RET} : REG_RSP;
	 1 : REG_NONE;
];

reg_srcB = [ # send to register file as read port; creates reg_outputB
	 D_icode in {RMMOVQ, MRMOVQ, IRMOVQ, RRMOVQ, OPQ, CMOVXX} : D_rB;
	 D_icode in {PUSHQ, POPQ, CALL, RET} : REG_RSP;
	 1 : REG_NONE;
];

d_dstE = [
       D_icode in {IRMOVQ, RRMOVQ, OPQ, CMOVXX} : D_rB;
       D_icode in {PUSHQ, POPQ, CALL, RET} : REG_RSP;
       1 : REG_NONE;
];

d_dstM = [
       D_icode in { MRMOVQ, POPQ } : D_rA;
       1 : REG_NONE;
];

d_valA = [
       D_icode in {JXX, CALL} : D_valP;
       reg_srcA == REG_NONE: 0;
       reg_srcA == e_dstE : e_valE;
       reg_srcA == m_dstE : m_valE;
       reg_srcA == m_dstM : m_valM; # forward post-memory
       reg_srcA == W_dstE : W_valE;
       reg_srcA == W_dstM : W_valM; # forward pre-writeback
       e_dstE == D_rA : e_valE;
       M_dstE == D_rA : M_valE;
       W_dstE == D_rA : W_valE;
       1 : reg_outputA; # returned by register file based on reg_srcA
];

d_valB = [
       reg_srcB == REG_NONE: 0;
       # forward from another phase
       reg_srcB == e_dstE : e_valE;
       reg_srcB == m_dstE : m_valE;
       reg_srcB == W_dstE : W_valE;
       reg_srcB == m_dstM : m_valM; # forward post-memory
       reg_srcB == W_dstM : W_valM; # forward pre-writeback
       e_dstE == D_rB : e_valE;
       M_dstE == D_rB : M_valE;
       W_dstE == D_rB : W_valE;
       1 : reg_outputB; # returned by register file based on reg_srcA
];



d_stat = D_stat;
d_icode = D_icode;
d_ifun = D_ifun;
d_valC = D_valC;


########## Execute #############
register dE {
	 stat:3 = STAT_BUB;
	 icode:4 = NOP;
	 ifun:4 = 0;
	 valC:64 = 0;
	 valA:64 = 0;
	 valB:64 = 0;
	 dstE:4 = REG_NONE;
	 dstM:4 = REG_NONE;
}

wire conditionsMet:1;
conditionsMet = [
    E_ifun == ALWAYS : TRUE;
    E_ifun == LE : C_SF || C_ZF;
    E_ifun == LT : C_SF;
    E_ifun == EQ : C_ZF;
    E_ifun == NE : !C_ZF;
    E_ifun == GE : !C_SF;
    E_ifun == GT : !C_SF && !C_ZF;
    1 : FALSE;
];


e_valE = [
    E_icode == OPQ && E_ifun == XORQ : E_valA ^ E_valB;
    E_icode == OPQ && E_ifun == ADDQ : E_valA + E_valB;
    E_icode == OPQ && E_ifun == SUBQ : E_valB - E_valA;
    E_icode == OPQ && E_ifun == ANDQ : E_valA & E_valB;
    E_icode in { PUSHQ, CALL } : E_valB - 8;
    E_icode in { POPQ, RET }   : E_valB + 8;
    E_icode in { RMMOVQ, MRMOVQ } : E_valC + E_valB; #Given in lab solution...keep?
    E_icode == IRMOVQ : E_valC;
    E_icode == RRMOVQ : E_valA; 
    E_icode == CMOVXX : 0 + E_valA;
    1 : 0;
];

#Do some accounting of Condition Codes
c_ZF = e_valE == 0;
c_SF = e_valE >= 0x8000000000000000;
stall_C = E_icode != OPQ;

e_cond = conditionsMet;
e_stat =  E_stat;
e_dstE = [
    E_icode == CMOVXX && !conditionsMet : REG_NONE;
    1 : E_dstE;
];
e_dstM = E_dstM;
e_icode = E_icode;
e_valA = E_valA;

########## Memory #############

register eM {
	 stat:3 = STAT_BUB;
	 icode:4 = NOP;
	 valE:64 = 0;
	 valA:64 = 0;
	 dstE:4 = REG_NONE;
	 dstM:4 = REG_NONE;
	 cond:1 = 0;
}

mem_addr = [ # output to memory system
	 M_icode in { RMMOVQ, MRMOVQ, CALL, PUSHQ } : M_valE;
	 M_icode in {POPQ, RET} : M_valA;
	 1 : 0; # Other instructions don't need address
];
mem_readbit =  M_icode in { MRMOVQ, PUSHQ, POPQ, RET }; # output to memory system
mem_writebit = M_icode in { RMMOVQ, PUSHQ, CALL, RET }; # output to memory system
mem_input = M_valA;

m_stat = M_stat;
m_valM = mem_output; # input from mem_readbit and mem_addr
m_dstE = M_dstE;
m_dstM = M_dstM;
m_icode = M_icode;
m_valE = M_valE;

########## Writeback #############
register mW {
	 stat:3 = STAT_BUB;
	 icode:4 = NOP;
	 valE:64 = 0;
	 valM:64 = 0;
	 dstE:4 = REG_NONE;
	 dstM:4 = REG_NONE;
}

reg_inputE = W_valE;
reg_dstE = [
    D_icode in {PUSHQ, CALL, RET} : REG_RSP;
    D_icode in {POPQ} : REG_RSP;
    1 : W_dstE; #default to the writeback destE
];

reg_inputM = W_valM; # output: sent to register file
reg_dstM = W_dstM; # output: sent to register file

Stat = W_stat; # output; halts execution and reports errors


################ Pipeline Register Control #########################

wire loadUse:1, branchmiss:1, stallret:1;
loadUse = (E_icode in {MRMOVQ}) && (E_dstM in {reg_srcA, reg_srcB}); 
branchmiss = (E_icode in {JXX}) && (!e_cond);
stallret = (M_icode == RET || D_icode ==RET || E_icode == RET);

### Fetch
stall_P = (loadUse || f_stat != STAT_AOK || stallret);

### Decode
stall_D = loadUse;
bubble_D = branchmiss || stallret;

### Execute
bubble_E = loadUse || branchmiss;

### Memory

### Writeback
