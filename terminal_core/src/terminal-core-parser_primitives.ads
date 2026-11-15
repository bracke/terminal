private package Terminal.Core.Parser_Primitives is
   procedure Clear_CSI (T : in out Terminal);

   function Param
     (T       : Terminal;
      N       : Positive;
      Default : Natural) return Natural;

   function Param_Separator
     (T : Terminal;
      N : Positive) return Standard.Character;

   function In_String_Control (State : Parser_State) return Boolean;
end Terminal.Core.Parser_Primitives;
