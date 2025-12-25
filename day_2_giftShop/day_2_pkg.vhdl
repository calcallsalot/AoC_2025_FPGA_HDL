library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package productID_pkg is 

	function umax(a, b : unsigned) return unsigned;
	function umin(a, b : unsigned) return unsigned;
	
	function ceil_div(a, b : unsigned) return unsigned;
end package;

package body productID_pkg is 
	function umax(a, b : unsigned) return unsigned is 
	begin 
		if a > b then return a; else return b; end if;
	end;
	
	function umin(a, b : unsigned) return unsigned is 
	begin
		if a > b then return b; else return a; end if;
	end;
	
	function ceil_div(a, b : unsigned) return unsigned is 
		variable tmp : unsigned(a'length downto 0);
	begin 
	-- tmp = a + (b-1) (one extra bit for carry)
    tmp := ('0' & a) + ('0' & (b - 1));
    return resize(tmp / b, a'length);
  end;
end package body;