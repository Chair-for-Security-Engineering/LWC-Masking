--------------------------------------------------------------------------------
--! @file       xoodoo.vhd
--! @brief      Xoodoo permutation with a given number of rounds per cycle.
--!
--! @author     Guido Bertoni
--! @author     Silvia Mella <silvia.mella@st.com>
--! @license    To the extent possible under law, the implementer has waived all copyright
--!             and related or neighboring rights to the source code in this file.
--!             http://creativecommons.org/publicdomain/zero/1.0/
--------------------------------------------------------------------------------

library work;
    use work.xoodoo_globals.all;
    use work.NIST_LWAPI_pkg.all;
    use work.design_pkg.all;

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.std_logic_arith.all;

entity xoodoo is
    generic( roundPerCycle : integer  := 1);
    port (
        clk_i           : in std_logic;
        rst_i           : in std_logic;
        start_i         : in std_logic;
        state_valid_o   : out std_logic;
        init_reg        : in std_logic;
        word_in         : in std_logic_vector(PDI_SHARES * CCW - 1 downto 0);
        word_index_in   : in integer range 0 to 11;
        word_enable_in  : in std_logic;
        domain_i        : in std_logic_vector(31 downto 0);
        domain_enable_i : in std_logic;
        rdi             : in  std_logic_vector(RW - 1 downto 0);
        rdi_valid       : in  std_logic;
        rdi_ready       : out std_logic;
        word_out        : out std_logic_vector(PDI_SHARES * CCW - 1 downto 0)
    );
end xoodoo;

architecture rtl of xoodoo is

    --components

    component xoodoo_n_rounds
        generic( roundPerCycle : integer  := 1);
        port (
            clk          : in std_logic;
            state_in     : in  std_logic_vector(PDI_SHARES*384-1 downto 0);
            state_out    : out std_logic_vector(PDI_SHARES*384-1 downto 0);
            rnd          : in std_logic_vector(RW - 1 downto 0);
            rc_state_in  : in std_logic_vector(5 downto 0);
            rc_state_out : out std_logic_vector(5 downto 0)
        );
    end component;

    component xoodoo_register
        port (
            clk         : in std_logic;
            rst         : in std_logic;
            init        : in std_logic;

            state_in    : in  x_state_type;
            state_out   : out x_state_type;

            word_in         : in std_logic_vector(31 downto 0);
            word_index_in   : in integer range 0 to 11;
            word_enable_in  : in std_logic;
            start_in        : in std_logic;
            stop_in        : in std_logic;
            final           : out std_logic;
            running_in      : in std_logic;
            domain_i        : in std_logic_vector(31 downto 0);
            domain_enable_i : in std_logic;
            word_out        : out std_logic_vector(31 downto 0)
        );
    end component;

      ----------------------------------------------------------------------------
      -- Internal signal declarations
      ----------------------------------------------------------------------------

    -- round constants

    signal reg_in_s0, reg_in_s1, reg_in_s2, reg_in_s3 : x_state_type;
    signal reg_out_s0, reg_out_s1, reg_out_s2, reg_out_s3 : x_state_type;
    signal round_out_s0, round_out_s1, round_out_s2, round_out_s3 : std_logic_vector(383 downto 0);
    signal reg_in_s0_vec, reg_in_s1_vec, reg_in_s2_vec, reg_in_s3_vec : std_logic_vector(383 downto 0);
    signal reg_out_s0_vec, reg_out_s1_vec, reg_out_s2_vec, reg_out_s3_vec : std_logic_vector(383 downto 0);
    signal round_in, round_out : std_logic_vector(PDI_SHARES*384-1 downto 0);
      
    signal rc_state_in, rc_state_out : std_logic_vector(5 downto 0);
    signal done, done_short, running, clk_round : std_logic;
    signal word_in_s : std_logic_vector(PDI_SHARES*32-1 downto 0);
    signal word_index_in_s : integer range 0 to 11;
    signal word_enable_in_s : std_logic;
    signal init_reg_s : std_logic;
    signal domain_s : std_logic_vector(31 downto 0);
    signal domain_enable_s : std_logic;
    signal word_out_s : std_logic_vector(PDI_SHARES*32-1 downto 0);
    
    signal counter : integer range 0 to 8;
    signal counter_reset, counter_enable, register_enable, rc_reset, rc_enable, final_s0, final_s1, final_s2, final_s3 : std_logic;
    signal latency : unsigned(3 downto 0) := b"1100";
    
