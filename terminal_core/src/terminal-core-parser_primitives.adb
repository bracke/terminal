package body Terminal.Core.Parser_Primitives is
   procedure Clear_CSI (T : in out Terminal) is
   begin
      T.Parser.CSI_Private := ASCII.NUL;
      T.Parser.CSI_Params := (others => 0);
      T.Parser.CSI_Set := (others => False);
      T.Parser.CSI_Separators := (others => ASCII.NUL);
      T.Parser.CSI_Count := 0;
      T.Parser.CSI_Intermediates := (others => ASCII.NUL);
      T.Parser.CSI_Intermediate_Count := 0;
      T.Parser.CSI_Invalid := False;
   end Clear_CSI;

   function Param
     (T       : Terminal;
      N       : Positive;
      Default : Natural) return Natural is
     (if N <= T.Parser.CSI_Count and then T.Parser.CSI_Set (N)
      then T.Parser.CSI_Params (N)
      else Default);

   function Param_Separator
     (T : Terminal;
      N : Positive) return Standard.Character is
     (if N <= T.Parser.CSI_Count
      then T.Parser.CSI_Separators (N)
      else ASCII.NUL);

   function In_String_Control (State : Parser_State) return Boolean is
     (State = OSC
      or else State = OSC_Escape
      or else State = OSC_Overflow
      or else State = OSC_Overflow_Escape
      or else State = Ignored_String
      or else State = Ignored_String_Escape
      or else State = Ignored_String_Overflow
      or else State = Ignored_String_Overflow_Escape);
end Terminal.Core.Parser_Primitives;
