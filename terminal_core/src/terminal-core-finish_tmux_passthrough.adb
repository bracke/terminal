with Terminal.Core.Graphics_Runtime;

separate (Terminal.Core)
function Finish_Tmux_Passthrough
  (T                  : in out Terminal;
   Overflowed         : in out Boolean;
   Passthrough        : in out Core_Byte_Array_Access;
   Passthrough_Length : in out Natural;
   Passthrough_Budget : in out Natural) return Boolean
is
   Prefix : constant String := "tmux;";
   Decoded : Core_Byte_Array_Access := null;
   Decoded_Count : Natural := 0;
   I : Natural;

   procedure Reset_String_Parser is
   begin
      T.Parser.Ignored_String_Is_DCS := False;
      T.Parser.Ignored_String_Is_APC := False;
      T.Parser.State := Ground;
      Graphics_Runtime.Clear_Graphics_Transfer (T.Graphics);
   end Reset_String_Parser;
begin
   if not T.Parser.Ignored_String_Is_DCS
     or else T.Graphics.Transfer = null
     or else T.Graphics.Transfer_Length <= Prefix'Length
   then
      return False;
   end if;

   for J in Prefix'Range loop
      if T.Graphics.Transfer (J) /= Prefix (J) then
         return False;
      end if;
   end loop;

   if T.Parser.Tmux_Passthrough_Depth = Max_Tmux_Passthrough_Depth
   then
      Increment_Saturating (T.Diag.Parser_Overflow);
      Overflowed := True;
      Reset_String_Parser;
      return True;
   end if;

   --  Determine the exact decoded size before allocating.  All nested
   --  wrappers in one Feed share a single transaction-sized budget, so a
   --  chain of individually valid wrappers cannot multiply parser memory.
   I := Prefix'Length + 1;
   while I <= T.Graphics.Transfer_Length loop
      Decoded_Count := Decoded_Count + 1;
      if T.Graphics.Transfer (I) = ASCII.ESC
        and then I < T.Graphics.Transfer_Length
        and then T.Graphics.Transfer (I + 1) = ASCII.ESC
      then
         I := I + 2;
      else
         I := I + 1;
      end if;
   end loop;

   if Passthrough /= null or else Decoded_Count > Passthrough_Budget then
      Increment_Saturating (T.Diag.Parser_Overflow);
      Overflowed := True;
      Reset_String_Parser;
      return True;
   end if;

   if Decoded_Count > 0 then
      begin
         Decoded := new Core_Byte_Array (1 .. Decoded_Count);
      exception
         when Storage_Error =>
            Increment_Saturating (T.Diag.Parser_Overflow);
            Overflowed := True;
            Reset_String_Parser;
            return True;
      end;
   end if;

   Decoded_Count := 0;
   I := Prefix'Length + 1;
   while I <= T.Graphics.Transfer_Length loop
      if T.Graphics.Transfer (I) = ASCII.ESC
        and then I < T.Graphics.Transfer_Length
        and then T.Graphics.Transfer (I + 1) = ASCII.ESC
      then
         Decoded_Count := Decoded_Count + 1;
         Decoded.all (Decoded_Count) := 16#1B#;
         I := I + 2;
      else
         Decoded_Count := Decoded_Count + 1;
         Decoded.all (Decoded_Count) :=
           Common.Bytes.Byte
             (Standard.Character'Pos (T.Graphics.Transfer (I)));
         I := I + 1;
      end if;
   end loop;

   Reset_String_Parser;
   Increment_Saturating (T.Diag.Multiplexer_Passthrough);
   Passthrough_Budget := Passthrough_Budget - Decoded_Count;
   Passthrough_Length := Decoded_Count;
   Passthrough := Decoded;
   Decoded := null;

   return True;
exception
   when others =>
      if Decoded /= null then
         Storage.Release (Decoded);
      end if;
      raise;

end Finish_Tmux_Passthrough;
