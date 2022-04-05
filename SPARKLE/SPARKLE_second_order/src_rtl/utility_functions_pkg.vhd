library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

package utility_functions is 

    -- Schwaemm/Esch Constants
    constant KEY_SIZE : integer := 4;
    constant BLK_SIZE : integer := 8;
    constant TAG_SIZE2 : integer := 4;
    constant HASH_SIZE : integer := 8;
    constant HASH_BLK_SIZE : integer := 4;
    
    constant STEPS_SMALL : integer := 7;
    constant STEPS_BIG : integer := 11;
    
    constant PAD_AD_CONST : std_logic_vector(31 downto 0) := x"04000000";
    constant NO_PAD_AD_CONST : std_logic_vector(31 downto 0) := x"05000000";
    constant PAD_PT_CONST : std_logic_vector(31 downto 0) := x"06000000";
    constant NO_PAD_PT_CONST : std_logic_vector(31 downto 0) := x"07000000";
    constant PAD_HASH_CONST : std_logic_vector(31 downto 0) := x"01000000";
    constant NO_PAD_HASH_CONST : std_logic_vector(31 downto 0) := x"02000000";

    constant VALID_WORD : std_logic_vector(3 downto 0) := b"1111";
    constant ZERO_W : std_logic_vector(31 downto 0) := x"00000000";
        
    function rot_y_word (inputData : in std_logic_vector(31 downto 0); rc : in integer)
        return std_logic_vector;
        
    function rot_x_word (inputData : in std_logic_vector(31 downto 0); rc : in integer)
        return std_logic_vector;
    
    function littleEndianWord (inputData : in std_logic_vector(31 downto 0))
        return std_logic_vector;
        
    function padWordLoc (currentWord : in std_logic_vector(31 downto 0); padLoc : in std_logic_vector(3 downto 0))
        return std_logic_vector;

    function padWordLoc2 (currentWord : in std_logic_vector(31 downto 0); padLoc : in std_logic_vector(3 downto 0))
        return std_logic_vector;
    
    function padWordValid (currentWord : in std_logic_vector(31 downto 0); bytesValid : in std_logic_vector(3 downto 0))
        return std_logic_vector;

    function padWordValid2 (currentWord : in std_logic_vector(31 downto 0); bytesValid : in std_logic_vector(3 downto 0))
        return std_logic_vector;
    
    function zeroFillPt (input : in std_logic_vector(255 downto 0); lw_index : in integer; valid_bytes : in std_logic_vector(3 downto 0))
        return std_logic_vector;

    function zeroFillPt2 (input : in std_logic_vector(255 downto 0); lw_index : in integer; valid_bytes : in std_logic_vector(3 downto 0))
        return std_logic_vector;
    
end package utility_functions;

