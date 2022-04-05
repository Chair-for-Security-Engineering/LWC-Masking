----------------------------------------------------------------------------------
-- Company: SAL-Virginia Tech
-- Engineer: Behnaz Rezvani
-- 
-- Create Date: 02/05/2020
-- Module Name: GIFTCOFB - Behavioral
-- Tool Versions: Vivado 2019.1
-- Description: Version 2
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.SomeFunc.all;
use work.NIST_LWAPI_pkg.all;
use work.design_pkg.all;

-- Entity
----------------------------------------------------------------------
entity GIFTCOFB is
    Port(
        clk             : in std_logic;
        rst             : in std_logic;
        -- Data Input
        key             : in std_logic_vector(SDI_SHARES * CCSW -1 downto 0); -- SW = 32
        bdi             : in std_logic_vector(PDI_SHARES * CCW -1 downto 0); -- W = 32
        -- Key Control
        key_valid       : in std_logic;
        key_ready       : out std_logic;
        key_update      : in std_logic;
        -- BDI Control
        bdi_valid       : in std_logic;
        bdi_ready       : out std_logic;
        bdi_pad_loc     : in std_logic_vector(3 downto 0); -- W/8 = 4
        bdi_valid_bytes : in std_logic_vector(3 downto 0); -- W/8 = 4
        bdi_size        : in std_logic_vector(2 downto 0); -- W/(8+1) = 3
        bdi_eot         : in std_logic;
        bdi_eoi         : in std_logic;
        bdi_type        : in std_logic_vector(3 downto 0);
        hash_in         : in std_logic;
        decrypt_in      : in std_logic;
        -- Data Output
        bdo             : out std_logic_vector(PDI_SHARES * CCW -1 downto 0); -- W = 32
        -- BDO Control
        bdo_valid       : out std_logic;
        bdo_ready       : in std_logic;
        bdo_valid_bytes : out std_logic_vector(3 downto 0); -- W/8 = 4
        end_of_block    : out std_logic;
        bdo_type        : out std_logic_vector(3 downto 0);
        -- Tag Verification
        msg_auth        : out std_logic;
        msg_auth_valid  : out std_logic;
        msg_auth_ready  : in std_logic;
        rdi             : in  std_logic_vector(RW - 1 downto 0);
        rdi_valid       : in  std_logic;
        rdi_ready       : out std_logic    
    );
end GIFTCOFB;

-- Architecture
----------------------------------------------------------------------
architecture Behavioral of GIFTCOFB is

    -- Constants -----------------------------------------------------
    --bdi_type and bdo_type encoding
    constant HDR_AD         : std_logic_vector(3 downto 0) := "0001";
    constant HDR_MSG        : std_logic_vector(3 downto 0) := "0100";
    constant HDR_CT         : std_logic_vector(3 downto 0) := "0101";
    constant HDR_TAG        : std_logic_vector(3 downto 0) := "1000";
    constant HDR_KEY        : std_logic_vector(3 downto 0) := "1100";
    constant HDR_NPUB       : std_logic_vector(3 downto 0) := "1101";
    
    constant zero64         : std_logic_vector(63 downto 0) := (others => '0');
    
    -- Types ---------------------------------------------------------
    type fsm is (idle, load_key, wait_Npub, load_Npub, process_Npub,
                 load_AD, process_AD, load_data, process_data, output_tag,
                 load_tag, verify_tag, AD_delta1, AD_delta2, AD_delta3,
                 M_delta1, M_delta2, M_delta3);

    -- Signals -------------------------------------------------------
    signal X_in_mux_sel     : std_logic;
    signal GIFT_start       : std_logic;
    signal GIFT_rst         : std_logic;
    signal GIFT_done        : std_logic;

    signal KeyReg128_rst    : std_logic;
    signal KeyReg128_en     : std_logic;
    
    signal iDataReg_rst     : std_logic;
    signal iDataReg_en      : std_logic;
    signal iData_mux_sel    : std_logic_vector(1 downto 0);
    
    signal DstateReg_rst    : std_logic;
    signal DstateReg_en     : std_logic;
    signal Dstate_mux_sel   : std_logic_vector(1 downto 0);
    
    signal bdo_t_mux_sel    : std_logic;

    signal ctr_words        : std_logic_vector(2 downto 0);
    signal ctr_bytes        : std_logic_vector(4 downto 0);
    signal bdo_s            : std_logic_vector(PDI_SHARES * CCW -1 downto 0);

----------------------------------------------------------------------
begin
    bdo <= bdo_s;

    Datapath: entity work.GIFTCOFB_Datapath
    Port map(
        clk             => clk,
        rst             => rst,
        GIFT_start      => GIFT_start,
        GIFT_rst        => GIFT_rst,
        GIFT_done       => GIFT_done,
        X_in_mux_sel    => X_in_mux_sel,
        key             => key,
        bdi             => bdi,   
        bdi_size        => bdi_size,
        bdi_eot         => bdi_eot,
        bdo             => bdo_s,
        ctr_words       => ctr_words,
        ctr_bytes       => ctr_bytes,
        KeyReg128_rst   => KeyReg128_rst,
        KeyReg128_en    => KeyReg128_en,
        DstateReg_rst   => DstateReg_rst,
        DstateReg_en    => DstateReg_en,
        Dstate_mux_sel  => Dstate_mux_sel,
        iDataReg_rst    => iDataReg_rst,
        iDataReg_en     => iDataReg_en,
        iData_mux_sel   => iData_mux_sel,
        bdo_t_mux_sel   => bdo_t_mux_sel,
        fresh           => rdi 
    );

    Controller: entity work.GIFTCOFB_Controller
    Port map(
        clk             => clk,
        rst             => rst,
        GIFT_start      => GIFT_start,
        GIFT_rst        => GIFT_rst,
        GIFT_done       => GIFT_done,
        X_in_mux_sel    => X_in_mux_sel,
        key             => key,
        key_valid       => key_valid,
        key_ready       => key_ready,
        key_update      => key_update,
        bdi             => bdi,
        bdi_valid       => bdi_valid ,
        bdi_ready       => bdi_ready,
        bdi_valid_bytes => bdi_valid_bytes,
        bdi_size        => bdi_size,
        bdi_eot         => bdi_eot,
        bdi_eoi         => bdi_eoi,
        bdi_type        => bdi_type,
        decrypt_in      => decrypt_in,
        bdo             => bdo_s,
        bdo_valid       => bdo_valid,
        bdo_ready       => bdo_ready,
        bdo_valid_bytes => bdo_valid_bytes,
        end_of_block    => end_of_block,
        msg_auth        => msg_auth,
        msg_auth_valid  => msg_auth_valid,
        msg_auth_ready  => msg_auth_ready,
        ctr_words       => ctr_words,
        ctr_bytes       => ctr_bytes,
        KeyReg128_rst   => KeyReg128_rst,
        KeyReg128_en    => KeyReg128_en,
        DstateReg_rst   => DstateReg_rst,
        DstateReg_en    => DstateReg_en,
        Dstate_mux_sel  => Dstate_mux_sel,
        iDataReg_rst    => iDataReg_rst,
        iDataReg_en     => iDataReg_en,
        iData_mux_sel   => iData_mux_sel,
        bdo_t_mux_sel   => bdo_t_mux_sel,
        rdi_valid       => rdi_valid,
        rdi_ready       => rdi_ready 
    );

end Behavioral;
