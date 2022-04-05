----------------------------------------------------------------------
-- Company: SAL-Virginia Tech
-- Engineer: Behnaz Rezvani
-- 
-- Create Date: 02/05/2020
-- Module Name: GIFTCOFB_Datapath - Behavioral
-- Tool Versions: Vivado 2019.1
-- Description: Version 1
-- 
----------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.SomeFunc.all;
use work.NIST_LWAPI_pkg.all;
use work.design_pkg.all;

-- Entity
----------------------------------------------------------------------
entity GIFTCOFB_Datapath is
  Port (
    clk, rst        : in  std_logic;
    GIFT_start      : in  std_logic;
    GIFT_rst        : in  std_logic;
    GIFT_done       : out std_logic;
    X_in_mux_sel    : in  std_logic;
    key, bdi        : in  std_logic_vector(PDI_SHARES * CCW - 1 downto 0);
    bdi_size        : in  std_logic_vector(2  downto 0);
    bdi_eot         : in  std_logic;
    bdo             : out std_logic_vector(PDI_SHARES * CCW - 1 downto 0);
    --msg_auth        : out std_logic;
    ctr_words       : in  std_logic_vector(2  downto 0);
    ctr_bytes       : in  std_logic_vector(4  downto 0);
    KeyReg128_rst   : in  std_logic;
    KeyReg128_en    : in  std_logic;
    DstateReg_rst   : in  std_logic;
    DstateReg_en    : in  std_logic;
    Dstate_mux_sel  : in  std_logic_vector(1  downto 0);
    iDataReg_rst    : in  std_logic;
    iDataReg_en     : in  std_logic;
    iData_mux_sel   : in  std_logic_vector(1  downto 0);
    bdo_t_mux_sel   : in  std_logic;
    fresh           : in  std_logic_vector(1151 downto 0)
  );
end GIFTCOFB_Datapath;

-- Architecture
----------------------------------------------------------------------
architecture Behavioral of GIFTCOFB_Datapath is

    -- Constants ----------------------------------------------------
    constant zero64         : std_logic_vector(63  downto 0) := (others => '0');
    constant zero127        : std_logic_vector(126 downto 0) := (others => '0');

    -- Signals -------------------------------------------------------
    signal X_in             : std_logic_vector(PDI_SHARES*128-1 downto 0);
    signal Y_out            : std_logic_vector(PDI_SHARES*128-1 downto 0);
    
    signal KeyReg128_in     : std_logic_vector(SDI_SHARES*128-1 downto 0);
    signal Key128_reg       : std_logic_vector(SDI_SHARES*128-1 downto 0);
    signal DstateReg_in     : std_logic_vector(PDI_SHARES*64-1  downto 0);
    signal DstateReg_out    : std_logic_vector(PDI_SHARES*64-1  downto 0); -- Delta state
    signal iDataReg_in      : std_logic_vector(PDI_SHARES*128-1 downto 0);
    signal iDataReg_out     : std_logic_vector(PDI_SHARES*128-1 downto 0);
    signal Y_out_32         : std_logic_vector(PDI_SHARES*32-1  downto 0);
    signal bdo_t            : std_logic_vector(PDI_SHARES*32-1 downto 0);
