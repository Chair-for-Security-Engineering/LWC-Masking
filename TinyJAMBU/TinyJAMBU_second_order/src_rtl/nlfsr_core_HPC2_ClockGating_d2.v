/* modified netlist. Source: module nlfsr_core in file ./test/nlfsr_core.v */
/* clock gating is added to the circuit, the latency increased 2 time(s)  */

module nlfsr_core_HPC2_ClockGating_d2 (x_s0, clk, x_s1, x_s2, Fresh, /*rst,*/ y_s0, y_s1, y_s2/*, Synch*/);
    input [116:70] x_s0 ;
    input clk ;
    input [116:70] x_s1 ;
    input [116:70] x_s2 ;
    //input rst ;
    input [95:0] Fresh ;
    output [31:0] y_s0 ;
    output [31:0] y_s1 ;
    output [31:0] y_s2 ;
    //output Synch ;
    //wire clk_gated ;

    /* cells in depth 0 */
    //ClockGatingController #(2) ClockGatingInst ( .clk (clk), .rst (rst), .GatedClk (clk_gated), .Synch (Synch) ) ;

    /* cells in depth 1 */

    /* cells in depth 2 */
    nand_HPC2 #(.security_order(2), .pipeline(0)) U65 ( .a ({x_s2[94], x_s1[94], x_s0[94]}), .b ({x_s2[79], x_s1[79], x_s0[79]}), .clk (clk), .r ({Fresh[2], Fresh[1], Fresh[0]}), .c ({y_s2[9], y_s1[9], y_s0[9]}) ) ;
    nand_HPC2 #(.security_order(2), .pipeline(0)) U66 ( .a ({x_s2[93], x_s1[93], x_s0[93]}), .b ({x_s2[78], x_s1[78], x_s0[78]}), .clk (clk), .r ({Fresh[5], Fresh[4], Fresh[3]}), .c ({y_s2[8], y_s1[8], y_s0[8]}) ) ;
    nand_HPC2 #(.security_order(2), .pipeline(0)) U67 ( .a ({x_s2[92], x_s1[92], x_s0[92]}), .b ({x_s2[77], x_s1[77], x_s0[77]}), .clk (clk), .r ({Fresh[8], Fresh[7], Fresh[6]}), .c ({y_s2[7], y_s1[7], y_s0[7]}) ) ;
    nand_HPC2 #(.security_order(2), .pipeline(0)) U68 ( .a ({x_s2[91], x_s1[91], x_s0[91]}), .b ({x_s2[76], x_s1[76], x_s0[76]}), .clk (clk), .r ({Fresh[11], Fresh[10], Fresh[9]}), .c ({y_s2[6], y_s1[6], y_s0[6]}) ) ;
    nand_HPC2 #(.security_order(2), .pipeline(0)) U69 ( .a ({x_s2[90], x_s1[90], x_s0[90]}), .b ({x_s2[75], x_s1[75], x_s0[75]}), .clk (clk), .r ({Fresh[14], Fresh[13], Fresh[12]}), .c ({y_s2[5], y_s1[5], y_s0[5]}) ) ;
    nand_HPC2 #(.security_order(2), .pipeline(0)) U70 ( .a ({x_s2[89], x_s1[89], x_s0[89]}), .b ({x_s2[74], x_s1[74], x_s0[74]}), .clk (clk), .r ({Fresh[17], Fresh[16], Fresh[15]}), .c ({y_s2[4], y_s1[4], y_s0[4]}) ) ;
    nand_HPC2 #(.security_order(2), .pipeline(0)) U71 ( .a ({x_s2[88], x_s1[88], x_s0[88]}), .b ({x_s2[73], x_s1[73], x_s0[73]}), .clk (clk), .r ({Fresh[20], Fresh[19], Fresh[18]}), .c ({y_s2[3], y_s1[3], y_s0[3]}) ) ;
    nand_HPC2 #(.security_order(2), .pipeline(0)) U72 ( .a ({x_s2[101], x_s1[101], x_s0[101]}), .b ({x_s2[116], x_s1[116], x_s0[116]}), .clk (clk), .r ({Fresh[23], Fresh[22], Fresh[21]}), .c ({y_s2[31], y_s1[31], y_s0[31]}) ) ;
    nand_HPC2 #(.security_order(2), .pipeline(0)) U73 ( .a ({x_s2[100], x_s1[100], x_s0[100]}), .b ({x_s2[115], x_s1[115], x_s0[115]}), .clk (clk), .r ({Fresh[26], Fresh[25], Fresh[24]}), .c ({y_s2[30], y_s1[30], y_s0[30]}) ) ;
    nand_HPC2 #(.security_order(2), .pipeline(0)) U74 ( .a ({x_s2[87], x_s1[87], x_s0[87]}), .b ({x_s2[72], x_s1[72], x_s0[72]}), .clk (clk), .r ({Fresh[29], Fresh[28], Fresh[27]}), .c ({y_s2[2], y_s1[2], y_s0[2]}) ) ;
    nand_HPC2 #(.security_order(2), .pipeline(0)) U75 ( .a ({x_s2[99], x_s1[99], x_s0[99]}), .b ({x_s2[114], x_s1[114], x_s0[114]}), .clk (clk), .r ({Fresh[32], Fresh[31], Fresh[30]}), .c ({y_s2[29], y_s1[29], y_s0[29]}) ) ;
    nand_HPC2 #(.security_order(2), .pipeline(0)) U76 ( .a ({x_s2[98], x_s1[98], x_s0[98]}), .b ({x_s2[113], x_s1[113], x_s0[113]}), .clk (clk), .r ({Fresh[35], Fresh[34], Fresh[33]}), .c ({y_s2[28], y_s1[28], y_s0[28]}) ) ;
    nand_HPC2 #(.security_order(2), .pipeline(0)) U77 ( .a ({x_s2[97], x_s1[97], x_s0[97]}), .b ({x_s2[112], x_s1[112], x_s0[112]}), .clk (clk), .r ({Fresh[38], Fresh[37], Fresh[36]}), .c ({y_s2[27], y_s1[27], y_s0[27]}) ) ;
    nand_HPC2 #(.security_order(2), .pipeline(0)) U78 ( .a ({x_s2[96], x_s1[96], x_s0[96]}), .b ({x_s2[111], x_s1[111], x_s0[111]}), .clk (clk), .r ({Fresh[41], Fresh[40], Fresh[39]}), .c ({y_s2[26], y_s1[26], y_s0[26]}) ) ;
    nand_HPC2 #(.security_order(2), .pipeline(0)) U79 ( .a ({x_s2[95], x_s1[95], x_s0[95]}), .b ({x_s2[110], x_s1[110], x_s0[110]}), .clk (clk), .r ({Fresh[44], Fresh[43], Fresh[42]}), .c ({y_s2[25], y_s1[25], y_s0[25]}) ) ;
    nand_HPC2 #(.security_order(2), .pipeline(0)) U80 ( .a ({x_s2[94], x_s1[94], x_s0[94]}), .b ({x_s2[109], x_s1[109], x_s0[109]}), .clk (clk), .r ({Fresh[47], Fresh[46], Fresh[45]}), .c ({y_s2[24], y_s1[24], y_s0[24]}) ) ;
    nand_HPC2 #(.security_order(2), .pipeline(0)) U81 ( .a ({x_s2[93], x_s1[93], x_s0[93]}), .b ({x_s2[108], x_s1[108], x_s0[108]}), .clk (clk), .r ({Fresh[50], Fresh[49], Fresh[48]}), .c ({y_s2[23], y_s1[23], y_s0[23]}) ) ;
    nand_HPC2 #(.security_order(2), .pipeline(0)) U82 ( .a ({x_s2[92], x_s1[92], x_s0[92]}), .b ({x_s2[107], x_s1[107], x_s0[107]}), .clk (clk), .r ({Fresh[53], Fresh[52], Fresh[51]}), .c ({y_s2[22], y_s1[22], y_s0[22]}) ) ;
    nand_HPC2 #(.security_order(2), .pipeline(0)) U83 ( .a ({x_s2[91], x_s1[91], x_s0[91]}), .b ({x_s2[106], x_s1[106], x_s0[106]}), .clk (clk), .r ({Fresh[56], Fresh[55], Fresh[54]}), .c ({y_s2[21], y_s1[21], y_s0[21]}) ) ;
    nand_HPC2 #(.security_order(2), .pipeline(0)) U84 ( .a ({x_s2[90], x_s1[90], x_s0[90]}), .b ({x_s2[105], x_s1[105], x_s0[105]}), .clk (clk), .r ({Fresh[59], Fresh[58], Fresh[57]}), .c ({y_s2[20], y_s1[20], y_s0[20]}) ) ;
    nand_HPC2 #(.security_order(2), .pipeline(0)) U85 ( .a ({x_s2[86], x_s1[86], x_s0[86]}), .b ({x_s2[71], x_s1[71], x_s0[71]}), .clk (clk), .r ({Fresh[62], Fresh[61], Fresh[60]}), .c ({y_s2[1], y_s1[1], y_s0[1]}) ) ;
    nand_HPC2 #(.security_order(2), .pipeline(0)) U86 ( .a ({x_s2[89], x_s1[89], x_s0[89]}), .b ({x_s2[104], x_s1[104], x_s0[104]}), .clk (clk), .r ({Fresh[65], Fresh[64], Fresh[63]}), .c ({y_s2[19], y_s1[19], y_s0[19]}) ) ;
    nand_HPC2 #(.security_order(2), .pipeline(0)) U87 ( .a ({x_s2[88], x_s1[88], x_s0[88]}), .b ({x_s2[103], x_s1[103], x_s0[103]}), .clk (clk), .r ({Fresh[68], Fresh[67], Fresh[66]}), .c ({y_s2[18], y_s1[18], y_s0[18]}) ) ;
    nand_HPC2 #(.security_order(2), .pipeline(0)) U88 ( .a ({x_s2[87], x_s1[87], x_s0[87]}), .b ({x_s2[102], x_s1[102], x_s0[102]}), .clk (clk), .r ({Fresh[71], Fresh[70], Fresh[69]}), .c ({y_s2[17], y_s1[17], y_s0[17]}) ) ;
    nand_HPC2 #(.security_order(2), .pipeline(0)) U89 ( .a ({x_s2[101], x_s1[101], x_s0[101]}), .b ({x_s2[86], x_s1[86], x_s0[86]}), .clk (clk), .r ({Fresh[74], Fresh[73], Fresh[72]}), .c ({y_s2[16], y_s1[16], y_s0[16]}) ) ;
    nand_HPC2 #(.security_order(2), .pipeline(0)) U90 ( .a ({x_s2[100], x_s1[100], x_s0[100]}), .b ({x_s2[85], x_s1[85], x_s0[85]}), .clk (clk), .r ({Fresh[77], Fresh[76], Fresh[75]}), .c ({y_s2[15], y_s1[15], y_s0[15]}) ) ;
    nand_HPC2 #(.security_order(2), .pipeline(0)) U91 ( .a ({x_s2[99], x_s1[99], x_s0[99]}), .b ({x_s2[84], x_s1[84], x_s0[84]}), .clk (clk), .r ({Fresh[80], Fresh[79], Fresh[78]}), .c ({y_s2[14], y_s1[14], y_s0[14]}) ) ;
    nand_HPC2 #(.security_order(2), .pipeline(0)) U92 ( .a ({x_s2[98], x_s1[98], x_s0[98]}), .b ({x_s2[83], x_s1[83], x_s0[83]}), .clk (clk), .r ({Fresh[83], Fresh[82], Fresh[81]}), .c ({y_s2[13], y_s1[13], y_s0[13]}) ) ;
    nand_HPC2 #(.security_order(2), .pipeline(0)) U93 ( .a ({x_s2[97], x_s1[97], x_s0[97]}), .b ({x_s2[82], x_s1[82], x_s0[82]}), .clk (clk), .r ({Fresh[86], Fresh[85], Fresh[84]}), .c ({y_s2[12], y_s1[12], y_s0[12]}) ) ;
    nand_HPC2 #(.security_order(2), .pipeline(0)) U94 ( .a ({x_s2[96], x_s1[96], x_s0[96]}), .b ({x_s2[81], x_s1[81], x_s0[81]}), .clk (clk), .r ({Fresh[89], Fresh[88], Fresh[87]}), .c ({y_s2[11], y_s1[11], y_s0[11]}) ) ;
    nand_HPC2 #(.security_order(2), .pipeline(0)) U95 ( .a ({x_s2[95], x_s1[95], x_s0[95]}), .b ({x_s2[80], x_s1[80], x_s0[80]}), .clk (clk), .r ({Fresh[92], Fresh[91], Fresh[90]}), .c ({y_s2[10], y_s1[10], y_s0[10]}) ) ;
    nand_HPC2 #(.security_order(2), .pipeline(0)) U96 ( .a ({x_s2[85], x_s1[85], x_s0[85]}), .b ({x_s2[70], x_s1[70], x_s0[70]}), .clk (clk), .r ({Fresh[95], Fresh[94], Fresh[93]}), .c ({y_s2[0], y_s1[0], y_s0[0]}) ) ;

endmodule
