with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;

package body Unicode_Generator_Support is
   use Ada.Strings;
   use Ada.Strings.Fixed;
   use Ada.Text_IO;

   function Hex_Value (Text : String) return Natural is
      Result : Natural := 0;
      Digit  : Natural;
   begin
      if Text'Length = 0 then
         raise Constraint_Error with "empty hexadecimal value";
      end if;
      for C of Text loop
         Digit :=
           (case C is
               when '0' .. '9' => Character'Pos (C) - Character'Pos ('0'),
               when 'A' .. 'F' => Character'Pos (C) - Character'Pos ('A') + 10,
               when 'a' .. 'f' => Character'Pos (C) - Character'Pos ('a') + 10,
               when others =>
                  raise Constraint_Error with "invalid hexadecimal value");
         Result := Result * 16 + Digit;
      end loop;
      return Result;
   end Hex_Value;

   function Hex_Image (Value : Natural) return String is
      Hex_Digits : constant String := "0123456789ABCDEF";
      Buffer     : String (1 .. 6);
      First      : Positive := Buffer'Last;
      Rest       : Natural := Value;
   begin
      if Value > Max_Code_Point then
         raise Constraint_Error with "code point exceeds Unicode range";
      end if;
      loop
         Buffer (First) := Hex_Digits (Rest mod 16 + 1);
         Rest := Rest / 16;
         exit when Rest = 0;
         First := First - 1;
      end loop;
      return Buffer (First .. Buffer'Last);
   end Hex_Image;

   procedure Mark
     (Flags : Flag_Array_Access;
      First : Natural;
      Last  : Natural) is
   begin
      if Flags = null
        or else First > Last
        or else First < Flags'First
        or else Last > Flags'Last
        or else Last > Max_Code_Point
      then
         raise Constraint_Error with "invalid Unicode range";
      end if;
      Flags (First .. Last) := (others => True);
   end Mark;

   procedure Parse_Property_Line
     (Raw      : String;
      First_CP : out Natural;
      Last_CP  : out Natural;
      Property : out String;
      Valid    : out Boolean)
   is
      Comment   : constant Natural := Index (Raw, "#");
      Last_Char : constant Natural :=
        (if Comment = 0 then Raw'Last else Comment - 1);
   begin
      First_CP := 0;
      Last_CP := 0;
      Property := (others => ' ');
      Valid := False;
      if Last_Char < Raw'First then
         return;
      end if;
      declare
         Line : constant String := Trim (Raw (Raw'First .. Last_Char), Both);
         Semi : constant Natural := Index (Line, ";");
      begin
         if Line'Length = 0 then
            return;
         elsif Semi = 0 then
            raise Constraint_Error with "missing Unicode property separator";
         end if;
         declare
            Range_Text : constant String :=
              Trim (Line (Line'First .. Semi - 1), Both);
            Value : constant String :=
              Trim (Line (Semi + 1 .. Line'Last), Both);
            Dots : constant Natural := Index (Range_Text, "..");
         begin
            if Range_Text'Length = 0 then
               raise Constraint_Error with "empty Unicode property range";
            elsif Value'Length = 0 then
               raise Constraint_Error with "empty Unicode property name";
            elsif Value'Length > Property'Length then
               raise Constraint_Error with "Unicode property name is too long";
            elsif Index (Value, ";") /= 0 then
               raise Constraint_Error with "too many Unicode property fields";
            end if;
            if Dots /= 0
              and then
                (Dots = Range_Text'First
                 or else Dots + 1 = Range_Text'Last
                 or else Index (Range_Text (Dots + 2 .. Range_Text'Last), "..") /= 0)
            then
               raise Constraint_Error with "malformed Unicode property range";
            end if;
            First_CP := Hex_Value
              (Range_Text
                 (Range_Text'First ..
                  (if Dots = 0 then Range_Text'Last else Dots - 1)));
            Last_CP :=
              (if Dots = 0 then First_CP
               else Hex_Value (Range_Text (Dots + 2 .. Range_Text'Last)));
            if Last_CP > Max_Code_Point or else First_CP > Last_CP then
               raise Constraint_Error with "invalid Unicode property range";
            end if;
            Property (Property'First .. Property'First + Value'Length - 1) :=
              Value;
            Valid := True;
         end;
      end;
   end Parse_Property_Line;

   procedure Parse_Variation_Line
     (Raw         : String;
      Base_CP     : out Natural;
      Selector_CP : out Natural;
      Valid       : out Boolean)
   is
      Comment   : constant Natural := Index (Raw, "#");
      Last_Char : constant Natural :=
        (if Comment = 0 then Raw'Last else Comment - 1);
   begin
      Base_CP := 0;
      Selector_CP := 0;
      Valid := False;
      if Last_Char < Raw'First then
         return;
      end if;
      declare
         Line : constant String := Trim (Raw (Raw'First .. Last_Char), Both);
         Semi : constant Natural := Index (Line, ";");
      begin
         if Line'Length = 0 then
            return;
         elsif Semi = 0 then
            raise Constraint_Error with "missing Unicode variation separator";
         end if;
         declare
            Sequence : constant String :=
              Trim (Line (Line'First .. Semi - 1), Both);
            Property : constant String :=
              Trim (Line (Semi + 1 .. Line'Last), Both);
            Space : constant Natural := Index (Sequence, " ");
         begin
            if Sequence'Length = 0 then
               raise Constraint_Error with "empty Unicode variation sequence";
            elsif Property'Length = 0 then
               raise Constraint_Error with "empty Unicode variation property";
            elsif Space = 0 then
               raise Constraint_Error with
                 "Unicode variation sequence has no selector";
            end if;
            declare
               Base_Text : constant String :=
                 Trim (Sequence (Sequence'First .. Space - 1), Both);
               Selector_Text : constant String :=
                 Trim (Sequence (Space + 1 .. Sequence'Last), Both);
            begin
               if Base_Text'Length = 0 or else Selector_Text'Length = 0 then
                  raise Constraint_Error with
                    "incomplete Unicode variation sequence";
               elsif Index (Selector_Text, " ") /= 0 then
                  raise Constraint_Error with
                    "too many Unicode variation code points";
               end if;
               Base_CP := Hex_Value (Base_Text);
               Selector_CP := Hex_Value (Selector_Text);
               if Base_CP > Max_Code_Point or else Selector_CP > Max_Code_Point
               then
                  raise Constraint_Error with
                    "Unicode variation code point exceeds Unicode range";
               elsif Selector_CP not in 16#FE0E# | 16#FE0F# then
                  raise Constraint_Error with
                    "unsupported Unicode variation selector";
               elsif Property not in "text style;" | "emoji style;" then
                  raise Constraint_Error with
                    "unsupported Unicode variation property";
               elsif (Selector_CP = 16#FE0E# and then Property /= "text style;")
                 or else
                   (Selector_CP = 16#FE0F# and then Property /= "emoji style;")
               then
                  raise Constraint_Error with
                    "Unicode variation selector and property disagree";
               end if;
               Valid := True;
            end;
         end;
      end;
   end Parse_Variation_Line;

   procedure Write_Intervals
     (Output : File_Type;
      Name   : String;
      Flags  : Flag_Array_Access)
   is
      First    : Natural;
      Last     : Natural;
      Is_First : Boolean := True;
   begin
      if Flags = null then
         raise Constraint_Error with Name & " interval flags are missing";
      elsif (for all Flag of Flags.all => not Flag) then
         raise Constraint_Error with Name & " contains no intervals";
      end if;

      First := Flags'First;
      Put_Line (Output, "   " & Name & " : constant Interval_Array :=");
      Put_Line (Output, "     (");
      while First <= Flags'Last loop
         while First <= Flags'Last and then not Flags (First) loop
            First := First + 1;
         end loop;
         exit when First > Flags'Last;
         Last := First;
         while Last < Flags'Last and then Flags (Last + 1) loop
            Last := Last + 1;
         end loop;
         if not Is_First then
            Put_Line (Output, ",");
         end if;
         Put
           (Output,
            "      (16#" & Hex_Image (First) & "#, 16#" &
            Hex_Image (Last) & "#)");
         Is_First := False;
         exit when Last = Flags'Last;
         First := Last + 1;
      end loop;
      Put_Line (Output, ");");
   end Write_Intervals;

   function Same_Text_Files
     (Left_Path  : String;
      Right_Path : String) return Boolean
   is
      Left  : File_Type;
      Right : File_Type;

      procedure Close_Files is
      begin
         if Is_Open (Left) then
            Close (Left);
         end if;
         if Is_Open (Right) then
            Close (Right);
         end if;
      end Close_Files;
   begin
      Open (Left, In_File, Left_Path);
      Open (Right, In_File, Right_Path);
      while not End_Of_File (Left) and then not End_Of_File (Right) loop
         if Get_Line (Left) /= Get_Line (Right) then
            Close_Files;
            return False;
         end if;
      end loop;
      declare
         Equal : constant Boolean :=
           End_Of_File (Left) and then End_Of_File (Right);
      begin
         Close_Files;
         return Equal;
      end;
   exception
      when others =>
         begin
            Close_Files;
         exception
            when others =>
               null;
         end;
         raise;
   end Same_Text_Files;
end Unicode_Generator_Support;
