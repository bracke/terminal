package Terminal.Core.Parser is
   Max_CSI_Params       : constant := 16;
   Max_CSI_Intermediate : constant := 4;
   Max_OSC_Length       : constant := 128 * 1024;
   Max_Escape_Length    : constant := 128 * 1024;
end Terminal.Core.Parser;
