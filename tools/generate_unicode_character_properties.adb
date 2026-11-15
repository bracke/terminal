with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with GNAT.OS_Lib;
with Unicode_Generator_Support;

procedure Generate_Unicode_Character_Properties is
   use Ada.Strings;
   use Ada.Strings.Fixed;
   use Ada.Text_IO;

   package Support renames Unicode_Generator_Support;
   Max_Code_Point : constant Natural := Support.Max_Code_Point;
   subtype Flag_Array is Support.Flag_Array;
   subtype Flag_Array_Access is Support.Flag_Array_Access;

   Wide       : constant Flag_Array_Access :=
     new Flag_Array'(0 .. Max_Code_Point => False);
   Emoji_Base : constant Flag_Array_Access :=
     new Flag_Array'(0 .. Max_Code_Point => False);
   Zero_Width : constant Flag_Array_Access :=
     new Flag_Array'(0 .. Max_Code_Point => False);
   Attachment : constant Flag_Array_Access :=
     new Flag_Array'(0 .. Max_Code_Point => False);
   Saw_Unicode_15_1 : Boolean := False;
   Saw_EAW_15_1     : Boolean := False;
   Saw_Emoji_15_1   : Boolean := False;

   function Hex_Value (Text : String) return Natural
     renames Support.Hex_Value;

   procedure Mark
     (Flags : Flag_Array_Access;
      First : Natural;
      Last  : Natural)
     renames Support.Mark;

   procedure Read_Unicode_Data (Path : String) is
      Input         : File_Type;
      Pending_First : Natural := 0;
      Have_Pending  : Boolean := False;
   begin
      Open (Input, In_File, Path);
      while not End_Of_File (Input) loop
         declare
            Line : constant String := Get_Line (Input);
            S1   : constant Natural := Index (Line, ";");
            S2   : constant Natural := Index (Line, ";", From => S1 + 1);
            S3   : constant Natural := Index (Line, ";", From => S2 + 1);
            CP   : constant Natural := Hex_Value (Line (Line'First .. S1 - 1));
            Name : constant String := Line (S1 + 1 .. S2 - 1);
            Cat  : constant String := Line (S2 + 1 .. S3 - 1);
            Is_Mark : constant Boolean := Cat in "Mn" | "Mc" | "Me";
            Is_Zero : constant Boolean := Is_Mark or else Cat = "Cf";
         begin
            if CP = 16#2FFC#
              and then Name = "IDEOGRAPHIC DESCRIPTION CHARACTER SURROUND FROM RIGHT"
            then
               Saw_Unicode_15_1 := True;
            end if;
            if Index (Name, ", First>") /= 0 then
               Pending_First := CP;
               Have_Pending := True;
            elsif Index (Name, ", Last>") /= 0 then
               if not Have_Pending then
                  raise Constraint_Error with "Unicode range has no First record";
               end if;
               if Is_Zero then
                  Mark (Zero_Width, Pending_First, CP);
               end if;
               if Is_Mark then
                  Mark (Attachment, Pending_First, CP);
               end if;
               Have_Pending := False;
            else
               if Is_Zero then
                  Zero_Width (CP) := True;
               end if;
               if Is_Mark then
                  Attachment (CP) := True;
               end if;
            end if;
         end;
      end loop;
      Close (Input);
      if Have_Pending then
         raise Constraint_Error with "unterminated Unicode range";
      end if;
      Mark (Zero_Width, 16#1160#, 16#11FF#);
      Mark (Attachment, 16#FE00#, 16#FE0F#);
      Attachment (16#FE00# .. 16#FE0F#) := (others => False);
      Attachment (16#E0100# .. 16#E01EF#) := (others => False);
   end Read_Unicode_Data;

   procedure Read_East_Asian_Width (Path : String) is
      Input : File_Type;
   begin
      Open (Input, In_File, Path);
      while not End_Of_File (Input) loop
         declare
            Raw      : constant String := Get_Line (Input);
            Property : String (1 .. 8);
            First    : Natural;
            Last     : Natural;
            Valid    : Boolean;
         begin
            if Index (Raw, "EastAsianWidth-15.1.0.txt") /= 0 then
               Saw_EAW_15_1 := True;
            end if;
            Support.Parse_Property_Line
              (Raw, First, Last, Property, Valid);
            if Valid and then Trim (Property, Both) in "W" | "F" then
               Mark (Wide, First, Last);
            end if;
         end;
      end loop;
      Close (Input);
   end Read_East_Asian_Width;

   procedure Read_Emoji_Variation (Path : String) is
      Input : File_Type;
   begin
      Open (Input, In_File, Path);
      while not End_Of_File (Input) loop
         declare
            Raw      : constant String := Get_Line (Input);
            Base     : Natural;
            Selector : Natural;
            Valid    : Boolean;
         begin
            if Index (Raw, "Emoji Version 15.1") /= 0 then
               Saw_Emoji_15_1 := True;
            end if;
            Support.Parse_Variation_Line (Raw, Base, Selector, Valid);
            if Valid and then Selector = 16#FE0F# then
               Emoji_Base (Base) := True;
            end if;
         end;
      end loop;
      Close (Input);
   end Read_Emoji_Variation;

   procedure Write_Intervals
     (Output : File_Type;
      Name   : String;
      Flags  : Flag_Array_Access)
     renames Support.Write_Intervals;

   function Same_Text_Files
     (Left_Path  : String;
      Right_Path : String) return Boolean
     renames Support.Same_Text_Files;

begin
   if Ada.Command_Line.Argument_Count not in 4 .. 5
     or else
       (Ada.Command_Line.Argument_Count = 5
        and then Ada.Command_Line.Argument (5) /= "--check")
   then
      Put_Line
        (Standard_Error,
         "usage: generate_unicode_character_properties " &
         "UnicodeData.txt EastAsianWidth.txt " &
         "emoji-variation-sequences.txt output.ads [--check]");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;
   declare
      Target : constant String := Ada.Command_Line.Argument (4);
      Temporary : constant String :=
        Target & ".tmp." &
        Trim
          (GNAT.OS_Lib.Process_Id'Image (GNAT.OS_Lib.Current_Process_Id), Both);
      Check_Mode : constant Boolean :=
        Ada.Command_Line.Argument_Count = 5;
      Output : File_Type;
      Renamed : Boolean := False;
   begin
      Read_Unicode_Data (Ada.Command_Line.Argument (1));
      Read_East_Asian_Width (Ada.Command_Line.Argument (2));
      Read_Emoji_Variation (Ada.Command_Line.Argument (3));
      if not Saw_Unicode_15_1
        or else not Saw_EAW_15_1
        or else not Saw_Emoji_15_1
      then
         raise Constraint_Error with "all inputs must be Unicode 15.1 data";
      end if;

      Create (Output, Out_File, Temporary);
      Put_Line (Output, "--  Generated from Unicode 15.1 data; do not edit.");
      Put_Line
        (Output, "private package Terminal.Core.Character_Properties_Data is");
      Put_Line (Output, "   Unicode_Version : constant String := ""15.1.0"";");
      Put_Line
        (Output, "   type Interval is record First, Last : Natural; end record;");
      Put_Line
        (Output,
         "   type Interval_Array is array (Positive range <>) of Interval;");
      Write_Intervals (Output, "Wide_Intervals", Wide);
      Write_Intervals (Output, "Emoji_Variation_Base_Intervals", Emoji_Base);
      Write_Intervals (Output, "Zero_Width_Intervals", Zero_Width);
      Write_Intervals
        (Output, "Renderable_Attachment_Intervals", Attachment);
      Put_Line (Output, "end Terminal.Core.Character_Properties_Data;");
      Close (Output);

      if Check_Mode then
         if not Same_Text_Files (Temporary, Target) then
            Put_Line
              (Standard_Error,
               "generated Unicode character properties are out of date");
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         end if;
         Ada.Directories.Delete_File (Temporary);
      else
         GNAT.OS_Lib.Rename_File (Temporary, Target, Renamed);
         if not Renamed then
            raise Use_Error with "cannot atomically replace generated output";
         end if;
      end if;
   exception
      when others =>
         if Is_Open (Output) then
            Close (Output);
         end if;
         if Ada.Directories.Exists (Temporary) then
            Ada.Directories.Delete_File (Temporary);
         end if;
         raise;
   end;
end Generate_Unicode_Character_Properties;
