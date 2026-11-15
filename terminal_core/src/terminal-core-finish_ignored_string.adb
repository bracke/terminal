with Terminal.Core.Graphics_Runtime;
with Terminal.Common.Sixel;

separate (Terminal.Core)
procedure Finish_Ignored_String
  (T                  : in out Terminal;
   Overflowed         : in out Boolean;
   Recovered          : in out Boolean;
   Passthrough        : in out Core_Byte_Array_Access;
   Passthrough_Length : in out Natural;
   Passthrough_Budget : in out Natural)
is
   pragma Unreferenced (Recovered);

   function Is_Sixel_DCS return Boolean is
      I : Natural := 1;
   begin
      if not T.Parser.Ignored_String_Is_DCS
        or else T.Graphics.Transfer = null
        or else T.Graphics.Transfer_Length = 0
      then
         return False;
      end if;
      while I <= T.Graphics.Transfer_Length loop
         case T.Graphics.Transfer (I) is
            when '0' .. '9' | ';' | '?' =>
               I := I + 1;
            when 'q' =>
               return True;
            when others =>
               return False;
         end case;
      end loop;
      return False;
   end Is_Sixel_DCS;

   function Is_Kitty_Graphics_APC return Boolean is
   begin
      return T.Parser.Ignored_String_Is_APC
        and then T.Graphics.Transfer_Length >= 1
        and then T.Graphics.Transfer /= null
        and then T.Graphics.Transfer (1) = 'G';
   end Is_Kitty_Graphics_APC;
begin
   if Finish_Tmux_Passthrough
        (T, Overflowed, Passthrough, Passthrough_Length, Passthrough_Budget)
   then
      Graphics_Runtime.Clear_Graphics_Transfer (T.Graphics);
      return;
   end if;

   if T.Graphics.Kitty_Chunk_Active and then not Is_Kitty_Graphics_APC then
      Reject_Kitty_Chunk_Interleave (T);
   end if;

   if Is_Sixel_DCS then
      Handle_Sixel_DCS
        (T,
         Common.Sixel.Analyze
           (T.Graphics.Transfer (1 .. T.Graphics.Transfer_Length)));
   elsif Is_Kitty_Graphics_APC then
      Process_Kitty_Graphics_APC
        (T, T.Graphics.Transfer (1 .. T.Graphics.Transfer_Length));
   elsif T.Parser.Ignored_String_Is_DCS
     and then T.Parser.Ignored_String_Count >= 2
     and then T.Parser.Ignored_String_Data (1) = '$'
     and then T.Parser.Ignored_String_Data (2) = 'q'
   then
      Handle_DECRQSS (T);
   end if;

   T.Parser.Ignored_String_Is_DCS := False;
   T.Parser.Ignored_String_Is_APC := False;
   Graphics_Runtime.Clear_Graphics_Transfer (T.Graphics);
   T.Parser.State := Ground;
end Finish_Ignored_String;
