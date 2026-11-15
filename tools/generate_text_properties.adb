with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with GNAT.OS_Lib;
with Unicode_Generator_Support;

procedure Generate_Text_Properties is
   use Ada.Strings;
   use Ada.Strings.Fixed;
   use Ada.Text_IO;

   package Support renames Unicode_Generator_Support;
   Max_Code_Point : constant Natural := Support.Max_Code_Point;
   subtype Flag_Array is Support.Flag_Array;
   subtype Flag_Array_Access is Support.Flag_Array_Access;
   RTL   : constant Flag_Array_Access :=
     new Flag_Array'(0 .. Max_Code_Point => False);
   Emoji : constant Flag_Array_Access :=
     new Flag_Array'(0 .. Max_Code_Point => False);

   Saw_Scripts_15_1 : Boolean := False;
   Saw_Bidi_15_1    : Boolean := False;
   Saw_Emoji_15_1   : Boolean := False;

   function Hex_Image (Value : Natural) return String
     renames Support.Hex_Image;

   procedure Parse_Property_Line
     (Raw      : String;
      First_CP : out Natural;
      Last_CP  : out Natural;
      Property : out String;
      Valid    : out Boolean)
     renames Support.Parse_Property_Line;

   function Mapped_Script (Name : String) return String is
   begin
      if Name in "Common" | "Inherited" then
         return "Script_Common";
      elsif Name = "Han" then
         return "Script_CJK";
      elsif Name = "Khitan_Small_Script" then
         return "Script_Khitan_Small";
      elsif Name = "Unknown" then
         return "Script_Unknown";
      else
         --  Keep the Unicode property name as the Ada literal.  A newly
         --  introduced script must therefore be added to Text_Run_Script or
         --  the generated unit fails to compile instead of silently becoming
         --  Script_Unknown.
         return "Script_" & Name;
      end if;
   end Mapped_Script;

   --  This policy is intentionally reviewed against the complete mapped
   --  script set below.  Both complex and simple/bidi-routed scripts are
   --  explicit; a Unicode data update that introduces an unreviewed script
   --  aborts generation instead of silently classifying it as simple.
   function Requires_Complex_Shaping (Name : String) return Boolean is
   begin
      if Name in
        "Tibetan" |
        "Devanagari" | "Bengali" | "Gurmukhi" | "Gujarati" | "Oriya" |
        "Tamil" | "Telugu" | "Kannada" | "Malayalam" | "Sinhala" |
        "Brahmi" | "Kaithi" | "Chakma" | "Mahajani" | "Sharada" |
        "Khojki" | "Khudawadi" | "Grantha" | "Newa" | "Tirhuta" |
        "Siddham" | "Modi" | "Takri" | "Ahom" | "Dogra" |
        "Warang_Citi" | "Dives_Akuru" | "Nandinagari" |
        "Zanabazar_Square" | "Soyombo" | "Thai" | "Lao" | "Myanmar" |
        "Mongolian" | "Limbu" | "Tai_Le" | "New_Tai_Lue" | "Khmer" |
        "Balinese" | "Sundanese" | "Batak" | "Lepcha" | "Ol_Chiki" |
        "Syloti_Nagri" | "Phags_Pa" | "Saurashtra" | "Kayah_Li" |
        "Rejang" | "Buginese" | "Tai_Tham" | "Javanese" | "Cham" |
        "Tai_Viet" | "Meetei_Mayek" | "Bhaiksuki" | "Buhid" |
        "Gunjala_Gondi" | "Hanunoo" | "Kawi" | "Kharoshthi" |
        "Makasar" | "Marchen" | "Masaram_Gondi" | "Multani" |
        "Nag_Mundari" | "Sora_Sompeng" | "Tagalog" | "Tagbanwa" |
        "Tangsa"
      then
         return True;
      elsif Name in
        "Adlam" | "Anatolian_Hieroglyphs" | "Arabic" | "Armenian" |
        "Avestan" | "Bamum" | "Bassa_Vah" | "Bopomofo" | "Braille" |
        "Canadian_Aboriginal" | "Carian" | "Caucasian_Albanian" |
        "Cherokee" | "Chorasmian" | "Common" | "Coptic" | "Cuneiform" |
        "Cypriot" | "Cypro_Minoan" | "Cyrillic" | "Deseret" | "Duployan" |
        "Egyptian_Hieroglyphs" | "Elbasan" | "Elymaic" | "Ethiopic" |
        "Georgian" | "Glagolitic" | "Gothic" | "Greek" | "Han" |
        "Hangul" | "Hanifi_Rohingya" | "Hatran" | "Hebrew" | "Hiragana" |
        "Imperial_Aramaic" | "Inherited" | "Inscriptional_Pahlavi" |
        "Inscriptional_Parthian" | "Katakana" | "Khitan_Small_Script" |
        "Latin" | "Linear_A" | "Linear_B" | "Lisu" | "Lycian" | "Lydian" |
        "Mandaic" | "Manichaean" | "Medefaidrin" | "Mende_Kikakui" |
        "Meroitic_Cursive" | "Meroitic_Hieroglyphs" | "Miao" | "Mro" |
        "Nabataean" | "Nko" | "Nushu" | "Nyiakeng_Puachue_Hmong" |
        "Ogham" | "Old_Hungarian" | "Old_Italic" | "Old_North_Arabian" |
        "Old_Permic" | "Old_Persian" | "Old_Sogdian" |
        "Old_South_Arabian" | "Old_Turkic" | "Old_Uyghur" | "Osage" |
        "Osmanya" | "Pahawh_Hmong" | "Palmyrene" | "Pau_Cin_Hau" |
        "Phoenician" | "Psalter_Pahlavi" | "Runic" | "Samaritan" |
        "Shavian" | "SignWriting" | "Sogdian" | "Syriac" | "Tangut" |
        "Thaana" | "Tifinagh" | "Toto" | "Ugaritic" | "Vai" |
        "Vithkuqi" | "Wancho" | "Yezidi" | "Yi"
      then
         return False;
      else
         raise Constraint_Error with
           "unreviewed Unicode shaping policy for script " & Name;
      end if;
   end Requires_Complex_Shaping;

   Reviewed_Mapped_Script_Count : constant := 162;

   procedure Read_Flags
     (Path       : String;
      Property_1 : String;
      Property_2 : String;
      Flags      : Flag_Array_Access;
      Version_Marker : String;
      Saw_Version : out Boolean)
   is
      Input : File_Type;
      Name  : String (1 .. 64);
      First_CP, Last_CP : Natural;
      Valid : Boolean;
   begin
      Saw_Version := False;
      Open (Input, In_File, Path);
      while not End_Of_File (Input) loop
         declare
            Raw : constant String := Get_Line (Input);
         begin
            if Index (Raw, Version_Marker) /= 0 then
               Saw_Version := True;
            end if;
            Parse_Property_Line (Raw, First_CP, Last_CP, Name, Valid);
            if Valid then
               declare
                  Value : constant String := Trim (Name, Both);
               begin
                  if Value = Property_1
                    or else (Property_2'Length > 0 and then Value = Property_2)
                  then
                     Flags (First_CP .. Last_CP) := (others => True);
                  end if;
               end;
            end if;
         end;
      end loop;
      Close (Input);
   end Read_Flags;

   procedure Write_Flag_Intervals
     (Output : File_Type;
      Name   : String;
      Flags  : Flag_Array_Access)
     renames Support.Write_Intervals;

   procedure Write_Script_Intervals
     (Output : File_Type; Path : String)
   is
      Max_Script_Names : constant Positive := 256;
      subtype Script_Name_Index is Natural range 0 .. Max_Script_Names;
      type Script_Name_Array is
        array (Positive range 1 .. Max_Script_Names) of String (1 .. 64);
      type Script_Index_Array is
        array (Natural range 0 .. Max_Code_Point) of Script_Name_Index;
      type Script_Index_Array_Access is access Script_Index_Array;

      Input : File_Type;
      Name : String (1 .. 64);
      First_CP, Last_CP : Natural;
      Valid : Boolean;
      Initial : Boolean := True;
      Names : Script_Name_Array := (others => (others => ' '));
      Name_Count : Natural range 0 .. Max_Script_Names := 0;
      Script_Map : constant Script_Index_Array_Access :=
        new Script_Index_Array'(others => 0);
      Complex_Map : constant Flag_Array_Access :=
        new Flag_Array'(0 .. Max_Code_Point => False);

      function Intern (Value : String) return Script_Name_Index is
      begin
         for I in 1 .. Name_Count loop
            if Trim (Names (I), Both) = Value then
               return I;
            end if;
         end loop;
         if Name_Count = Max_Script_Names then
            raise Constraint_Error with "too many mapped script names";
         end if;
         Name_Count := Name_Count + 1;
         Names (Name_Count) (1 .. Value'Length) := Value;
         return Name_Count;
      end Intern;

      procedure Emit
        (First : Natural;
         Last  : Natural;
         Kind  : Script_Name_Index;
         Complex_Shaping : Boolean) is
      begin
         if not Initial then
            Put_Line (Output, ",");
         end if;
         Put
           (Output, "      (16#" & Hex_Image (First) & "#, 16#" &
            Hex_Image (Last) & "#, RM." & Trim (Names (Kind), Both) & ", " &
            Boolean'Image (Complex_Shaping) & ")");
         Initial := False;
      end Emit;
   begin
      Open (Input, In_File, Path);
      while not End_Of_File (Input) loop
         declare
            Raw : constant String := Get_Line (Input);
         begin
            if Index (Raw, "Scripts-15.1.0.txt") /= 0 then
               Saw_Scripts_15_1 := True;
            end if;
            Parse_Property_Line (Raw, First_CP, Last_CP, Name, Valid);
            if Valid then
               declare
                  Mapped : constant String := Mapped_Script (Trim (Name, Both));
                  Kind   : constant Script_Name_Index := Intern (Mapped);
               begin
                  Script_Map (First_CP .. Last_CP) := (others => Kind);
                  Complex_Map (First_CP .. Last_CP) :=
                    (others => Requires_Complex_Shaping (Trim (Name, Both)));
               end;
            end if;
         end;
      end loop;
      Close (Input);

      if Name_Count /= Reviewed_Mapped_Script_Count then
         raise Constraint_Error with
           "Unicode script set changed; review complex-shaping policy"
           & Natural'Image (Name_Count);
      end if;

      Put_Line (Output, "   Script_Intervals : constant Script_Interval_Array :=");
      Put_Line (Output, "     (");
      declare
         First : Natural := Script_Map'First;
         Last  : Natural;
         Kind  : Script_Name_Index;
      begin
         while First <= Script_Map'Last loop
            while First <= Script_Map'Last and then Script_Map (First) = 0 loop
               First := First + 1;
            end loop;
            exit when First > Script_Map'Last;
            Kind := Script_Map (First);
            Last := First;
            while Last < Script_Map'Last
              and then Script_Map (Last + 1) = Kind
              and then Complex_Map (Last + 1) = Complex_Map (First)
            loop
               Last := Last + 1;
            end loop;
            Emit (First, Last, Kind, Complex_Map (First));
            exit when Last = Script_Map'Last;
            First := Last + 1;
         end loop;
      end;
      Put_Line (Output, ");");
   end Write_Script_Intervals;

   function Same_Text_Files
     (Left_Path  : String;
      Right_Path : String) return Boolean
     renames Support.Same_Text_Files;

begin
   if Ada.Command_Line.Argument_Count not in 4 .. 5
     or else (Ada.Command_Line.Argument_Count = 5
              and then Ada.Command_Line.Argument (5) /= "--check")
   then
      Put_Line
        (Standard_Error,
         "usage: generate_text_properties Scripts.txt DerivedBidiClass.txt " &
         "emoji-data.txt output.ads [--check]");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   declare
      Target : constant String := Ada.Command_Line.Argument (4);
      Temporary : constant String :=
        Target & ".tmp." &
        Trim
          (GNAT.OS_Lib.Process_Id'Image (GNAT.OS_Lib.Current_Process_Id), Both);
      Check_Mode : constant Boolean := Ada.Command_Line.Argument_Count = 5;
      Output : File_Type;
      Renamed : Boolean := False;
   begin
      Read_Flags
        (Ada.Command_Line.Argument (2), "R", "AL", RTL,
         "DerivedBidiClass-15.1.0.txt", Saw_Bidi_15_1);
      Read_Flags
        (Ada.Command_Line.Argument (3), "Emoji", "", Emoji,
         "Emoji Version 15.1", Saw_Emoji_15_1);
      Create (Output, Out_File, Temporary);
      Put_Line (Output, "--  Generated from Unicode 15.1 data; do not edit.");
      Put_Line (Output, "with Terminal.App.Render_Model;");
      Put_Line (Output, "private package Terminal.App.Text_Properties_Data is");
      Put_Line (Output, "   package RM renames Terminal.App.Render_Model;");
      Put_Line (Output, "   Unicode_Version : constant String := ""15.1.0"";");
      Put_Line (Output, "   type Interval is record First, Last : Natural; end record;");
      Put_Line (Output, "   type Interval_Array is array (Positive range <>) of Interval;");
      Put_Line
        (Output,
         "   type Script_Interval is record First, Last : Natural; " &
         "Script : RM.Text_Run_Script; Complex_Shaping : Boolean; end record;");
      Put_Line
        (Output,
         "   type Script_Interval_Array is array (Positive range <>) of Script_Interval;");
      Write_Script_Intervals (Output, Ada.Command_Line.Argument (1));
      Write_Flag_Intervals (Output, "RTL_Intervals", RTL);
      Write_Flag_Intervals (Output, "Emoji_Intervals", Emoji);
      Put_Line (Output, "end Terminal.App.Text_Properties_Data;");
      Close (Output);

      if not Saw_Scripts_15_1 or else not Saw_Bidi_15_1 or else not Saw_Emoji_15_1 then
         raise Constraint_Error with "all inputs must be Unicode 15.1 data";
      elsif Check_Mode then
         if not Same_Text_Files (Temporary, Target) then
            Put_Line (Standard_Error, "generated text properties are out of date");
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
         if Is_Open (Output) then Close (Output); end if;
         if Ada.Directories.Exists (Temporary) then
            Ada.Directories.Delete_File (Temporary);
         end if;
         raise;
   end;
end Generate_Text_Properties;
