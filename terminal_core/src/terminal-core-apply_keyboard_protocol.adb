separate (Terminal.Core)
procedure Apply_Keyboard_Protocol (T : in out Terminal) is
   Stack : Keyboard_Stack renames
     T.Keyboard_Stacks (T.Current_Modes.Alternate_Screen);
   Flags : constant Natural :=
     Natural'Min (Param (T, 1, 0), Supported_Keyboard_Flags);
   type Flag_Array is array (Positive range <>) of Positive;
   Bits : constant Flag_Array := (1, 2, 4, 8, 16);

   function Added (Current, Requested : Natural) return Natural is
      Result : Natural := Current;
   begin
      for Bit of Bits loop
         if (Requested / Bit) mod 2 = 1
           and then (Result / Bit) mod 2 = 0
         then
            Result := Result + Bit;
         end if;
      end loop;
      return Result;
   end Added;

   function Removed (Current, Requested : Natural) return Natural is
      Result : Natural := Current;
   begin
      for Bit of Bits loop
         if (Requested / Bit) mod 2 = 1
           and then (Result / Bit) mod 2 = 1
         then
            Result := Result - Bit;
         end if;
      end loop;
      return Result;
   end Removed;
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
                 Added (Stack.Flags (Stack.Depth), Flags);
            when 3 =>
               Stack.Flags (Stack.Depth) :=
                 Removed (Stack.Flags (Stack.Depth), Flags);
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
