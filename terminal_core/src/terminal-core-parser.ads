with Terminal.Core.Parser_Limits;

package Terminal.Core.Parser is
   Max_CSI_Params       : constant := 16;
   Max_CSI_Intermediate : constant := 4;
   --  Bound numeric parameters before converting them into work counts.  A
   --  command that exceeds this limit is reported as parser overflow instead
   --  of being silently reinterpreted according to the current screen size.
   Max_CSI_Parameter    : constant := 65_535;
   Max_OSC_Length       : constant := Parser_Limits.Max_OSC_Length;
   Max_Escape_Length    : constant := Parser_Limits.Max_Escape_Length;
end Terminal.Core.Parser;
