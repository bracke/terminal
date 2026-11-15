with Ada.Unchecked_Deallocation;
with Terminal.Common.Counters;
with Terminal.Core.Graphics_Runtime;
with Terminal.Core.Parser_Limits;

package body Terminal.Core.Parser_Buffers is
   procedure Free_String is new Ada.Unchecked_Deallocation
     (String, String_Access);

   procedure Increment_Saturating (Value : in out Natural) renames
     Standard.Terminal.Common.Counters.Increment_Saturating;

   function OSC_Slice
     (T     : Terminal;
      First : Positive;
      Last  : Natural) return String
   is
      Result : String (1 .. Last - First + 1);
   begin
      for I in Result'Range loop
         Result (I) := T.Parser.OSC_Data (First + I - 1);
      end loop;
      return Result;
   end OSC_Slice;

   function Ignored_String_Slice
     (T     : Terminal;
      First : Positive;
      Last  : Natural) return String
   is
      Result : String (1 .. Last - First + 1);
   begin
      for I in Result'Range loop
         Result (I) := T.Parser.Ignored_String_Data (First + I - 1);
      end loop;
      return Result;
   end Ignored_String_Slice;

   procedure Append_OSC_Byte
     (T          : in out Terminal;
      Ch         : Standard.Character;
      Overflowed : in out Boolean)
   is
      New_Capacity : Natural;
      Replacement  : String_Access := null;
   begin
      if T.Parser.OSC_Count >= Parser_Limits.Max_OSC_Length then
         Increment_Saturating (T.Diag.Parser_Overflow);
         Overflowed := True;
         T.Parser.State := OSC_Overflow;
      else
         if T.Parser.OSC_Count = T.Parser.OSC_Capacity then
            if T.Parser.OSC_Capacity = 0 then
               New_Capacity := Natural'Min
                 (4 * 1024, Parser_Limits.Max_OSC_Length);
            elsif T.Parser.OSC_Capacity > Parser_Limits.Max_OSC_Length / 2
            then
               New_Capacity := Parser_Limits.Max_OSC_Length;
            else
               New_Capacity := T.Parser.OSC_Capacity * 2;
            end if;
            Replacement := new String (1 .. New_Capacity);
            if T.Parser.OSC_Count > 0 then
               Replacement (1 .. T.Parser.OSC_Count) :=
                 T.Parser.OSC_Data (1 .. T.Parser.OSC_Count);
            end if;
            if T.Parser.OSC_Data /= null then
               Free_String (T.Parser.OSC_Data);
            end if;
            T.Parser.OSC_Data := Replacement;
            T.Parser.OSC_Capacity := New_Capacity;
            Replacement := null;
         end if;
         T.Parser.OSC_Count := T.Parser.OSC_Count + 1;
         T.Parser.OSC_Data (T.Parser.OSC_Count) := Ch;
      end if;
   exception
      when Storage_Error =>
         if Replacement /= null then
            Free_String (Replacement);
         end if;
         Increment_Saturating (T.Diag.Parser_Overflow);
         Overflowed := True;
         T.Parser.State := OSC_Overflow;
   end Append_OSC_Byte;

   procedure Append_Ignored_String_Byte
     (T          : in out Terminal;
      Ch         : Standard.Character;
      Overflowed : in out Boolean)
   is
      Is_Full_Graphics_Capture : constant Boolean :=
        (T.Parser.Ignored_String_Is_DCS
         and then
           (T.Graphics.Transfer_Length > 0
            or else
              (T.Parser.Ignored_String_Count = 0
               and then Ch in '0' .. '9' | ';' | '?' | 'q' | 't')))
        or else
          (T.Parser.Ignored_String_Is_APC
           and then
             (T.Graphics.Transfer_Length > 0
              or else (T.Parser.Ignored_String_Count = 0 and then Ch = 'G')));

      procedure Append_Graphics_Byte is
      begin
         if not Graphics_Runtime.Append_Transfer_Character (T.Graphics, Ch)
         then
            if T.Graphics.Kitty_Chunk_Active
              and then T.Parser.Ignored_String_Is_APC
            then
               Graphics_Runtime.Advance_Graphics_Transaction (T.Graphics);
               Graphics_Runtime.Clear_Kitty_Chunk (T.Graphics);
            end if;
            Increment_Saturating (T.Diag.Parser_Overflow);
            Overflowed := True;
            Graphics_Runtime.Clear_Graphics_Transfer (T.Graphics);
            T.Parser.State := Ignored_String_Overflow;
         end if;
      end Append_Graphics_Byte;
   begin
      if Is_Full_Graphics_Capture then
         Append_Graphics_Byte;
         if T.Parser.State = Ignored_String_Overflow then
            return;
         end if;
         if T.Parser.Ignored_String_Count < Parser_Limits.Max_Escape_Length
         then
            T.Parser.Ignored_String_Count := T.Parser.Ignored_String_Count + 1;
            T.Parser.Ignored_String_Data (T.Parser.Ignored_String_Count) := Ch;
         end if;
      elsif T.Parser.Ignored_String_Count >= Parser_Limits.Max_Escape_Length
      then
         Increment_Saturating (T.Diag.Parser_Overflow);
         Overflowed := True;
         T.Parser.State := Ignored_String_Overflow;
      else
         T.Parser.Ignored_String_Count := T.Parser.Ignored_String_Count + 1;
         T.Parser.Ignored_String_Data (T.Parser.Ignored_String_Count) := Ch;
      end if;
   end Append_Ignored_String_Byte;

   procedure Start_Ignored_String
     (T      : in out Terminal;
      Is_DCS : Boolean;
      Is_APC : Boolean := False) is
   begin
      Graphics_Runtime.Clear_Graphics_Transfer (T.Graphics);
      T.Parser.Ignored_String_Data := (others => ASCII.NUL);
      T.Parser.Ignored_String_Count := 0;
      T.Parser.Ignored_String_Is_DCS := Is_DCS;
      T.Parser.Ignored_String_Is_APC := Is_APC;
      T.Parser.State := Ignored_String;
   end Start_Ignored_String;
end Terminal.Core.Parser_Buffers;
