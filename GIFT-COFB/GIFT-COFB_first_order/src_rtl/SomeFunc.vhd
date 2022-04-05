----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06/08/2019 01:16:22 AM
-- Design Name: 
-- Module Name: SomeFunc - package

----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Declarations
-----------------------------------------------------------------
package SomeFunc is

    function Pad        (I          : in std_logic_vector(127 downto 0);
                         bytes_Num  : in natural)                        return std_logic_vector;
    function Pad2       (I          : in std_logic_vector(127 downto 0);
                         bytes_Num  : in natural)                        return std_logic_vector;
    function Doubling   (L          : in std_logic_vector(63 downto 0))  return std_logic_vector;
    function Doubling2  (L          : in std_logic_vector(63 downto 0))  return std_logic_vector;
    function Tripling   (L          : in std_logic_vector(63 downto 0))  return std_logic_vector;
    function Tripling2  (L          : in std_logic_vector(63 downto 0))  return std_logic_vector;
    function G          (Y          : in std_logic_vector(127 downto 0)) return std_logic_vector;
    function rho1       (Y, M       : in std_logic_vector(127 downto 0)) return std_logic_vector;
    function Trunc      (output     : in std_logic_vector(31 downto 0);
                         bdi_size   : in std_logic_vector(2 downto 0))   return std_logic_vector;
    function myMux      (X          : in std_logic_vector(127 downto 0);
                         ctr_words  : in std_logic_vector(2 downto 0);
                         last_word  : in std_logic)                      return std_logic_vector;

end package SomeFunc;

-- Body
-----------------------------------------------------------------
package body SomeFunc is

    -- Padding --------------------------------------------------
    function Pad (I : in std_logic_vector(127 downto 0); bytes_Num : in natural) return std_logic_vector is
    variable temp  : std_logic_vector(127 downto 0);
    begin
        if (bytes_Num = 0) then
            temp(127)           := '1';
            temp(126 downto 0)  := (others => '0');
        elsif (bytes_Num < 16) then
            temp(127 downto (128 - 8*bytes_Num)) := I(127 downto (128 - 8*bytes_Num));
            temp(127 - 8*bytes_Num)              := '1';
            temp(126 - 8*bytes_Num downto 0)     := (others => '0');
        else
            temp := I;
        end if;
        return temp;
    end function;
 
    function Pad2 (I : in std_logic_vector(127 downto 0); bytes_Num : in natural) return std_logic_vector is
    variable temp  : std_logic_vector(127 downto 0);
    begin
        if (bytes_Num = 0) then
            temp(127)           := '0';
            temp(126 downto 0)  := (others => '0');
        elsif (bytes_Num < 16) then
            temp(127 downto (128 - 8*bytes_Num)) := I(127 downto (128 - 8*bytes_Num));
            temp(127 - 8*bytes_Num)              := '0';
            temp(126 - 8*bytes_Num downto 0)     := (others => '0');
        else
            temp := I;
        end if;
        return temp;
    end function;
        
    -- 2*b ------------------------------------------------------
    function Doubling (L : in std_logic_vector(63 downto 0)) return std_logic_vector is
    variable temp : std_logic_vector(63 downto 0);
    begin
        if (L(63) = '0') then
            temp := L(62 downto 0) & '0'; -- b<<1, if b(63)=0
        else
            temp := L(62 downto 4) & ( (L(3 downto 0) & '0') xor "11011"); -- (b<<1) xor 27, if b(63)=1
        end if;
        return temp;
    end function;

    -- 2*b ------------------------------------------------------
    function Doubling2 (L : in std_logic_vector(63 downto 0)) return std_logic_vector is
    variable temp : std_logic_vector(63 downto 0);
    begin
        if (L(63) = '0') then
            temp := L(62 downto 0) & '0'; -- b<<1, if b(63)=0
        else
            temp := L(62 downto 4) & ( (L(3 downto 0) & '0') xor "00000"); -- (b<<1) xor 27, if b(63)=1
        end if;
        return temp;
    end function;
    
    -- 3*b ------------------------------------------------------
    function Tripling (L : in std_logic_vector(63 downto 0)) return std_logic_vector is
    variable temp : std_logic_vector(63 downto 0);
    begin
        temp := Doubling (L) xor L;
        return temp;
    end function;

    -- 3*b ------------------------------------------------------
    function Tripling2 (L : in std_logic_vector(63 downto 0)) return std_logic_vector is
    variable temp : std_logic_vector(63 downto 0);
    begin
        temp := Doubling2 (L) xor L;
        return temp;
    end function;
    
    -- G --------------------------------------------------------
    function G (Y : in std_logic_vector(127 downto 0)) return std_logic_vector is
    variable temp : std_logic_vector(127 downto 0);
    begin
        temp := Y(63 downto 0) & Y(126 downto 64) & Y(127); -- G(Y) = (Y[2], Y[1] <<< 1);
        return temp;
    end function;
    
    -- rho1 -----------------------------------------------------
    function rho1 (Y, M : in std_logic_vector(127 downto 0)) return std_logic_vector is
    variable temp : std_logic_vector(127 downto 0);
    begin
        temp := G(Y) xor M; -- rho1(Y, M) = G(Y) xor M
        return temp;
    end function;
    
    -- Trunc ---------------------------------------------------
    function Trunc (output : in std_logic_vector(31 downto 0); bdi_size : in std_logic_vector(2 downto 0)) return std_logic_vector is
    variable temp : std_logic_vector(31 downto 0);
    begin
        if (bdi_size = 1) then
            temp := output(31 downto 24) & x"000000";
        elsif (bdi_size = 2) then
            temp := output(31 downto 16) & x"0000";
        elsif (bdi_size = 3) then
            temp := output(31 downto 8)  & x"00";
        elsif (bdi_size = 4) then
            temp := output;
        end if;
        return temp;
    end function;

    -- Multiplexer -----------------------------------------
    function myMux (X : in std_logic_vector(127 downto 0); ctr_words : in std_logic_vector(2 downto 0); last_word : in std_logic) return std_logic_vector is
    variable temp : std_logic_vector(127 downto 0);
    begin
        if (last_word = '1' and ctr_words = 0) then
            temp := X(31 downto 0) & X(127 downto 32);
        elsif (last_word = '1' and ctr_words = 1) then
            temp := X(63 downto 0) & X(127 downto 64);
        elsif (last_word = '1' and ctr_words = 2) then
            temp := X(95 downto 0) & X(127 downto 96);
        else
            temp := X;
        end if;
        return temp;
    end function;

end package body SomeFunc;