----------------------------------------------------------------------    
begin
   
   -- GIFT Cipher
    Ek: entity work.GIFT128 -- GIFT Cipher
    Port map(
        clk     => clk,
        rst     => GIFT_rst,
        start   => GIFT_start,
        Key     => Key128_reg,
        X_in    => X_in,
        Y_out   => Y_out,
        done    => GIFT_done,
        fresh   => fresh
    );
    
    -- Registers  
    KeyReg128_in(1*128-1 downto 0*128) <= Key128_reg(0*128+95 downto 0*128+0) & key(1*32-1 downto 0*32);
    KeyReg128_in(2*128-1 downto 1*128) <= Key128_reg(1*128+95 downto 1*128+0) & key(2*32-1 downto 1*32);  
    KeyReg128_in(3*128-1 downto 2*128) <= Key128_reg(2*128+95 downto 2*128+0) & key(3*32-1 downto 2*32);  
    KeyReg128_in(4*128-1 downto 3*128) <= Key128_reg(3*128+95 downto 3*128+0) & key(4*32-1 downto 3*32);  

    KeyReg128_s0: entity work.myReg -- Register for 128-bit secret key
    generic map( b => 128)
    Port map(
        clk     => clk,
        rst     => KeyReg128_rst,
        en      => KeyReg128_en,
        D_in    => KeyReg128_in(1*128-1 downto 0*128),
        D_out   => Key128_reg(1*128-1 downto 0*128)
    );

    KeyReg128_s1: entity work.myReg -- Register for 128-bit secret key
    generic map( b => 128)
    Port map(
        clk     => clk,
        rst     => KeyReg128_rst,
        en      => KeyReg128_en,
        D_in    => KeyReg128_in(2*128-1 downto 1*128),
        D_out   => Key128_reg(2*128-1 downto 1*128)
    );

    KeyReg128_s2: entity work.myReg -- Register for 128-bit secret key
    generic map( b => 128)
    Port map(
        clk     => clk,
        rst     => KeyReg128_rst,
        en      => KeyReg128_en,
        D_in    => KeyReg128_in(3*128-1 downto 2*128),
        D_out   => Key128_reg(3*128-1 downto 2*128)
    );

    KeyReg128_s3: entity work.myReg -- Register for 128-bit secret key
    generic map( b => 128)
    Port map(
        clk     => clk,
        rst     => KeyReg128_rst,
        en      => KeyReg128_en,
        D_in    => KeyReg128_in(4*128-1 downto 3*128),
        D_out   => Key128_reg(4*128-1 downto 3*128)
    );

    DeltaReg_s0: entity work.myReg -- Register for 64-bit delta state
    generic map( b => 64)
    Port map(
        clk     => clk,
        rst     => DstateReg_rst,
        en      => DstateReg_en,
        D_in    => DstateReg_in(1*64-1 downto 0*64),
        D_out   => DstateReg_out(1*64-1 downto 0*64)
    );

    DeltaReg_s1: entity work.myReg -- Register for 64-bit delta state
    generic map( b => 64)
    Port map(
        clk     => clk,
        rst     => DstateReg_rst,
        en      => DstateReg_en,
        D_in    => DstateReg_in(2*64-1 downto 1*64),
        D_out   => DstateReg_out(2*64-1 downto 1*64)
    ); 
	
    DeltaReg_s2: entity work.myReg -- Register for 64-bit delta state
    generic map( b => 64)
    Port map(
        clk     => clk,
        rst     => DstateReg_rst,
        en      => DstateReg_en,
        D_in    => DstateReg_in(3*64-1 downto 2*64),
        D_out   => DstateReg_out(3*64-1 downto 2*64)
    ); 	
    
	DeltaReg_s3: entity work.myReg -- Register for 64-bit delta state
    generic map( b => 64)
    Port map(
        clk     => clk,
        rst     => DstateReg_rst,
        en      => DstateReg_en,
        D_in    => DstateReg_in(4*64-1 downto 3*64),
        D_out   => DstateReg_out(4*64-1 downto 3*64)
    ); 	    
	
    iDataReg_s0: entity work.myReg -- Register for inputs: nonce, AD, PT/CT, expected tag
    generic map( b => 128)
    Port map(
        clk     => clk,
        rst     => iDataReg_rst,
        en      => iDataReg_en,
        D_in    => iDataReg_in(1*128-1 downto 0*128),
        D_out   => iDataReg_out(1*128-1 downto 0*128)
    );
    
    iDataReg_s1: entity work.myReg -- Register for inputs: nonce, AD, PT/CT, expected tag
    generic map( b => 128)
    Port map(
        clk     => clk,
        rst     => iDataReg_rst,
        en      => iDataReg_en,
        D_in    => iDataReg_in(2*128-1 downto 1*128),
        D_out   => iDataReg_out(2*128-1 downto 1*128)
    );
	
    iDataReg_s2: entity work.myReg -- Register for inputs: nonce, AD, PT/CT, expected tag
    generic map( b => 128)
    Port map(
        clk     => clk,
        rst     => iDataReg_rst,
        en      => iDataReg_en,
        D_in    => iDataReg_in(3*128-1 downto 2*128),
        D_out   => iDataReg_out(3*128-1 downto 2*128)
    );

    iDataReg_s3: entity work.myReg -- Register for inputs: nonce, AD, PT/CT, expected tag
    generic map( b => 128)
    Port map(
        clk     => clk,
        rst     => iDataReg_rst,
        en      => iDataReg_en,
        D_in    => iDataReg_in(4*128-1 downto 3*128),
        D_out   => iDataReg_out(4*128-1 downto 3*128)
    );
	
    -- Multiplexers
    with X_in_mux_sel select
        X_in(1*128-1 downto 0*128) <=  iDataReg_out(1*128-1 downto 0*128)       when '0',    -- Nonce
        rho1(Y_out(1*128-1 downto 0*128), Pad(iDataReg_out(1*128-1 downto 0*128), conv_integer(ctr_bytes))) xor (DstateReg_out(1*64-1 downto 0*64) & zero64) when others; -- AD or PT

    with X_in_mux_sel select
        X_in(2*128-1 downto 1*128) <=  iDataReg_out(2*128-1 downto 1*128)       when '0',    -- Nonce
        rho1(Y_out(2*128-1 downto 1*128), Pad2(iDataReg_out(2*128-1 downto 1*128), conv_integer(ctr_bytes))) xor (DstateReg_out(2*64-1 downto 1*64) & zero64) when others; -- AD or PT

    with X_in_mux_sel select
        X_in(3*128-1 downto 2*128) <=  iDataReg_out(3*128-1 downto 2*128)       when '0',    -- Nonce
        rho1(Y_out(3*128-1 downto 2*128), Pad2(iDataReg_out(3*128-1 downto 2*128), conv_integer(ctr_bytes))) xor (DstateReg_out(3*64-1 downto 2*64) & zero64) when others; -- AD or PT

    with X_in_mux_sel select
        X_in(4*128-1 downto 3*128) <=  iDataReg_out(4*128-1 downto 3*128)       when '0',    -- Nonce
        rho1(Y_out(4*128-1 downto 3*128), Pad2(iDataReg_out(4*128-1 downto 3*128), conv_integer(ctr_bytes))) xor (DstateReg_out(4*64-1 downto 3*64) & zero64) when others; -- AD or PT

    with Dstate_mux_sel select
        DstateReg_in(1*64-1 downto 0*64) <=  Y_out(0*128+127 downto 0*128+64)            when "00",   -- Tranc(Ek(N))
                                             Tripling(DstateReg_out(1*64-1 downto 0*64)) when "01",   -- 3*L
                                             Doubling(DstateReg_out(1*64-1 downto 0*64)) when others; -- 2*L
    with Dstate_mux_sel select
        DstateReg_in(2*64-1 downto 1*64) <=  Y_out(1*128+127 downto 1*128+64)            when "00",   -- Tranc(Ek(N))
                                             Tripling(DstateReg_out(2*64-1 downto 1*64)) when "01",   -- 3*L
                                             Doubling(DstateReg_out(2*64-1 downto 1*64)) when others; -- 2*L
    with Dstate_mux_sel select
        DstateReg_in(3*64-1 downto 2*64) <=  Y_out(2*128+127 downto 2*128+64)            when "00",   -- Tranc(Ek(N))
                                             Tripling(DstateReg_out(3*64-1 downto 2*64)) when "01",   -- 3*L
                                             Doubling(DstateReg_out(3*64-1 downto 2*64)) when others; -- 2*L	
    with Dstate_mux_sel select
        DstateReg_in(4*64-1 downto 3*64) <=  Y_out(3*128+127 downto 3*128+64)            when "00",   -- Tranc(Ek(N))
                                             Tripling(DstateReg_out(4*64-1 downto 3*64)) when "01",   -- 3*L
                                             Doubling(DstateReg_out(4*64-1 downto 3*64)) when others; -- 2*L												 
											 
    with iData_mux_sel select
        iDataReg_in(1*128-1 downto 0*128) <=  iDataReg_out(0*128+95 downto 0*128+0) & bdi(1*32-1 downto 0*32)                              when "00",   -- Nonce or expected tag
                                        myMux(iDataReg_out(0*128+95 downto 0*128+0) & bdo_t(1*32-1 downto 0*32), ctr_words, bdi_eot) when "10",   -- PT during the decryption                 
                                        myMux(iDataReg_out(0*128+95 downto 0*128+0) & bdi(1*32-1 downto 0*32), ctr_words, bdi_eot) when others; -- AD or PT
    with iData_mux_sel select
        iDataReg_in(2*128-1 downto 1*128) <=  iDataReg_out(1*128+95 downto 1*128+0) & bdi(2*32-1 downto 1*32)                              when "00",   -- Nonce or expected tag
                                        myMux(iDataReg_out(1*128+95 downto 1*128+0) & bdo_t(2*32-1 downto 1*32), ctr_words, bdi_eot) when "10",   -- PT during the decryption                 
                                        myMux(iDataReg_out(1*128+95 downto 1*128+0) & bdi(2*32-1 downto 1*32), ctr_words, bdi_eot) when others; -- AD or PT
    with iData_mux_sel select
        iDataReg_in(3*128-1 downto 2*128) <=  iDataReg_out(2*128+95 downto 2*128+0) & bdi(3*32-1 downto 2*32)                              when "00",   -- Nonce or expected tag
                                        myMux(iDataReg_out(2*128+95 downto 2*128+0) & bdo_t(3*32-1 downto 2*32), ctr_words, bdi_eot) when "10",   -- PT during the decryption                 
                                        myMux(iDataReg_out(2*128+95 downto 2*128+0) & bdi(3*32-1 downto 2*32), ctr_words, bdi_eot) when others; -- AD or PT
    with iData_mux_sel select
        iDataReg_in(4*128-1 downto 3*128) <=  iDataReg_out(3*128+95 downto 3*128+0) & bdi(4*32-1 downto 3*32)                              when "00",   -- Nonce or expected tag
                                        myMux(iDataReg_out(3*128+95 downto 3*128+0) & bdo_t(4*32-1 downto 3*32), ctr_words, bdi_eot) when "10",   -- PT during the decryption                 
                                        myMux(iDataReg_out(3*128+95 downto 3*128+0) & bdi(4*32-1 downto 3*32), ctr_words, bdi_eot) when others; -- AD or PT

    Y_out_32(1*32-1 downto 0*32) <=  Y_out(0*128+(127 - conv_integer(ctr_words)*32) downto 0*128+(96 - conv_integer(ctr_words)*32)); 
    Y_out_32(2*32-1 downto 1*32) <=  Y_out(1*128+(127 - conv_integer(ctr_words)*32) downto 1*128+(96 - conv_integer(ctr_words)*32)); 
    Y_out_32(3*32-1 downto 2*32) <=  Y_out(2*128+(127 - conv_integer(ctr_words)*32) downto 2*128+(96 - conv_integer(ctr_words)*32)); 
    Y_out_32(4*32-1 downto 3*32) <=  Y_out(3*128+(127 - conv_integer(ctr_words)*32) downto 3*128+(96 - conv_integer(ctr_words)*32)); 

    with bdo_t_mux_sel select                      
        bdo_t(1*32-1 downto 0*32) <=  Y_out_32(1*32-1 downto 0*32) xor bdi(1*32-1 downto 0*32) when '0',    -- CT(PT) =  Y xor PT(CT) 
                                      Y_out_32(1*32-1 downto 0*32) when others; -- Computed tag
    with bdo_t_mux_sel select                      
        bdo_t(2*32-1 downto 1*32) <=  Y_out_32(2*32-1 downto 1*32) xor bdi(2*32-1 downto 1*32) when '0',    -- CT(PT) =  Y xor PT(CT) 
                                      Y_out_32(2*32-1 downto 1*32) when others; -- Computed tag
    with bdo_t_mux_sel select                      
        bdo_t(3*32-1 downto 2*32) <=  Y_out_32(3*32-1 downto 2*32) xor bdi(3*32-1 downto 2*32) when '0',    -- CT(PT) =  Y xor PT(CT) 
                                      Y_out_32(3*32-1 downto 2*32) when others; -- Computed tag									  
    with bdo_t_mux_sel select                      
        bdo_t(4*32-1 downto 3*32) <=  Y_out_32(4*32-1 downto 3*32) xor bdi(4*32-1 downto 3*32) when '0',    -- CT(PT) =  Y xor PT(CT) 
                                      Y_out_32(4*32-1 downto 3*32) when others; -- Computed tag	
	bdo <= bdo_t;
    
    --msg_auth <=  '1' when ((iDataReg_out(1*128-1 downto 0*128) xor iDataReg_out(2*128-1 downto 1*128)) = (Y_out(1*128-1 downto 0*128) xor Y_out(2*128-1 downto 1*128))) else '0';
end Behavioral;
