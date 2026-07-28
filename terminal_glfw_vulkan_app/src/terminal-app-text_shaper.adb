with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;

with Terminal.App.Fonts;
with Terminal.App.HarfBuzz;

package body Terminal.App.Text_Shaper is
   package RM renames Terminal.App.Render_Model;
   package HB renames Terminal.App.HarfBuzz;
   use type RM.Text_Run_Kind;
   use type HB.Load_Status;
   use type HB.Shape_Status;

   Max_Shaping_Fallbacks : constant := Terminal.App.Fonts.Max_Fallback_Fonts;
   type Fallback_Face_Array is
     array (Positive range 1 .. Max_Shaping_Fallbacks) of HB.Font_Face;

   Default_Face         : HB.Font_Face;
   Default_Face_Loaded  : Boolean := False;
   Default_Face_Tried   : Boolean := False;
   Fallback_Faces       : Fallback_Face_Array;
   Fallback_Face_Count  : Natural := 0;

   --  Shaping dominates the per-frame render cost, and the whole visible screen
   --  is reshaped every frame even when nothing changed (a cursor blink alone
   --  redraws it). Shaping is a pure function of a run's codepoints -- Direction,
   --  Script and Run_Kind are all derived from them -- and of the loaded faces,
   --  so memoise the fields Prepare produces, keyed on the codepoints (plus Bold
   --  and Italic, conservatively). The cache is dropped whenever the face set
   --  changes (Configure_Font / Add_Fallback_Font), the only thing that can alter
   --  a run's shaping.
   type Shape_Cache_Entry is record
      Run_Kind           : RM.Text_Run_Kind;
      Shape_Status       : RM.Text_Run_Shape_Status;
      Direction          : RM.Text_Run_Direction;
      Script             : RM.Text_Run_Script;
      Shaped_Glyphs      : RM.Shaped_Glyph_Array;
      Shaped_Glyph_Count : RM.Shaped_Glyph_Total;
      Fallback_Glyphs    : Boolean;
   end record;

   package Shape_Cache_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Shape_Cache_Entry,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   Shape_Cache             : Shape_Cache_Maps.Map;
   Max_Shape_Cache_Entries : constant := 8192;

   procedure Clear_Shape_Cache is
   begin
      Shape_Cache.Clear;
   end Clear_Shape_Cache;

   function Shape_Cache_Key (Run : RM.Text_Run_Command) return String is
      use Ada.Strings.Unbounded;
      Result : Unbounded_String;
   begin
      Append (Result, (if Run.Bold then 'B' else 'b'));
      Append (Result, (if Run.Italic then 'I' else 'i'));
      for I in 1 .. Run.Codepoint_Count loop
         declare
            CP : constant Natural := Run.Codepoints (I);
         begin
            Append (Result, Character'Val (CP mod 256));
            Append (Result, Character'Val ((CP / 256) mod 256));
            Append (Result, Character'Val ((CP / 65536) mod 256));
         end;
      end loop;
      return To_String (Result);
   end Shape_Cache_Key;

   procedure Configure_Font
     (Path        : String;
      Pixel_Size  : Positive;
      Status      : out Backend_Status)
   is
      Load_Result : HB.Load_Status;
   begin
      HB.Load (Default_Face, Path, Pixel_Size, Load_Result);
      Default_Face_Tried := True;
      Default_Face_Loaded := Load_Result = HB.Loaded;
      for I in 1 .. Fallback_Face_Count loop
         HB.Reset (Fallback_Faces (I));
      end loop;
      Fallback_Face_Count := 0;
      Clear_Shape_Cache;

      case Load_Result is
         when HB.Loaded =>
            Status := Backend_Ok;
         when HB.Invalid_Path =>
            Status := Backend_Unavailable;
         when HB.Load_Failed =>
            Status := Backend_Load_Failed;
      end case;
   end Configure_Font;

   procedure Add_Fallback_Font
     (Path        : String;
      Pixel_Size  : Positive;
      Status      : out Backend_Status)
   is
      Load_Result : HB.Load_Status;
      Slot        : Natural;
   begin
      if Fallback_Face_Count >= Max_Shaping_Fallbacks then
         Status := Backend_Unavailable;
         return;
      end if;

      Slot := Fallback_Face_Count + 1;
      HB.Load (Fallback_Faces (Slot), Path, Pixel_Size, Load_Result);

      case Load_Result is
         when HB.Loaded =>
            Fallback_Face_Count := Slot;
            --  A new fallback face can change how previously-unshaped runs shape,
            --  so the memoised results are no longer valid.
            Clear_Shape_Cache;
            Status := Backend_Ok;
         when HB.Invalid_Path =>
            Status := Backend_Unavailable;
         when HB.Load_Failed =>
            Status := Backend_Load_Failed;
      end case;
   end Add_Fallback_Font;

   function Backend_Available return Boolean is
     (Default_Face_Loaded and then HB.Is_Loaded (Default_Face));

   function Backend_Status_Label (Status : Backend_Status) return String is
   begin
      case Status is
         when Backend_Ok =>
            return "Shaping backend ready";
         when Backend_Unavailable =>
            return "Shaping backend unavailable";
         when Backend_Load_Failed =>
            return "Shaping backend load failed";
      end case;
   end Backend_Status_Label;

   function Shape_Status_Label (Status : Shape_Status) return String is
   begin
      case Status is
         when RM.Shape_Ok =>
            return "Text shaping complete";
         when RM.Needs_Shaping_Backend =>
            return "Text shaping backend needed";
         when RM.Invalid_Run =>
            return "Text shaping skipped; invalid run";
      end case;
   end Shape_Status_Label;

   procedure Ensure_Default_Backend is
      Status : Backend_Status;
   begin
      if not Default_Face_Tried then
         Configure_Font
           (Path       => Terminal.App.Fonts.Default_Font_Path,
            Pixel_Size => 16,
            Status     => Status);
      end if;
   end Ensure_Default_Backend;

   function Is_Combining_Or_Format (C : Natural) return Boolean is
     ((C in 16#0300# .. 16#036F#)
      or else (C in 16#1AB0# .. 16#1AFF#)
      or else (C in 16#1DC0# .. 16#1DFF#)
      or else (C in 16#20D0# .. 16#20FF#)
      or else (C in 16#FE20# .. 16#FE2F#)
      or else (C in 16#FE00# .. 16#FE0F#)
      or else C = 16#200C#
      or else (C in 16#E0020# .. 16#E007F#));

   function Is_ZWJ (C : Natural) return Boolean is
     (C = 16#200D#);

   function Is_Emoji_Modifier (C : Natural) return Boolean is
     (C in 16#1F3FB# .. 16#1F3FF#);

   function Is_LTR_Directional_Control (C : Natural) return Boolean is
     (C = 16#200E#
      or else C = 16#202A#
      or else C = 16#202D#
      or else C = 16#2066#);

   function Is_RTL_Directional_Control (C : Natural) return Boolean is
     (C = 16#200F#
      or else C = 16#202B#
      or else C = 16#202E#
      or else C = 16#2067#);

   function Is_Neutral_Bidi_Control (C : Natural) return Boolean is
     (C = 16#202C#
      or else C = 16#2068#
      or else C = 16#2069#);

   function Is_Bidi_Control (C : Natural) return Boolean is
     (Is_LTR_Directional_Control (C)
      or else Is_RTL_Directional_Control (C)
      or else Is_Neutral_Bidi_Control (C));

   function Is_RTL_Script (C : Natural) return Boolean is
     ((C in 16#0590# .. 16#08FF#)
      or else (C in 16#FB1D# .. 16#FDFF#)
      or else (C in 16#FE70# .. 16#FEFF#)
      or else (C in 16#10840# .. 16#1093F#)
      or else (C in 16#10A60# .. 16#10AFF#)
      or else (C in 16#10B00# .. 16#10BAF#)
      or else (C in 16#10D00# .. 16#10D3F#)
      or else (C in 16#1E900# .. 16#1E95F#));

   function Is_Bidi_Control_Or_RTL (C : Natural) return Boolean is
     (Is_RTL_Script (C) or else Is_Bidi_Control (C));

   function Is_Hebrew (C : Natural) return Boolean is
     (C in 16#0590# .. 16#05FF#);

   function Is_Arabic (C : Natural) return Boolean is
     ((C in 16#0600# .. 16#08FF#)
      or else (C in 16#FB50# .. 16#FDFF#)
      or else (C in 16#FE70# .. 16#FEFF#));

   function Is_Syriac (C : Natural) return Boolean is
     ((C in 16#0700# .. 16#074F#)
      or else C in 16#0860# .. 16#086F#);

   function Is_Thaana (C : Natural) return Boolean is
     (C in 16#0780# .. 16#07BF#);

   function Is_NKo (C : Natural) return Boolean is
     (C in 16#07C0# .. 16#07FF#);

   function Is_Samaritan (C : Natural) return Boolean is
     (C in 16#0800# .. 16#083F#);

   function Is_Mandaic (C : Natural) return Boolean is
     (C in 16#0840# .. 16#085F#);

   function Is_Adlam (C : Natural) return Boolean is
     (C in 16#1E900# .. 16#1E95F#);

   function Is_Hanifi_Rohingya (C : Natural) return Boolean is
     (C in 16#10D00# .. 16#10D3F#);

   function Is_Imperial_Aramaic (C : Natural) return Boolean is
     (C in 16#10840# .. 16#1085F#);

   function Is_Palmyrene (C : Natural) return Boolean is
     (C in 16#10860# .. 16#1087F#);

   function Is_Nabataean (C : Natural) return Boolean is
     (C in 16#10880# .. 16#108AF#);

   function Is_Hatran (C : Natural) return Boolean is
     (C in 16#108E0# .. 16#108FF#);

   function Is_Phoenician (C : Natural) return Boolean is
     (C in 16#10900# .. 16#1091F#);

   function Is_Lydian (C : Natural) return Boolean is
     (C in 16#10920# .. 16#1093F#);

   function Is_Avestan (C : Natural) return Boolean is
     (C in 16#10B00# .. 16#10B3F#);

   function Is_Inscriptional_Parthian (C : Natural) return Boolean is
     (C in 16#10B40# .. 16#10B5F#);

   function Is_Inscriptional_Pahlavi (C : Natural) return Boolean is
     (C in 16#10B60# .. 16#10B7F#);

   function Is_Psalter_Pahlavi (C : Natural) return Boolean is
     (C in 16#10B80# .. 16#10BAF#);

   function Is_Old_South_Arabian (C : Natural) return Boolean is
     (C in 16#10A60# .. 16#10A7F#);

   function Is_Old_North_Arabian (C : Natural) return Boolean is
     (C in 16#10A80# .. 16#10A9F#);

   function Is_Manichaean (C : Natural) return Boolean is
     (C in 16#10AC0# .. 16#10AFF#);

   function Is_Complex_Script (C : Natural) return Boolean is
     ((C in 16#0900# .. 16#0D7F#)
      or else (C in 16#0D80# .. 16#0DFF#)
      or else (C in 16#0F00# .. 16#0FFF#)
      or else (C in 16#11000# .. 16#114DF#)
      or else (C in 16#11580# .. 16#11AAF#)
      or else (C in 16#0E00# .. 16#0E7F#)
      or else (C in 16#0E80# .. 16#0EFF#)
      or else (C in 16#1000# .. 16#109F#)
      or else (C in 16#1800# .. 16#18AF#)
      or else (C in 16#1900# .. 16#19DF#)
      or else (C in 16#1A00# .. 16#1AAF#)
      or else (C in 16#1B00# .. 16#1BFF#)
      or else (C in 16#1C00# .. 16#1C7F#)
      or else (C in 16#1780# .. 16#17FF#)
      or else (C in 16#A800# .. 16#A95F#)
      or else (C in 16#A980# .. 16#A9DF#)
      or else (C in 16#AA00# .. 16#AAFF#)
      or else (C in 16#ABC0# .. 16#ABFF#));

   function Is_Latin (C : Natural) return Boolean is
     ((C in Character'Pos ('A') .. Character'Pos ('Z'))
      or else (C in Character'Pos ('a') .. Character'Pos ('z'))
      or else (C in 16#00C0# .. 16#024F#)
      or else (C in 16#1E00# .. 16#1EFF#));

   function Is_Greek (C : Natural) return Boolean is
     ((C in 16#0370# .. 16#03FF#)
      or else (C in 16#1F00# .. 16#1FFF#));

   function Is_Cyrillic (C : Natural) return Boolean is
     ((C in 16#0400# .. 16#052F#)
      or else (C in 16#2DE0# .. 16#2DFF#)
      or else (C in 16#A640# .. 16#A69F#));

   function Is_Glagolitic (C : Natural) return Boolean is
     ((C in 16#2C00# .. 16#2C5F#)
      or else (C in 16#1E000# .. 16#1E02F#));

   function Is_Coptic (C : Natural) return Boolean is
     ((C in 16#03E2# .. 16#03EF#)
      or else (C in 16#2C80# .. 16#2CFF#));

   function Is_Gothic (C : Natural) return Boolean is
     (C in 16#10330# .. 16#1034F#);

   function Is_Old_Italic (C : Natural) return Boolean is
     (C in 16#10300# .. 16#1032F#);

   function Is_Old_Persian (C : Natural) return Boolean is
     (C in 16#103A0# .. 16#103DF#);

   function Is_Ugaritic (C : Natural) return Boolean is
     (C in 16#10380# .. 16#1039F#);

   function Is_Linear_B (C : Natural) return Boolean is
     (C in 16#10000# .. 16#1007F#);

   function Is_Cypriot (C : Natural) return Boolean is
     (C in 16#10800# .. 16#1083F#);

   function Is_Egyptian_Hieroglyphs (C : Natural) return Boolean is
     (C in 16#13000# .. 16#1342F#);

   function Is_Anatolian_Hieroglyphs (C : Natural) return Boolean is
     (C in 16#14400# .. 16#1467F#);

   function Is_Old_Permic (C : Natural) return Boolean is
     (C in 16#10350# .. 16#1037F#);

   function Is_Elbasan (C : Natural) return Boolean is
     (C in 16#10500# .. 16#1052F#);

   function Is_Caucasian_Albanian (C : Natural) return Boolean is
     (C in 16#10530# .. 16#1056F#);

   function Is_Mro (C : Natural) return Boolean is
     (C in 16#16A40# .. 16#16A6F#);

   function Is_Bassa_Vah (C : Natural) return Boolean is
     (C in 16#16AD0# .. 16#16AFF#);

   function Is_Pahawh_Hmong (C : Natural) return Boolean is
     (C in 16#16B00# .. 16#16B8F#);

   function Is_Linear_A (C : Natural) return Boolean is
     (C in 16#10600# .. 16#1077F#);

   function Is_Phaistos_Disc (C : Natural) return Boolean is
     (C in 16#101D0# .. 16#101FF#);

   function Is_Cuneiform (C : Natural) return Boolean is
     ((C in 16#12000# .. 16#123FF#)
      or else (C in 16#12400# .. 16#1247F#)
      or else (C in 16#12480# .. 16#1254F#));

   function Is_Lycian (C : Natural) return Boolean is
     (C in 16#10280# .. 16#1029F#);

   function Is_Carian (C : Natural) return Boolean is
     (C in 16#102A0# .. 16#102DF#);

   function Is_Old_Turkic (C : Natural) return Boolean is
     (C in 16#10C00# .. 16#10C4F#);

   function Is_Medefaidrin (C : Natural) return Boolean is
     (C in 16#16E40# .. 16#16E9F#);

   function Is_Toto (C : Natural) return Boolean is
     (C in 16#1E290# .. 16#1E2BF#);

   function Is_Wancho (C : Natural) return Boolean is
     (C in 16#1E2C0# .. 16#1E2FF#);

   function Is_Deseret (C : Natural) return Boolean is
     (C in 16#10400# .. 16#1044F#);

   function Is_Shavian (C : Natural) return Boolean is
     (C in 16#10450# .. 16#1047F#);

   function Is_Osmanya (C : Natural) return Boolean is
     (C in 16#10480# .. 16#104AF#);

   function Is_Osage (C : Natural) return Boolean is
     (C in 16#104B0# .. 16#104FF#);

   function Is_Bamum (C : Natural) return Boolean is
     ((C in 16#A6A0# .. 16#A6FF#)
      or else (C in 16#16800# .. 16#16A3F#));

   function Is_Lisu (C : Natural) return Boolean is
     ((C in 16#A4D0# .. 16#A4FF#)
      or else (C in 16#11FB0# .. 16#11FBF#));

   function Is_Miao (C : Natural) return Boolean is
     (C in 16#16F00# .. 16#16F9F#);

   function Is_Nushu (C : Natural) return Boolean is
     (C in 16#1B170# .. 16#1B2FF#);

   function Is_Tangut (C : Natural) return Boolean is
     ((C in 16#17000# .. 16#187FF#)
      or else (C in 16#18800# .. 16#18AFF#));

   function Is_Khitan_Small (C : Natural) return Boolean is
     (C in 16#18B00# .. 16#18CFF#);

   function Is_Armenian (C : Natural) return Boolean is
     ((C in 16#0530# .. 16#058F#)
      or else (C in 16#FB13# .. 16#FB17#));

   function Is_Georgian (C : Natural) return Boolean is
     ((C in 16#10A0# .. 16#10FF#)
      or else (C in 16#1C90# .. 16#1CBF#)
      or else (C in 16#2D00# .. 16#2D2F#));

   function Is_Ethiopic (C : Natural) return Boolean is
     ((C in 16#1200# .. 16#137F#)
      or else (C in 16#1380# .. 16#139F#)
      or else (C in 16#2D80# .. 16#2DDF#)
      or else (C in 16#AB00# .. 16#AB2F#));

   function Is_Cherokee (C : Natural) return Boolean is
     ((C in 16#13A0# .. 16#13FF#)
      or else (C in 16#AB70# .. 16#ABBF#));

   function Is_Canadian_Aboriginal (C : Natural) return Boolean is
     ((C in 16#1400# .. 16#167F#)
      or else (C in 16#18B0# .. 16#18FF#));

   function Is_Ogham (C : Natural) return Boolean is
     (C in 16#1680# .. 16#169F#);

   function Is_Runic (C : Natural) return Boolean is
     (C in 16#16A0# .. 16#16FF#);

   function Is_Tifinagh (C : Natural) return Boolean is
     (C in 16#2D30# .. 16#2D7F#);

   function Is_Vai (C : Natural) return Boolean is
     (C in 16#A500# .. 16#A63F#);

   function Is_ASCII_Digit (C : Natural) return Boolean is
     (C in Character'Pos ('0') .. Character'Pos ('9'));

   function Is_Hiragana (C : Natural) return Boolean is
     ((C in 16#3040# .. 16#309F#)
      or else (C in 16#1B001# .. 16#1B11F#));

   function Is_Katakana (C : Natural) return Boolean is
     ((C in 16#30A0# .. 16#30FF#)
      or else (C in 16#31F0# .. 16#31FF#)
      or else (C in 16#1B000# .. 16#1B0FF#));

   function Is_Bopomofo (C : Natural) return Boolean is
     ((C in 16#3100# .. 16#312F#)
      or else (C in 16#31A0# .. 16#31BF#));

   function Is_Hangul (C : Natural) return Boolean is
     ((C in 16#1100# .. 16#11FF#)
      or else (C in 16#3130# .. 16#318F#)
      or else (C in 16#A960# .. 16#A97F#)
      or else (C in 16#AC00# .. 16#D7AF#)
      or else (C in 16#D7B0# .. 16#D7FF#));

   function Is_Yi (C : Natural) return Boolean is
     (C in 16#A000# .. 16#A4CF#);

   function Is_CJK (C : Natural) return Boolean is
     ((C in 16#1100# .. 16#11FF#)
      or else (C in 16#2E80# .. 16#A4CF#)
      or else (C in 16#AC00# .. 16#D7AF#)
      or else (C in 16#F900# .. 16#FAFF#)
      or else (C in 16#20000# .. 16#3FFFD#));

   function Is_Emoji (C : Natural) return Boolean is
     ((C in 16#1F000# .. 16#1FAFF#)
      or else (C in 16#2600# .. 16#27BF#));

   function Is_Common (C : Natural) return Boolean is
     (C <= 16#0040#
      or else (C in 16#005B# .. 16#0060#)
      or else (C in 16#007B# .. 16#00BF#)
      or else Is_Combining_Or_Format (C)
      or else Is_Bidi_Control (C));

   function Has_Common_Ligature_Sequence (Run : RM.Text_Run_Command) return Boolean is
   begin
      if Run.Codepoint_Count < 2 then
         return False;
      end if;

      for I in 1 .. Run.Codepoint_Count - 1 loop
         if Run.Codepoints (I) = Character'Pos ('f') then
            if Run.Codepoints (I + 1) = Character'Pos ('f')
              or else Run.Codepoints (I + 1) = Character'Pos ('i')
              or else Run.Codepoints (I + 1) = Character'Pos ('l')
            then
               return True;
            end if;
         end if;
      end loop;

      return False;
   end Has_Common_Ligature_Sequence;

   function Classify (Run : RM.Text_Run_Command) return Run_Kind is
      Saw_Combining : Boolean := False;
   begin
      if Run.Codepoint_Count = 0 then
         return RM.Invalid_Run;
      end if;

      for I in 1 .. Run.Codepoint_Count loop
         declare
            C : constant Natural := Run.Codepoints (I);
         begin
            if C > 16#10FFFF# then
               return RM.Invalid_Run;
            elsif Is_ASCII_Digit (C) then
               null;
            elsif Is_Bidi_Control_Or_RTL (C) then
               return RM.Bidi_Text;
            elsif Is_ZWJ (C) then
               return RM.Joined_Emoji_Cluster;
            elsif Is_Emoji_Modifier (C) then
               return RM.Emoji_Modified_Cluster;
            elsif Is_Complex_Script (C) then
               return RM.Complex_Script;
            elsif Is_Combining_Or_Format (C) then
               Saw_Combining := True;
            end if;
         end;
      end loop;

      if Saw_Combining then
         return RM.Combining_Cluster;
      elsif Has_Common_Ligature_Sequence (Run) then
         return RM.Ligature_Candidate;
      elsif Run.Codepoint_Count > 1 then
         return RM.Simple_Text;
      else
         return RM.Simple_Glyph;
      end if;
   end Classify;

   function Requires_Backend (Kind : Run_Kind) return Boolean is
     (Kind not in RM.Simple_Glyph | RM.Simple_Text);

   function Has_Notdef_Glyph (Run : RM.Text_Run_Command) return Boolean is
   begin
      for I in 1 .. Run.Shaped_Glyph_Count loop
         if Run.Shaped_Glyphs (I).Glyph_ID = 0 then
            return True;
         end if;
      end loop;

      return False;
   end Has_Notdef_Glyph;

   procedure Shape_With_Configured_Faces
     (Run    : in out RM.Text_Run_Command;
      Status : out HB.Shape_Status)
   is
      Candidate : RM.Text_Run_Command;
      Candidate_Status : HB.Shape_Status;
      Primary_Result : RM.Text_Run_Command;
      Primary_Status : HB.Shape_Status := HB.Not_Loaded;
   begin
      if Backend_Available then
         Candidate := Run;
         HB.Shape (Default_Face, 0, Candidate, Candidate_Status);
         if Candidate_Status = HB.Shaped and then not Has_Notdef_Glyph (Candidate) then
            Run := Candidate;
            Status := HB.Shaped;
            return;
         end if;

         Primary_Result := Candidate;
         Primary_Status := Candidate_Status;
      end if;

      for I in 1 .. Fallback_Face_Count loop
         if HB.Is_Loaded (Fallback_Faces (I)) then
            Candidate := Run;
            HB.Shape (Fallback_Faces (I), I, Candidate, Candidate_Status);
            if Candidate_Status = HB.Shaped
              and then not Has_Notdef_Glyph (Candidate)
            then
               Run := Candidate;
               Status := HB.Shaped;
               return;
            end if;
         end if;
      end loop;

      if Primary_Status = HB.Shaped then
         Run := Primary_Result;
         Status :=
           (if Has_Notdef_Glyph (Primary_Result)
            then HB.Shape_Failed
            else HB.Shaped);
      else
         Status := Primary_Status;
      end if;
   end Shape_With_Configured_Faces;

   function Direction_Of (Run : RM.Text_Run_Command) return RM.Text_Run_Direction is
   begin
      for I in 1 .. Run.Codepoint_Count loop
         if Is_RTL_Script (Run.Codepoints (I))
           or else Is_RTL_Directional_Control (Run.Codepoints (I))
         then
            return RM.Direction_Right_To_Left;
         elsif Is_LTR_Directional_Control (Run.Codepoints (I)) then
            return RM.Direction_Left_To_Right;
         elsif Is_ASCII_Digit (Run.Codepoints (I)) then
            return RM.Direction_Left_To_Right;
         elsif Is_Latin (Run.Codepoints (I))
           or else Is_Greek (Run.Codepoints (I))
           or else Is_Cyrillic (Run.Codepoints (I))
           or else Is_Armenian (Run.Codepoints (I))
           or else Is_Georgian (Run.Codepoints (I))
           or else Is_Ethiopic (Run.Codepoints (I))
           or else Is_Cherokee (Run.Codepoints (I))
           or else Is_Canadian_Aboriginal (Run.Codepoints (I))
           or else Is_Ogham (Run.Codepoints (I))
           or else Is_Runic (Run.Codepoints (I))
           or else Is_Tifinagh (Run.Codepoints (I))
           or else Is_Vai (Run.Codepoints (I))
           or else Is_Glagolitic (Run.Codepoints (I))
           or else Is_Coptic (Run.Codepoints (I))
           or else Is_Gothic (Run.Codepoints (I))
           or else Is_Old_Italic (Run.Codepoints (I))
           or else Is_Old_Persian (Run.Codepoints (I))
           or else Is_Ugaritic (Run.Codepoints (I))
           or else Is_Linear_B (Run.Codepoints (I))
           or else Is_Cypriot (Run.Codepoints (I))
           or else Is_Egyptian_Hieroglyphs (Run.Codepoints (I))
           or else Is_Anatolian_Hieroglyphs (Run.Codepoints (I))
           or else Is_Old_Permic (Run.Codepoints (I))
           or else Is_Elbasan (Run.Codepoints (I))
           or else Is_Caucasian_Albanian (Run.Codepoints (I))
           or else Is_Mro (Run.Codepoints (I))
           or else Is_Bassa_Vah (Run.Codepoints (I))
           or else Is_Pahawh_Hmong (Run.Codepoints (I))
           or else Is_Linear_A (Run.Codepoints (I))
           or else Is_Phaistos_Disc (Run.Codepoints (I))
           or else Is_Cuneiform (Run.Codepoints (I))
           or else Is_Lycian (Run.Codepoints (I))
           or else Is_Carian (Run.Codepoints (I))
           or else Is_Old_Turkic (Run.Codepoints (I))
           or else Is_Medefaidrin (Run.Codepoints (I))
           or else Is_Toto (Run.Codepoints (I))
           or else Is_Wancho (Run.Codepoints (I))
           or else Is_Deseret (Run.Codepoints (I))
           or else Is_Shavian (Run.Codepoints (I))
           or else Is_Osmanya (Run.Codepoints (I))
           or else Is_Osage (Run.Codepoints (I))
           or else Is_Bamum (Run.Codepoints (I))
           or else Is_Lisu (Run.Codepoints (I))
           or else Is_Miao (Run.Codepoints (I))
           or else Is_Nushu (Run.Codepoints (I))
           or else Is_Tangut (Run.Codepoints (I))
           or else Is_Khitan_Small (Run.Codepoints (I))
           or else Is_Hiragana (Run.Codepoints (I))
           or else Is_Katakana (Run.Codepoints (I))
           or else Is_Bopomofo (Run.Codepoints (I))
           or else Is_Hangul (Run.Codepoints (I))
           or else Is_Yi (Run.Codepoints (I))
           or else Is_CJK (Run.Codepoints (I))
           or else Is_Emoji (Run.Codepoints (I))
           or else Is_Complex_Script (Run.Codepoints (I))
         then
            return RM.Direction_Left_To_Right;
         end if;
      end loop;

      return RM.Direction_Neutral;
   end Direction_Of;

   function Script_Of (Run : RM.Text_Run_Command) return RM.Text_Run_Script is
   begin
      for I in 1 .. Run.Codepoint_Count loop
         declare
            C : constant Natural := Run.Codepoints (I);
         begin
            if Is_Hebrew (C) then
               return RM.Script_Hebrew;
            elsif Is_Syriac (C) then
               return RM.Script_Syriac;
            elsif Is_Thaana (C) then
               return RM.Script_Thaana;
            elsif Is_NKo (C) then
               return RM.Script_NKo;
            elsif Is_Samaritan (C) then
               return RM.Script_Samaritan;
            elsif Is_Mandaic (C) then
               return RM.Script_Mandaic;
            elsif Is_Adlam (C) then
               return RM.Script_Adlam;
            elsif Is_Hanifi_Rohingya (C) then
               return RM.Script_Hanifi_Rohingya;
            elsif Is_Imperial_Aramaic (C) then
               return RM.Script_Imperial_Aramaic;
            elsif Is_Palmyrene (C) then
               return RM.Script_Palmyrene;
            elsif Is_Nabataean (C) then
               return RM.Script_Nabataean;
            elsif Is_Hatran (C) then
               return RM.Script_Hatran;
            elsif Is_Phoenician (C) then
               return RM.Script_Phoenician;
            elsif Is_Lydian (C) then
               return RM.Script_Lydian;
            elsif Is_Avestan (C) then
               return RM.Script_Avestan;
            elsif Is_Inscriptional_Parthian (C) then
               return RM.Script_Inscriptional_Parthian;
            elsif Is_Inscriptional_Pahlavi (C) then
               return RM.Script_Inscriptional_Pahlavi;
            elsif Is_Psalter_Pahlavi (C) then
               return RM.Script_Psalter_Pahlavi;
            elsif Is_Old_South_Arabian (C) then
               return RM.Script_Old_South_Arabian;
            elsif Is_Old_North_Arabian (C) then
               return RM.Script_Old_North_Arabian;
            elsif Is_Manichaean (C) then
               return RM.Script_Manichaean;
            elsif Is_Arabic (C) then
               return RM.Script_Arabic;
            elsif C in 16#0F00# .. 16#0FFF# then
               return RM.Script_Tibetan;
            elsif C in 16#0900# .. 16#097F# then
               return RM.Script_Devanagari;
            elsif C in 16#0980# .. 16#09FF# then
               return RM.Script_Bengali;
            elsif C in 16#0A00# .. 16#0A7F# then
               return RM.Script_Gurmukhi;
            elsif C in 16#0A80# .. 16#0AFF# then
               return RM.Script_Gujarati;
            elsif C in 16#0B00# .. 16#0B7F# then
               return RM.Script_Oriya;
            elsif C in 16#0B80# .. 16#0BFF# then
               return RM.Script_Tamil;
            elsif C in 16#0C00# .. 16#0C7F# then
               return RM.Script_Telugu;
            elsif C in 16#0C80# .. 16#0CFF# then
               return RM.Script_Kannada;
            elsif C in 16#0D00# .. 16#0D7F# then
               return RM.Script_Malayalam;
            elsif C in 16#0D80# .. 16#0DFF# then
               return RM.Script_Sinhala;
            elsif C in 16#11000# .. 16#1107F# then
               return RM.Script_Brahmi;
            elsif C in 16#11080# .. 16#110CF# then
               return RM.Script_Kaithi;
            elsif C in 16#11100# .. 16#1114F# then
               return RM.Script_Chakma;
            elsif C in 16#11150# .. 16#1117F# then
               return RM.Script_Mahajani;
            elsif C in 16#11180# .. 16#111DF# then
               return RM.Script_Sharada;
            elsif C in 16#11200# .. 16#1124F# then
               return RM.Script_Khojki;
            elsif C in 16#112B0# .. 16#112FF# then
               return RM.Script_Khudawadi;
            elsif C in 16#11300# .. 16#1137F# then
               return RM.Script_Grantha;
            elsif C in 16#11400# .. 16#1147F# then
               return RM.Script_Newa;
            elsif C in 16#11480# .. 16#114DF# then
               return RM.Script_Tirhuta;
            elsif C in 16#11580# .. 16#115FF# then
               return RM.Script_Siddham;
            elsif C in 16#11600# .. 16#1165F# then
               return RM.Script_Modi;
            elsif C in 16#11680# .. 16#116CF# then
               return RM.Script_Takri;
            elsif C in 16#11700# .. 16#1174F# then
               return RM.Script_Ahom;
            elsif C in 16#11800# .. 16#1184F# then
               return RM.Script_Dogra;
            elsif C in 16#118A0# .. 16#118FF# then
               return RM.Script_Warang_Citi;
            elsif C in 16#11900# .. 16#1195F# then
               return RM.Script_Dives_Akuru;
            elsif C in 16#119A0# .. 16#119FF# then
               return RM.Script_Nandinagari;
            elsif C in 16#11A00# .. 16#11A4F# then
               return RM.Script_Zanabazar_Square;
            elsif C in 16#11A50# .. 16#11AAF# then
               return RM.Script_Soyombo;
            elsif C in 16#0E00# .. 16#0E7F# then
               return RM.Script_Thai;
            elsif C in 16#0E80# .. 16#0EFF# then
               return RM.Script_Lao;
            elsif C in 16#1000# .. 16#109F# then
               return RM.Script_Myanmar;
            elsif C in 16#1800# .. 16#18AF# then
               return RM.Script_Mongolian;
            elsif C in 16#1900# .. 16#194F# then
               return RM.Script_Limbu;
            elsif C in 16#1950# .. 16#197F# then
               return RM.Script_Tai_Le;
            elsif C in 16#1980# .. 16#19DF# then
               return RM.Script_New_Tai_Lue;
            elsif C in 16#1780# .. 16#17FF# then
               return RM.Script_Khmer;
            elsif C in 16#1B00# .. 16#1B7F# then
               return RM.Script_Balinese;
            elsif C in 16#1B80# .. 16#1BBF# then
               return RM.Script_Sundanese;
            elsif C in 16#1BC0# .. 16#1BFF# then
               return RM.Script_Batak;
            elsif C in 16#1C00# .. 16#1C4F# then
               return RM.Script_Lepcha;
            elsif C in 16#1C50# .. 16#1C7F# then
               return RM.Script_Ol_Chiki;
            elsif C in 16#A800# .. 16#A82F# then
               return RM.Script_Syloti_Nagri;
            elsif C in 16#A840# .. 16#A87F# then
               return RM.Script_Phags_Pa;
            elsif C in 16#A880# .. 16#A8DF# then
               return RM.Script_Saurashtra;
            elsif C in 16#A900# .. 16#A92F# then
               return RM.Script_Kayah_Li;
            elsif C in 16#A930# .. 16#A95F# then
               return RM.Script_Rejang;
            elsif C in 16#1A00# .. 16#1A1F# then
               return RM.Script_Buginese;
            elsif C in 16#1A20# .. 16#1AAF# then
               return RM.Script_Tai_Tham;
            elsif C in 16#A980# .. 16#A9DF# then
               return RM.Script_Javanese;
            elsif C in 16#AA00# .. 16#AA5F# then
               return RM.Script_Cham;
            elsif C in 16#AA80# .. 16#AADF# then
               return RM.Script_Tai_Viet;
            elsif (C in 16#AAE0# .. 16#AAFF#)
              or else (C in 16#ABC0# .. 16#ABFF#)
            then
               return RM.Script_Meetei_Mayek;
            elsif Is_Hiragana (C) then
               return RM.Script_Hiragana;
            elsif Is_Katakana (C) then
               return RM.Script_Katakana;
            elsif Is_Bopomofo (C) then
               return RM.Script_Bopomofo;
            elsif Is_Hangul (C) then
               return RM.Script_Hangul;
            elsif Is_Yi (C) then
               return RM.Script_Yi;
            elsif Is_Latin (C) then
               return RM.Script_Latin;
            elsif Is_Greek (C) then
               return RM.Script_Greek;
            elsif Is_Cyrillic (C) then
               return RM.Script_Cyrillic;
            elsif Is_Glagolitic (C) then
               return RM.Script_Glagolitic;
            elsif Is_Coptic (C) then
               return RM.Script_Coptic;
            elsif Is_Gothic (C) then
               return RM.Script_Gothic;
            elsif Is_Old_Italic (C) then
               return RM.Script_Old_Italic;
            elsif Is_Old_Persian (C) then
               return RM.Script_Old_Persian;
            elsif Is_Ugaritic (C) then
               return RM.Script_Ugaritic;
            elsif Is_Linear_B (C) then
               return RM.Script_Linear_B;
            elsif Is_Cypriot (C) then
               return RM.Script_Cypriot;
            elsif Is_Egyptian_Hieroglyphs (C) then
               return RM.Script_Egyptian_Hieroglyphs;
            elsif Is_Anatolian_Hieroglyphs (C) then
               return RM.Script_Anatolian_Hieroglyphs;
            elsif Is_Old_Permic (C) then
               return RM.Script_Old_Permic;
            elsif Is_Elbasan (C) then
               return RM.Script_Elbasan;
            elsif Is_Caucasian_Albanian (C) then
               return RM.Script_Caucasian_Albanian;
            elsif Is_Mro (C) then
               return RM.Script_Mro;
            elsif Is_Bassa_Vah (C) then
               return RM.Script_Bassa_Vah;
            elsif Is_Pahawh_Hmong (C) then
               return RM.Script_Pahawh_Hmong;
            elsif Is_Linear_A (C) then
               return RM.Script_Linear_A;
            elsif Is_Phaistos_Disc (C) then
               return RM.Script_Phaistos_Disc;
            elsif Is_Cuneiform (C) then
               return RM.Script_Cuneiform;
            elsif Is_Lycian (C) then
               return RM.Script_Lycian;
            elsif Is_Carian (C) then
               return RM.Script_Carian;
            elsif Is_Old_Turkic (C) then
               return RM.Script_Old_Turkic;
            elsif Is_Medefaidrin (C) then
               return RM.Script_Medefaidrin;
            elsif Is_Toto (C) then
               return RM.Script_Toto;
            elsif Is_Wancho (C) then
               return RM.Script_Wancho;
            elsif Is_Deseret (C) then
               return RM.Script_Deseret;
            elsif Is_Shavian (C) then
               return RM.Script_Shavian;
            elsif Is_Osmanya (C) then
               return RM.Script_Osmanya;
            elsif Is_Osage (C) then
               return RM.Script_Osage;
            elsif Is_Bamum (C) then
               return RM.Script_Bamum;
            elsif Is_Lisu (C) then
               return RM.Script_Lisu;
            elsif Is_Miao (C) then
               return RM.Script_Miao;
            elsif Is_Nushu (C) then
               return RM.Script_Nushu;
            elsif Is_Tangut (C) then
               return RM.Script_Tangut;
            elsif Is_Khitan_Small (C) then
               return RM.Script_Khitan_Small;
            elsif Is_Armenian (C) then
               return RM.Script_Armenian;
            elsif Is_Georgian (C) then
               return RM.Script_Georgian;
            elsif Is_Ethiopic (C) then
               return RM.Script_Ethiopic;
            elsif Is_Cherokee (C) then
               return RM.Script_Cherokee;
            elsif Is_Canadian_Aboriginal (C) then
               return RM.Script_Canadian_Aboriginal;
            elsif Is_Ogham (C) then
               return RM.Script_Ogham;
            elsif Is_Runic (C) then
               return RM.Script_Runic;
            elsif Is_Tifinagh (C) then
               return RM.Script_Tifinagh;
            elsif Is_Vai (C) then
               return RM.Script_Vai;
            elsif Is_CJK (C) then
               return RM.Script_CJK;
            elsif Is_Emoji (C) then
               return RM.Script_Emoji;
            elsif not Is_Common (C) then
               return RM.Script_Unknown;
            end if;
         end;
      end loop;

      return RM.Script_Common;
   end Script_Of;

   procedure Prepare
     (Run    : in out RM.Text_Run_Command;
      Status : out Shape_Status)
   is
      Key       : constant String := Shape_Cache_Key (Run);
      Cached    : constant Shape_Cache_Maps.Cursor := Shape_Cache.Find (Key);
      Kind      : Run_Kind;
      HB_Status : HB.Shape_Status;
   begin
      if Shape_Cache_Maps.Has_Element (Cached) then
         declare
            E : constant Shape_Cache_Entry := Shape_Cache_Maps.Element (Cached);
         begin
            Run.Run_Kind           := E.Run_Kind;
            Run.Shape_Status       := E.Shape_Status;
            Run.Direction          := E.Direction;
            Run.Script             := E.Script;
            Run.Shaped_Glyphs      := E.Shaped_Glyphs;
            Run.Shaped_Glyph_Count := E.Shaped_Glyph_Count;
            Run.Fallback_Glyphs    := E.Fallback_Glyphs;
            Status                 := E.Shape_Status;
            return;
         end;
      end if;

      Kind := Classify (Run);
      Run.Run_Kind := Kind;
      Run.Direction := Direction_Of (Run);
      Run.Script := Script_Of (Run);
      Run.Shaped_Glyphs := (others => <>);
      Run.Shaped_Glyph_Count := 0;

      if Kind = RM.Invalid_Run then
         Run.Shape_Status := RM.Invalid_Run;
         Run.Fallback_Glyphs := True;
         Status := RM.Invalid_Run;
      else
         Ensure_Default_Backend;
         if Backend_Available then
            Shape_With_Configured_Faces (Run, HB_Status);
         else
            HB_Status := HB.Not_Loaded;
         end if;

         if HB_Status = HB.Shaped then
            Run.Shape_Status := RM.Shape_Ok;
            Run.Fallback_Glyphs := False;
            Status := RM.Shape_Ok;
         elsif Requires_Backend (Kind) then
            Run.Shape_Status := RM.Needs_Shaping_Backend;
            Run.Fallback_Glyphs := True;
            Run.Shaped_Glyphs := (others => <>);
            Run.Shaped_Glyph_Count := 0;
            Status := RM.Needs_Shaping_Backend;
         else
            Run.Shape_Status := RM.Shape_Ok;
            Run.Fallback_Glyphs := True;
            Run.Shaped_Glyphs := (others => <>);
            Run.Shaped_Glyph_Count := 0;
            Status := RM.Shape_Ok;
         end if;
      end if;

      --  Memoise the result so the same run (the norm on a screen redrawn every
      --  frame) is not reshaped again. Bounded: once full the cache is dropped
      --  wholesale rather than grown without limit.
      if Natural (Shape_Cache.Length) >= Max_Shape_Cache_Entries then
         Shape_Cache.Clear;
      end if;
      Shape_Cache.Insert
        (Key,
         (Run_Kind           => Run.Run_Kind,
          Shape_Status       => Run.Shape_Status,
          Direction          => Run.Direction,
          Script             => Run.Script,
          Shaped_Glyphs      => Run.Shaped_Glyphs,
          Shaped_Glyph_Count => Run.Shaped_Glyph_Count,
          Fallback_Glyphs    => Run.Fallback_Glyphs));
   end Prepare;
end Terminal.App.Text_Shaper;
