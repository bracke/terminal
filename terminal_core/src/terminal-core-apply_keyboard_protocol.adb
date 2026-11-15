separate (Terminal.Core)
procedure Apply_Keyboard_Protocol (T : in out Terminal) is
   Stack : Keyboard_Stack renames
     T.Keyboard_Stacks (T.Current_Modes.Alternate_Screen);
   Flags : constant Natural := Natural'Min (Param (T, 1, 0), 31)
     mod (Supported_Keyboard_Flags + 1);
begin
   case T.Parser.CSI_Private is
      when '>' =>
         if Stack.Depth = Max_Keyboard_Stack_Depth then
            Stack.Flags (1 .. Max_Keyboard_Stack_Depth - 1) :=
              Stack.Flags (2 .. Max_Keyboard_Stack_Depth);
         else
            Stack.Depth := Stack.Depth + 1;
         end if;
         Stack.Flags (Stack.Depth) := Flags;
      when '<' =>
         Stack.Depth := Stack.Depth - Natural'Min
           (Stack.Depth, Natural'Max (1, Param (T, 1, 1)));
      when '=' =>
         if Stack.Depth = 0 then
            Stack.Depth := 1;
            Stack.Flags (1) := 0;
         end if;
         case Param (T, 2, 1) is
            when 1 => Stack.Flags (Stack.Depth) := Flags;
            when 2 =>
               Stack.Flags (Stack.Depth) :=
                 (if Flags mod 2 = 1
                    or else Stack.Flags (Stack.Depth) mod 2 = 1
                  then 1 else 0);
            when 3 =>
               Stack.Flags (Stack.Depth) :=
                 (if Flags mod 2 = 1 then 0
                  else Stack.Flags (Stack.Depth) mod 2);
            when others =>
               Increment_Saturating (T.Diag.Unsupported_Sequence);
         end case;
      when '?' =>
         Begin_Response (T);
         Append_Response_String (T, ASCII.ESC & "[?");
         Append_Response_Natural (T, T.Current_Modes.Keyboard_Flags);
         Append_Response_Char (T, 'u');
         End_Response (T);
      when others =>
         Increment_Saturating (T.Diag.Unsupported_Sequence);
   end case;
   Refresh_Keyboard_Flags (T);
end Apply_Keyboard_Protocol;
