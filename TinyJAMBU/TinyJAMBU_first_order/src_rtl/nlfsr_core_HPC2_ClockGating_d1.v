/* modified netlist. Source: module nlfsr_core in file ./test/nlfsr_core.v */
/* clock gating is added to the circuit, the latency increased 2 time(s)  */

module nlfsr_core_HPC2_ClockGating_d1 (x_s0, clk, x_s1, Fresh, /*rst,*/ y_s0, y_s1/*, Synch*/);
    input clk ;
    input [116:70] x_s0 ;
    input [116:70] x_s1 ;
    //input rst ;
    input [31:0] Fresh ;
    output [31:0] y_s0 ;
    output [31:0] y_s1 ;
    //output Synch ;
    //wire clk_gated ;

    /* cells in depth 0 */
    //ClockGatingController #(2) ClockGatingInst ( .clk (clk), .rst (rst), .GatedClk (clk_gated), .Synch (Synch) ) ;

    /* cells in depth 1 */

    /* cells in depth 2 */
    nand_HPC2 #(.security_order(1), .pipeline(0)) U65 ( .a ({x_s1[94], x_s0[94]}), .b ({x_s1[79], x_s0[79]}), .clk (clk), .r (Fresh[0]), .c ({y_s1[9], y_s0[9]}) ) ;
    nand_HPC2 #(.security_order(1), .pipeline(0)) U66 ( .a ({x_s1[93], x_s0[93]}), .b ({x_s1[78], x_s0[78]}), .clk (clk), .r (Fresh[1]), .c ({y_s1[8], y_s0[8]}) ) ;
    nand_HPC2 #(.security_order(1), .pipeline(0)) U67 ( .a ({x_s1[92], x_s0[92]}), .b ({x_s1[77], x_s0[77]}), .clk (clk), .r (Fresh[2]), .c ({y_s1[7], y_s0[7]}) ) ;
    nand_HPC2 #(.security_order(1), .pipeline(0)) U68 ( .a ({x_s1[91], x_s0[91]}), .b ({x_s1[76], x_s0[76]}), .clk (clk), .r (Fresh[3]), .c ({y_s1[6], y_s0[6]}) ) ;
    nand_HPC2 #(.security_order(1), .pipeline(0)) U69 ( .a ({x_s1[90], x_s0[90]}), .b ({x_s1[75], x_s0[75]}), .clk (clk), .r (Fresh[4]), .c ({y_s1[5], y_s0[5]}) ) ;
    nand_HPC2 #(.security_order(1), .pipeline(0)) U70 ( .a ({x_s1[89], x_s0[89]}), .b ({x_s1[74], x_s0[74]}), .clk (clk), .r (Fresh[5]), .c ({y_s1[4], y_s0[4]}) ) ;
    nand_HPC2 #(.security_order(1), .pipeline(0)) U71 ( .a ({x_s1[88], x_s0[88]}), .b ({x_s1[73], x_s0[73]}), .clk (clk), .r (Fresh[6]), .c ({y_s1[3], y_s0[3]}) ) ;
    nand_HPC2 #(.security_order(1), .pipeline(0)) U72 ( .a ({x_s1[101], x_s0[101]}), .b ({x_s1[116], x_s0[116]}), .clk (clk), .r (Fresh[7]), .c ({y_s1[31], y_s0[31]}) ) ;
    nand_HPC2 #(.security_order(1), .pipeline(0)) U73 ( .a ({x_s1[100], x_s0[100]}), .b ({x_s1[115], x_s0[115]}), .clk (clk), .r (Fresh[8]), .c ({y_s1[30], y_s0[30]}) ) ;
    nand_HPC2 #(.security_order(1), .pipeline(0)) U74 ( .a ({x_s1[87], x_s0[87]}), .b ({x_s1[72], x_s0[72]}), .clk (clk), .r (Fresh[9]), .c ({y_s1[2], y_s0[2]}) ) ;
    nand_HPC2 #(.security_order(1), .pipeline(0)) U75 ( .a ({x_s1[99], x_s0[99]}), .b ({x_s1[114], x_s0[114]}), .clk (clk), .r (Fresh[10]), .c ({y_s1[29], y_s0[29]}) ) ;
    nand_HPC2 #(.security_order(1), .pipeline(0)) U76 ( .a ({x_s1[98], x_s0[98]}), .b ({x_s1[113], x_s0[113]}), .clk (clk), .r (Fresh[11]), .c ({y_s1[28], y_s0[28]}) ) ;
    nand_HPC2 #(.security_order(1), .pipeline(0)) U77 ( .a ({x_s1[97], x_s0[97]}), .b ({x_s1[112], x_s0[112]}), .clk (clk), .r (Fresh[12]), .c ({y_s1[27], y_s0[27]}) ) ;
    nand_HPC2 #(.security_order(1), .pipeline(0)) U78 ( .a ({x_s1[96], x_s0[96]}), .b ({x_s1[111], x_s0[111]}), .clk (clk), .r (Fresh[13]), .c ({y_s1[26], y_s0[26]}) ) ;
    nand_HPC2 #(.security_order(1), .pipeline(0)) U79 ( .a ({x_s1[95], x_s0[95]}), .b ({x_s1[110], x_s0[110]}), .clk (clk), .r (Fresh[14]), .c ({y_s1[25], y_s0[25]}) ) ;
    nand_HPC2 #(.security_order(1), .pipeline(0)) U80 ( .a ({x_s1[94], x_s0[94]}), .b ({x_s1[109], x_s0[109]}), .clk (clk), .r (Fresh[15]), .c ({y_s1[24], y_s0[24]}) ) ;
    nand_HPC2 #(.security_order(1), .pipeline(0)) U81 ( .a ({x_s1[93], x_s0[93]}), .b ({x_s1[108], x_s0[108]}), .clk (clk), .r (Fresh[16]), .c ({y_s1[23], y_s0[23]}) ) ;
    nand_HPC2 #(.security_order(1), .pipeline(0)) U82 ( .a ({x_s1[92], x_s0[92]}), .b ({x_s1[107], x_s0[107]}), .clk (clk), .r (Fresh[17]), .c ({y_s1[22], y_s0[22]}) ) ;
    nand_HPC2 #(.security_order(1), .pipeline(0)) U83 ( .a ({x_s1[91], x_s0[91]}), .b ({x_s1[106], x_s0[106]}), .clk (clk), .r (Fresh[18]), .c ({y_s1[21], y_s0[21]}) ) ;
    nand_HPC2 #(.security_order(1), .pipeline(0)) U84 ( .a ({x_s1[90], x_s0[90]}), .b ({x_s1[105], x_s0[105]}), .clk (clk), .r (Fresh[19]), .c ({y_s1[20], y_s0[20]}) ) ;
    nand_HPC2 #(.security_order(1), .pipeline(0)) U85 ( .a ({x_s1[86], x_s0[86]}), .b ({x_s1[71], x_s0[71]}), .clk (clk), .r (Fresh[20]), .c ({y_s1[1], y_s0[1]}) ) ;
    nand_HPC2 #(.security_order(1), .pipeline(0)) U86 ( .a ({x_s1[89], x_s0[89]}), .b ({x_s1[104], x_s0[104]}), .clk (clk), .r (Fresh[21]), .c ({y_s1[19], y_s0[19]}) ) ;
    nand_HPC2 #(.security_order(1), .pipeline(0)) U87 ( .a ({x_s1[88], x_s0[88]}), .b ({x_s1[103], x_s0[103]}), .clk (clk), .r (Fresh[22]), .c ({y_s1[18], y_s0[18]}) ) ;
    nand_HPC2 #(.security_order(1), .pipeline(0)) U88 ( .a ({x_s1[87], x_s0[87]}), .b ({x_s1[102], x_s0[102]}), .clk (clk), .r (Fresh[23]), .c ({y_s1[17], y_s0[17]}) ) ;
    nand_HPC2 #(.security_order(1), .pipeline(0)) U89 ( .a ({x_s1[101], x_s0[101]}), .b ({x_s1[86], x_s0[86]}), .clk (clk), .r (Fresh[24]), .c ({y_s1[16], y_s0[16]}) ) ;
    nand_HPC2 #(.security_order(1), .pipeline(0)) U90 ( .a ({x_s1[100], x_s0[100]}), .b ({x_s1[85], x_s0[85]}), .clk (clk), .r (Fresh[25]), .c ({y_s1[15], y_s0[15]}) ) ;
    nand_HPC2 #(.security_order(1), .pipeline(0)) U91 ( .a ({x_s1[99], x_s0[99]}), .b ({x_s1[84], x_s0[84]}), .clk (clk), .r (Fresh[26]), .c ({y_s1[14], y_s0[14]}) ) ;
    nand_HPC2 #(.security_order(1), .pipeline(0)) U92 ( .a ({x_s1[98], x_s0[98]}), .b ({x_s1[83], x_s0[83]}), .clk (clk), .r (Fresh[27]), .c ({y_s1[13], y_s0[13]}) ) ;
    nand_HPC2 #(.security_order(1), .pipeline(0)) U93 ( .a ({x_s1[97], x_s0[97]}), .b ({x_s1[82], x_s0[82]}), .clk (clk), .r (Fresh[28]), .c ({y_s1[12], y_s0[12]}) ) ;
    nand_HPC2 #(.security_order(1), .pipeline(0)) U94 ( .a ({x_s1[96], x_s0[96]}), .b ({x_s1[81], x_s0[81]}), .clk (clk), .r (Fresh[29]), .c ({y_s1[11], y_s0[11]}) ) ;
    nand_HPC2 #(.security_order(1), .pipeline(0)) U95 ( .a ({x_s1[95], x_s0[95]}), .b ({x_s1[80], x_s0[80]}), .clk (clk), .r (Fresh[30]), .c ({y_s1[10], y_s0[10]}) ) ;
    nand_HPC2 #(.security_order(1), .pipeline(0)) U96 ( .a ({x_s1[85], x_s0[85]}), .b ({x_s1[70], x_s0[70]}), .clk (clk), .r (Fresh[31]), .c ({y_s1[0], y_s0[0]}) ) ;

endmodule
