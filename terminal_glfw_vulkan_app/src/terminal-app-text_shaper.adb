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
            Status := Backend_Ok;
         when HB.Invalid_Path =>
            Status := Backend_Unavailable;
         when HB.Load_Failed =>
            Status := Backend_Load_Failed;
      end case;
   end Add_Fallback_Font;

   function Backend_Available return Boolean is
     (Default_Face_Loaded and then HB.Is_Loaded (Default_Face));

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
      or else (C in 16#FE70# .. 16#FEFF#));

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

   function Is_Complex_Script (C : Natural) return Boolean is
     ((C in 16#0900# .. 16#0D7F#)
      or else (C in 16#0D80# .. 16#0DFF#)
      or else (C in 16#0F00# .. 16#0FFF#)
      or else (C in 16#0E00# .. 16#0E7F#)
      or else (C in 16#0E80# .. 16#0EFF#)
      or else (C in 16#1000# .. 16#109F#)
      or else (C in 16#1800# .. 16#18AF#)
      or else (C in 16#1A00# .. 16#1AAF#)
      or else (C in 16#1B00# .. 16#1BFF#)
      or else (C in 16#1C00# .. 16#1C7F#)
      or else (C in 16#1780# .. 16#17FF#)
      or else (C in 16#A980# .. 16#A9DF#)
      or else (C in 16#AA00# .. 16#AA5F#));

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
            elsif C in 16#0E00# .. 16#0E7F# then
               return RM.Script_Thai;
            elsif C in 16#0E80# .. 16#0EFF# then
               return RM.Script_Lao;
            elsif C in 16#1000# .. 16#109F# then
               return RM.Script_Myanmar;
            elsif C in 16#1800# .. 16#18AF# then
               return RM.Script_Mongolian;
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
            elsif C in 16#1A00# .. 16#1A1F# then
               return RM.Script_Buginese;
            elsif C in 16#1A20# .. 16#1AAF# then
               return RM.Script_Tai_Tham;
            elsif C in 16#A980# .. 16#A9DF# then
               return RM.Script_Javanese;
            elsif C in 16#AA00# .. 16#AA5F# then
               return RM.Script_Cham;
            elsif Is_Latin (C) then
               return RM.Script_Latin;
            elsif Is_Greek (C) then
               return RM.Script_Greek;
            elsif Is_Cyrillic (C) then
               return RM.Script_Cyrillic;
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
      Kind : constant Run_Kind := Classify (Run);
      HB_Status : HB.Shape_Status;
   begin
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
   end Prepare;
end Terminal.App.Text_Shaper;
