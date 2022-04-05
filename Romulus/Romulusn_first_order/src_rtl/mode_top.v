`include "LWC_config2.v"

module mode_top (/*AUTOARG*/
   // Outputs
   pdo, counter,
   // Inputs
   pdi, sdi, rdi, domain, decrypt, clk, srst, senc, sse, xrst, xenc, xse,
   yrst, yenc, yse, zrst, zenc, zse, correct_cnt, constant,
   tk1s
   ) ;
   output [`PDI_SHARES * `W - 1:0] pdo;
   output [56 - 1:0] counter;   

   input [`PDI_SHARES * `W - 1:0] pdi;
   input [`SDI_SHARES * `SW - 1:0] sdi;
   input [`RW - 1:0] rdi;
   input [7:0] 	 domain;
   input [3:0] 	 decrypt;   
   input 	 clk;
   input 	 srst, senc, sse;
   input 	 xrst, xenc, xse;
   input 	 yrst, yenc, yse;
   input 	 zrst, zenc, zse;
   input 	 correct_cnt;
   input [5:0] 	 constant;
   input 	 tk1s;

   wire [`PDI_SHARES * 128 - 1:0] tk1, tk2;
   wire [`PDI_SHARES * 64 - 1:0] tk3;
   wire [`PDI_SHARES * 128 - 1:0] tka, tkb;
   wire [`PDI_SHARES * 64 - 1:0] tkc;
   wire [`PDI_SHARES * 128 - 1:0] skinnyS;
   wire [`PDI_SHARES * 128 - 1:0] skinnyX, skinnyY;
   wire [`PDI_SHARES * 64 - 1:0] skinnyZ;
   wire [`PDI_SHARES * 128 - 1:0] S, TKX, TKY, TKZZ;
   wire [`PDI_SHARES * 64 - 1:0] TKZ, TKZN;   
   wire [`PDI_SHARES * 56 - 1:0] cin;   

   assign counter = TKZ[1*64-1:0*64+8] ^ TKZ[2*64-1:1*64+8];
   
   state_update_32b STATE_s0 (.state(S[1*128-1:0*128]), .pdo(pdo[1*`W-1:0*`W]), .skinny_state(skinnyS[1*128-1:0*128]), .pdi(pdi[1*`W-1:0*`W]), .clk(clk), .rst(srst), .enc(senc), .se(sse), .decrypt(decrypt));
   state_update_32b STATE_s1 (.state(S[2*128-1:1*128]), .pdo(pdo[2*`W-1:1*`W]), .skinny_state(skinnyS[2*128-1:1*128]), .pdi(pdi[2*`W-1:1*`W]), .clk(clk), .rst(srst), .enc(senc), .se(sse), .decrypt(decrypt));
    
   tkx_update_32b TKEYX_s0 (.tkx(TKX[1*128-1:0*128]), .skinny_tkx(skinnyX[1*128-1:0*128]), .skinny_tkx_revert(tk2[1*128-1:0*128]), .sdi(sdi[1*`SW-1:0*`SW]), .clk(clk), .rst(xrst), .enc(xenc), .se(xse));
   tkx_update_32b TKEYX_s1 (.tkx(TKX[2*128-1:1*128]), .skinny_tkx(skinnyX[2*128-1:1*128]), .skinny_tkx_revert(tk2[2*128-1:1*128]), .sdi(sdi[2*`SW-1:1*`SW]), .clk(clk), .rst(xrst), .enc(xenc), .se(xse)); 
   
   tky_update_32b TKEYY_s0 (.tky(TKY[1*128-1:0*128]), .skinny_tky(skinnyY[1*128-1:0*128]), .skinny_tky_revert(tk1[1*128-1:0*128]), .pdi(pdi[1*`W-1:0*`W]), .clk(clk), .rst(yrst), .enc(yenc), .se(yse));
   tky_update_32b TKEYY_s1 (.tky(TKY[2*128-1:1*128]), .skinny_tky(skinnyY[2*128-1:1*128]), .skinny_tky_revert(tk1[2*128-1:1*128]), .pdi(pdi[2*`W-1:1*`W]), .clk(clk), .rst(yrst), .enc(yenc), .se(yse));
   
   tkz_update_32b   TKEYZ_s0 (.tkz(TKZ[1*64-1:0*64]), .skinny_tkz(TKZN[1*64-1:0*64]), .skinny_tkz_revert(tk3[1*64-1:0*64]), .clk(clk), .rst(zrst), .enc(zenc), .se(zse));
   tkz_update_32b_2 TKEYZ_s1 (.tkz(TKZ[2*64-1:1*64]), .skinny_tkz(TKZN[2*64-1:1*64]), .skinny_tkz_revert(tk3[2*64-1:1*64]), .clk(clk), .rst(zrst), .enc(zenc), .se(zse));

   assign cin[1*56-1:0*56] = correct_cnt ? TKZ[1*64-1:0*64+8] : tkc[1*64-1:0*64+8];
   assign cin[2*56-1:1*56] = correct_cnt ? TKZ[2*64-1:1*64+8] : tkc[2*64-1:1*64+8];
   
   assign TKZZ[1*128-1:0*128] = tk1s ? {TKZ[1*64-1:0*64], 64'h0} : 128'h0;
   assign TKZZ[2*128-1:1*128] = tk1s ? {TKZ[2*64-1:1*64], 64'h0} : 128'h0;
   
   assign TKZN = skinnyZ;   

   pt8 permA_s0 (.tk1o(tka[1*128-1:0*128]), .tk1i(TKX[1*128-1:0*128]));
   pt8 permA_s1 (.tk1o(tka[2*128-1:1*128]), .tk1i(TKX[2*128-1:1*128]));
   
   pt8 permB_s0 (.tk1o(tkb[1*128-1:0*128]), .tk1i(TKY[1*128-1:0*128]));
   pt8 permB_s1 (.tk1o(tkb[2*128-1:1*128]), .tk1i(TKY[2*128-1:1*128])); 
   
   pt4 permC_s0 (.tk1o(tkc[1*64-1:0*64]), .tk1i(TKZ[1*64-1:0*64]));
   pt4 permC_s1 (.tk1o(tkc[2*64-1:1*64]), .tk1i(TKZ[2*64-1:1*64]));

   lfsr_gf56 CNT_s0 (.so(tk3[1*64-1:0*64]), .si(cin[1*56-1:0*56]), .domain(8'h00));
   lfsr_gf56 CNT_s1 (.so(tk3[2*64-1:1*64]), .si(cin[2*56-1:1*56]), .domain(domain));
   
   lfsr3_20 LFSR2_s0 (.so(tk1[1*128-1:0*128]), .si(tkb[1*128-1:0*128]));
   lfsr3_20 LFSR2_s1 (.so(tk1[2*128-1:1*128]), .si(tkb[2*128-1:1*128]));
   
   lfsr2_20 LFSR3_s0 (.so(tk2[1*128-1:0*128]), .si(tka[1*128-1:0*128]));
   lfsr2_20 LFSR3_s1 (.so(tk2[2*128-1:1*128]), .si(tka[2*128-1:1*128]));

   RoundFunction_HPC2_ClockGating_d1 SKINNY (.clk(clk),
                                             .ROUND_KEY_s0({TKZZ[1*128-1:0*128], TKY[1*128-1:0*128], TKX[1*128-1:0*128]}), 
                                             .ROUND_KEY_s1({TKZZ[2*128-1:1*128], TKY[2*128-1:1*128], TKX[2*128-1:1*128]}),
                                             .ROUND_IN_s0(S[1*128-1:0*128]),
                                             .ROUND_IN_s1(S[2*128-1:1*128]), 
                                             .ROUND_OUT_s0(skinnyS[1*128-1:0*128]),
                                             .ROUND_OUT_s1(skinnyS[2*128-1:1*128]), 
                                             .Fresh(rdi),
                                             .CONST_IN(constant));
                         			 
   KeyExpansion KEYEXP_s0 (.ROUND_KEY({skinnyZ[1*64-1:0*64], skinnyY[1*128-1:0*128], skinnyX[1*128-1:0*128]}), .KEY({TKZ[1*64-1:0*64],TKY[1*128-1:0*128],TKX[1*128-1:0*128]}));
   KeyExpansion KEYEXP_s1 (.ROUND_KEY({skinnyZ[2*64-1:1*64], skinnyY[2*128-1:1*128], skinnyX[2*128-1:1*128]}), .KEY({TKZ[2*64-1:1*64],TKY[2*128-1:1*128],TKX[2*128-1:1*128]}));
endmodule // mode_top
