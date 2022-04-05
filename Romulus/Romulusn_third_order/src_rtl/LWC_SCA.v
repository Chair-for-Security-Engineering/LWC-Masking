`include "LWC_config2.v"

module LWC_SCA (/*AUTOARG*/
   // Outputs
   do_data, pdi_ready, sdi_ready, rdi_ready, do_valid, do_last,
   // Inputs
   pdi_data, sdi_data, rdi_data, pdi_valid, sdi_valid, rdi_valid, do_ready, clk, rst
   ) ;
   output [`PDI_SHARES * `W - 1:0] do_data;
   output 	 pdi_ready, sdi_ready, rdi_ready, do_valid, do_last;

   input [`PDI_SHARES * `W - 1:0]  pdi_data;
   input [`SDI_SHARES * `SW - 1:0] sdi_data;
   input [`RW - 1:0] rdi_data;
   input 	 pdi_valid, sdi_valid, rdi_valid, do_ready;

   input 	 clk, rst;

   wire [`PDI_SHARES * `W - 1:0] pdo, pdi;

   wire [7:0] domain;
   wire [3:0] decrypt;
   
   wire		     srst, senc, sse;
   wire		     xrst, xenc, xse;
   wire		     yrst, yenc, yse;
   wire		     zrst, zenc, zse;
   wire 	     tk1s;   

   wire [56 - 1:0]      counter;
   wire [5:0] 	    constant;
   wire 	    correct_cnt;   
    
   mode_top datapath (
		      // Outputs
		      pdo, counter,
		      // Inputs
		      pdi, sdi_data, rdi_data, domain, decrypt, clk, srst, senc, sse, xrst, xenc, xse,
		      yrst, yenc, yse, zrst, zenc, zse, correct_cnt, constant, tk1s
		      ) ;
   api control (
		// Outputs
		do_data, pdi, pdi_ready, sdi_ready, rdi_ready, do_valid, do_last, domain,
		srst, senc, sse, xrst, xenc, xse, yrst, yenc, yse, zrst, zenc, zse, decrypt, correct_cnt, constant, tk1s,
		// Inputs
		counter, pdi_data, pdo, sdi_data, pdi_valid, sdi_valid, rdi_valid, do_ready,
		clk, rst
		) ;
   
   
endmodule // romulusn1v12rb

