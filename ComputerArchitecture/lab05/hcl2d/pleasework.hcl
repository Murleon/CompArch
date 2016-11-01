/*Neha Telhan (nt7ab) */

########## the PC and condition codes registers #############
register pP { pc:64 = 0; } ##THIS IS FETCH REGISTER


########## Fetch #############
pc = P_pc;


f_icode = i10bytes[4..8];
f_ifun = i10bytes[0..4];
wire need_regs:1, need_immediate:1;

need_regs = f_icode in {RRMOVQ, IRMOVQ}; #True if icode is RR or IR
need_immediate = f_icode in {IRMOVQ};    #True if icode is IR

f_rA = [
   need_regs: i10bytes[12..16];
   1: REG_NONE;
];
f_rB = [
   need_regs: i10bytes[8..12];
   1: REG_NONE;
];

f_valC = [
       need_immediate && need_regs : i10bytes[16..80];
       need_immediate : i10bytes[8..72];
       1 : 0;
];

# new PC (assuming there is no jump)
####wire valP:64;
f_valP = [
     need_immediate && need_regs : pc + 10;
     need_immediate : pc + 9;
     need_regs : pc + 2;
     1 : pc + 1;
];

# pc register update
p_pc = [
     1 : f_valP;
];
stall_P = d_Stat != STAT_AOK; # so that we see the same final PC as the yis tool

f_Stat = [
       f_icode == HALT : STAT_HLT;
       f_icode in {NOP, RRMOVQ, IRMOVQ} : STAT_AOK;
       1 : STAT_INS;
];

#stall_F = f_Stat != STAT_AOK;


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

# source selection
reg_srcA = [	  
      D_icode in {RRMOVQ} : D_rA;
      1 : REG_NONE;
];

#d_srcA = reg_srcA;
#d_srcB = [
#       D_icode in {RRMOVQ} : D_rB;
#       1 : REG_NONE;
#];


# destination selection
d_dstE = [
       D_icode in {IRMOVQ, RRMOVQ} : D_rB;
       1 : REG_NONE;
];

d_valA = [
      reg_srcA == e_dstE : e_valE; 
      reg_srcA == m_dstE : m_valE;
      reg_srcA == W_dstE : W_valE; #forwarding
      1 : reg_outputA;
];

## Unsure about below ##
d_dstM = REG_NONE;
###d_valB = reg_outputB;

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
         valA:64 = 0;
         dstE:4 = REG_NONE;
         dstM:4 = REG_NONE;
        # srcA:4 = 0;
        # srcB:4 = 0;
}

e_valE = [
       E_icode == IRMOVQ : E_valC;
       E_icode == RRMOVQ : E_valA;
       1:0;
];


e_Stat = E_Stat;
e_dstE = E_dstE;
e_dstM = E_dstM;
e_icode = E_icode;
e_valA = E_valA;

########## Memory#############
register eM {
         Stat:3 = STAT_AOK;
         icode:4 = NOP;
         valE:64 = 0;
         valA:64 = 0;
         dstE:4 = REG_NONE;
         dstM:4= REG_NONE;
}

m_Stat = M_Stat;
m_icode = M_icode;
m_dstE = M_dstE;
m_dstM = M_dstM;
m_valE = M_valE;
m_valM = M_valA;

######### Writeback ###########
register mW {
         Stat:3 = STAT_AOK;
         icode:4 = NOP;
         valE:64 = 0;
         valM:64 = 0;
         dstE:4 = REG_NONE;
         dstM:4 = REG_NONE;
}

reg_inputE =  W_valE;

reg_dstE = W_dstE;


########## PC and Status updates #############

Stat = W_Stat;