package body utility_functions is 
    
    -- Function for cyclic rotate word y right
    function rot_y_word ( inputData : in std_logic_vector(31 downto 0); rc : in integer)
        return std_logic_vector is variable rotData : std_logic_vector(31 downto 0);
    begin 
        if (rc = 0) then
            rotData:= inputData(30 downto 0) & inputData(31);
        elsif (rc = 1) then
            rotData:= inputData(16 downto 0) & inputData(31 downto 17);
        elsif (rc = 2) then
            rotData:= inputData;
        else
            rotData:= inputData(23 downto 0) & inputData(31 downto 24);
        end if;
        return rotData;
    end rot_y_word;
    
        -- Function for cyclic rotate word y right
    function rot_x_word ( inputData : in std_logic_vector(31 downto 0); rc : in integer)
        return std_logic_vector is variable rotData : std_logic_vector(31 downto 0);
    begin 
        if (rc = 0) then
            rotData:= inputData(23 downto 0) & inputData(31 downto 24);
        elsif (rc = 1) then
            rotData:= inputData(16 downto 0) & inputData(31 downto 17);
        elsif (rc = 2) then
            rotData:= inputData(30 downto 0) & inputData(31);
        else
            rotData:= inputData(15 downto 0) & inputData(31 downto 16);
        end if;
        return rotData;
    end rot_x_word;
    
    -- Function to handle little endian mapping for single word
    function littleEndianWord ( inputData : in std_logic_vector(31 downto 0))
        return std_logic_vector is variable alignedData : std_logic_vector(31 downto 0);
    begin 

        alignedData(31 downto  24) := inputData(7 downto 0);
        alignedData(23 downto  16) := inputData(15 downto 8);
        alignedData(15 downto  8) := inputData(23 downto 16);
        alignedData(7 downto  0) := inputData(31 downto 24);
         
        return alignedData;
    end littleEndianWord; 
    
    -- Function to pad single word based on pad location bytes
    function padWordLoc ( currentWord : in std_logic_vector(31 downto 0); padLoc : in std_logic_vector(3 downto 0))
        return std_logic_vector is variable paddedWord : std_logic_vector(31 downto 0);
    begin 

        if (padLoc = b"1000") then
            paddedWord := x"80000000";
        elsif (padLoc = b"0100") then
            paddedWord := currentWord(31 downto 24) &  x"800000";
        elsif (padLoc = b"0010") then
            paddedWord := currentWord(31 downto 16) & x"8000";
        elsif (padLoc = b"0001") then
            paddedWord := currentWord(31 downto 8) & x"80";
        else
            paddedWord := currentWord;
        end if;
         
    return paddedWord;
    end padWordLoc;

    -- Function to pad single word based on pad location bytes
    function padWordLoc2 ( currentWord : in std_logic_vector(31 downto 0); padLoc : in std_logic_vector(3 downto 0))
        return std_logic_vector is variable paddedWord : std_logic_vector(31 downto 0);
    begin 

        if (padLoc = b"1000") then
            paddedWord := x"00000000";
        elsif (padLoc = b"0100") then
            paddedWord := currentWord(31 downto 24) &  x"000000";
        elsif (padLoc = b"0010") then
            paddedWord := currentWord(31 downto 16) & x"0000";
        elsif (padLoc = b"0001") then
            paddedWord := currentWord(31 downto 8) & x"00";
        else
            paddedWord := currentWord;
        end if;
         
    return paddedWord;
    end padWordLoc2;
    
    -- Function to pad single word based on valid bytes
    function padWordValid ( currentWord : in std_logic_vector(31 downto 0); bytesValid : in std_logic_vector(3 downto 0))
        return std_logic_vector is variable paddedWord : std_logic_vector(31 downto 0);
    begin 

        if (bytesValid = b"1000") then
            paddedWord :=  x"000080" & currentWord(7 downto 0);
        elsif (bytesValid = b"1100") then
            paddedWord := x"0080" & currentWord(15 downto 0);
        elsif (bytesValid = b"1110") then
            paddedWord := x"80" & currentWord(23 downto 0);
        else
            paddedWord := currentWord;
        end if;
         
    return paddedWord;
    end padWordValid;

    -- Function to pad single word based on valid bytes
    function padWordValid2 ( currentWord : in std_logic_vector(31 downto 0); bytesValid : in std_logic_vector(3 downto 0))
        return std_logic_vector is variable paddedWord : std_logic_vector(31 downto 0);
    begin 

        if (bytesValid = b"1000") then
            paddedWord :=  x"000000" & currentWord(7 downto 0);
        elsif (bytesValid = b"1100") then
            paddedWord := x"0000" & currentWord(15 downto 0);
        elsif (bytesValid = b"1110") then
            paddedWord := x"00" & currentWord(23 downto 0);
        else
            paddedWord := currentWord;
        end if;
         
    return paddedWord;
    end padWordValid2;
    
    -- Function to pad plaintext and zero fill
    function zeroFillPt (input : in std_logic_vector(255 downto 0); lw_index : in integer; valid_bytes : in std_logic_vector(3 downto 0))
        return std_logic_vector is variable zeroFilled : std_logic_vector(255 downto 0);
    begin
    
        if (lw_index = 0) then
            if (valid_bytes = b"1111") then
                zeroFilled := input(255 downto 224) & x"00000080" & x"00000000" & x"00000000" & x"00000000" & x"00000000" & x"00000000" & x"00000000";
            else
                zeroFilled := padWordValid(input(255 downto 224), valid_bytes) & x"00000000" & x"00000000" & x"00000000" &
                                x"00000000" & x"00000000" & x"00000000" & x"00000000";
            end if;      
        elsif (lw_index = 1) then
            if (valid_bytes = b"1111") then
                zeroFilled := input(255 downto 192) & x"00000080" & x"00000000" & x"00000000" & x"00000000" & x"00000000" & x"00000000";
            else
                zeroFilled := input(255 downto 224) & padWordValid(input(223 downto 192), valid_bytes) & x"00000000" & x"00000000" &
                                x"00000000" & x"00000000" & x"00000000" & x"00000000";
            end if;
        elsif (lw_index = 2) then
            if (valid_bytes = b"1111") then
                zeroFilled := input(255 downto 160) & x"00000080" & x"00000000" & x"00000000" & x"00000000" & x"00000000";
            else 
                zeroFilled := input(255 downto 192) & padWordValid(input(191 downto 160), valid_bytes) & x"00000000" &
                                x"00000000" & x"00000000" & x"00000000" & x"00000000";
            end if;
        elsif (lw_index = 3) then
            if (valid_bytes = b"1111") then
                zeroFilled := input(255 downto 128) & x"00000080" & x"00000000" & x"00000000" & x"00000000";
            else
                zeroFilled := input(255 downto 160) & padWordValid(input(159 downto 128), valid_bytes) &
                                x"00000000" & x"00000000" & x"00000000" & x"00000000";
            end if;
        elsif (lw_index = 4) then
            if (valid_bytes = b"1111") then
                zeroFilled := input(255 downto 96) & x"00000080" & x"00000000" & x"00000000";
            else
                zeroFilled := input(255 downto 128) & padWordValid(input(127 downto 96), valid_bytes)
                                & x"00000000" & x"00000000" & x"00000000";
            end if;
        elsif (lw_index = 5) then
            if (valid_bytes = b"1111") then
                zeroFilled := input(255 downto 64) & x"00000080" & x"00000000";
            else
                zeroFilled := input(255 downto 96) & padWordValid(input(95 downto 64), valid_bytes) & x"00000000" & x"00000000";
            end if;
        elsif (lw_index = 6) then
            if(valid_bytes = b"1111") then
                zeroFilled := input(255 downto 32) & x"00000080";
            else
            zeroFilled := input(255 downto 64) & padWordValid(input(63 downto 32), valid_bytes) & x"00000000";
            end if;
        elsif (lw_index = 7) then
            zeroFilled := input(255 downto 32) & padWordValid(input(31 downto 0), valid_bytes);          
        end if;
         
    return zeroFilled;
    end zeroFillPt;

    function zeroFillPt2 (input : in std_logic_vector(255 downto 0); lw_index : in integer; valid_bytes : in std_logic_vector(3 downto 0))
        return std_logic_vector is variable zeroFilled : std_logic_vector(255 downto 0);
    begin
    
        if (lw_index = 0) then
            if (valid_bytes = b"1111") then
                zeroFilled := input(255 downto 224) & x"00000000" & x"00000000" & x"00000000" & x"00000000" & x"00000000" & x"00000000" & x"00000000";
            else
                zeroFilled := padWordValid2(input(255 downto 224), valid_bytes) & x"00000000" & x"00000000" & x"00000000" &
                                x"00000000" & x"00000000" & x"00000000" & x"00000000";
            end if;      
        elsif (lw_index = 1) then
            if (valid_bytes = b"1111") then
                zeroFilled := input(255 downto 192) & x"00000000" & x"00000000" & x"00000000" & x"00000000" & x"00000000" & x"00000000";
            else
                zeroFilled := input(255 downto 224) & padWordValid2(input(223 downto 192), valid_bytes) & x"00000000" & x"00000000" &
                                x"00000000" & x"00000000" & x"00000000" & x"00000000";
            end if;
        elsif (lw_index = 2) then
            if (valid_bytes = b"1111") then
                zeroFilled := input(255 downto 160) & x"00000000" & x"00000000" & x"00000000" & x"00000000" & x"00000000";
            else 
                zeroFilled := input(255 downto 192) & padWordValid2(input(191 downto 160), valid_bytes) & x"00000000" &
                                x"00000000" & x"00000000" & x"00000000" & x"00000000";
            end if;
        elsif (lw_index = 3) then
            if (valid_bytes = b"1111") then
                zeroFilled := input(255 downto 128) & x"00000000" & x"00000000" & x"00000000" & x"00000000";
            else
                zeroFilled := input(255 downto 160) & padWordValid2(input(159 downto 128), valid_bytes) &
                                x"00000000" & x"00000000" & x"00000000" & x"00000000";
            end if;
        elsif (lw_index = 4) then
            if (valid_bytes = b"1111") then
                zeroFilled := input(255 downto 96) & x"00000000" & x"00000000" & x"00000000";
            else
                zeroFilled := input(255 downto 128) & padWordValid2(input(127 downto 96), valid_bytes)
                                & x"00000000" & x"00000000" & x"00000000";
            end if;
        elsif (lw_index = 5) then
            if (valid_bytes = b"1111") then
                zeroFilled := input(255 downto 64) & x"00000000" & x"00000000";
            else
                zeroFilled := input(255 downto 96) & padWordValid2(input(95 downto 64), valid_bytes) & x"00000000" & x"00000000";
            end if;
        elsif (lw_index = 6) then
            if(valid_bytes = b"1111") then
                zeroFilled := input(255 downto 32) & x"00000000";
            else
            zeroFilled := input(255 downto 64) & padWordValid2(input(63 downto 32), valid_bytes) & x"00000000";
            end if;
        elsif (lw_index = 7) then
            zeroFilled := input(255 downto 32) & padWordValid2(input(31 downto 0), valid_bytes);          
        end if;
         
    return zeroFilled;
    end zeroFillPt2;
    
end package body utility_functions;