begin  -- rtl
    clk_round <= clk_i and (not done);

    rg00_map : xoodoo_register
        port map(
            clk             => clk_i,
            rst             => rst_i,
            init            => init_reg_s,
            state_in        => reg_in_s0,
            state_out       => reg_out_s0,
            word_in         => word_in_s(1*32-1 downto 0*32),
            word_index_in   => word_index_in_s,
            word_enable_in  => word_enable_in_s,
            start_in        => start_i,
            stop_in         => done,
            final           => final_s0,
            running_in      => running,
            domain_i        => domain_s,
            domain_enable_i => domain_enable_s,
            word_out        => word_out_s(1*32-1 downto 0*32)
        );

    rg01_map : xoodoo_register
        port map(
            clk             => clk_i,
            rst             => rst_i,
            init            => init_reg_s,
            state_in        => reg_in_s1,
            state_out       => reg_out_s1,
            word_in         => word_in_s(2*32-1 downto 1*32),
            word_index_in   => word_index_in_s,
            word_enable_in  => word_enable_in_s,
            start_in        => start_i,
            stop_in         => done,
            final           => final_s1,
            running_in      => running,
            domain_i        => (others => '0'),
            domain_enable_i => '0',
            word_out        => word_out_s(2*32-1 downto 1*32)
        );

    rg02_map : xoodoo_register
        port map(
            clk             => clk_i,
            rst             => rst_i,
            init            => init_reg_s,
            state_in        => reg_in_s2,
            state_out       => reg_out_s2,
            word_in         => word_in_s(3*32-1 downto 2*32),
            word_index_in   => word_index_in_s,
            word_enable_in  => word_enable_in_s,
            start_in        => start_i,
            stop_in         => done,
            final           => final_s2,
            running_in      => running,
            domain_i        => (others => '0'),
            domain_enable_i => '0',
            word_out        => word_out_s(3*32-1 downto 2*32)
        );
   
    rg03_map : xoodoo_register
        port map(
            clk             => clk_i,
            rst             => rst_i,
            init            => init_reg_s,
            state_in        => reg_in_s3,
            state_out       => reg_out_s3,
            word_in         => word_in_s(4*32-1 downto 3*32),
            word_index_in   => word_index_in_s,
            word_enable_in  => word_enable_in_s,
            start_in        => start_i,
            stop_in         => done,
            final           => final_s3,
            running_in      => running,
            domain_i        => (others => '0'),
            domain_enable_i => '0',
            word_out        => word_out_s(4*32-1 downto 3*32)
        );
        
    rd00_map : xoodoo_n_rounds
        generic map (roundPerCycle => roundPerCycle)
        port map(
            clk          => clk_round,
            state_in     => round_in,
            state_out    => round_out,
            rnd          => rdi,
            rc_state_in  => rc_state_in,
            rc_state_out => rc_state_out
        );

    xoodoo_delay: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if ((counter_reset = '1') or (counter >= latency)) then
                counter  <= 0;
            else
                if (((start_i='1') or (counter_enable = '1')) and rdi_valid = '1') then                
                    counter <= counter + 1;
                end if;    
            end if;
        end if;    
    end process;

    rc_delay: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if (rc_reset = '1') then
                rc_state_in <= "011011";
            else
                if (rc_enable = '1' and rdi_valid = '1') then
                    rc_state_in <= rc_state_out; 
                end if; 
            end if;
        end if;    
    end process;

    main: process(clk_i)
    begin 
        if rising_edge(clk_i) then
            done_short <= '0';

			if (rst_i = active_rst) then
                done <= '0';
                running <= '0';
                counter_enable <= '0';
                counter_reset <= '1';
                rc_reset <= '0';
                rc_enable <= '0';
            else
                if start_i='1' then
                    done <= '0';
                    running <= '0';
                    counter_enable <= '1';
                    counter_reset <= '0';
                    rc_reset <= '1';
                    rc_enable <= '0';
                elsif rc_state_out /= "010011" and counter = latency then
                    done <= '0';
                    running <= '1';
                    counter_enable <= '1';
                    counter_reset <= '0';
                    rc_reset <= '0';
                    rc_enable <= '1';

                elsif counter /= latency and counter_enable = '1' then
                    done <= '0';
                    running <= '0';
                    counter_enable <= '1';
                    counter_reset <= '0';  
                    rc_reset <= '0';
                    rc_enable <= '0'; 
                    
                elsif counter /= latency and counter_enable = '0' and done = '0' then
                    done <= '0';
                    running <= '0';
                    counter_enable <= '0';
                    counter_reset <= '0';
                    rc_reset <= '0';
                    rc_enable <= '0';
                end if;

                if rc_state_out = "010011" and counter = latency then
                    done <= '1';
					done_short <= '1';
                    running <= '0';
                    counter_enable <= '0';
                    counter_reset <= '0';
                    rc_reset <= '0';
                    rc_enable <= '0';
                end if;
            end if;
        end if;
    end process;

    rdi_ready <= counter_enable or start_i or word_enable_in_s or done_short;
    reg_out_s0_vec <= xstate_to_stdlogicvector(reg_out_s0);
    reg_out_s1_vec <= xstate_to_stdlogicvector(reg_out_s1);
    reg_out_s2_vec <= xstate_to_stdlogicvector(reg_out_s2);
    reg_out_s3_vec <= xstate_to_stdlogicvector(reg_out_s3);
    round_in <= reg_out_s0_vec & reg_out_s1_vec & reg_out_s2_vec & reg_out_s3_vec;
    round_out_s0 <= round_out(1*384-1 downto 0*384);
    round_out_s1 <= round_out(2*384-1 downto 1*384);
    round_out_s2 <= round_out(3*384-1 downto 2*384);
    round_out_s3 <= round_out(4*384-1 downto 3*384);
    reg_in_s0 <= stdlogicvector_to_xstate(round_out_s0);
    reg_in_s1 <= stdlogicvector_to_xstate(round_out_s1);
    reg_in_s2 <= stdlogicvector_to_xstate(round_out_s2);
    reg_in_s3 <= stdlogicvector_to_xstate(round_out_s3);
    
    reg_in_s0_vec <= xstate_to_stdlogicvector(reg_in_s0);
    reg_in_s1_vec <= xstate_to_stdlogicvector(reg_in_s1);
    reg_in_s2_vec <= xstate_to_stdlogicvector(reg_in_s2);
    reg_in_s3_vec <= xstate_to_stdlogicvector(reg_in_s3);
  
    state_valid_o <= done and final_s0;
    word_in_s <= word_in;
    word_index_in_s <= word_index_in;
    word_enable_in_s <= word_enable_in;
    domain_s <= domain_i;
    domain_enable_s <= domain_enable_i;
    init_reg_s <= init_reg;
    word_out <= word_out_s;

end rtl;