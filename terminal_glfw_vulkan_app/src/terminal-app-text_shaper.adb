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

   function Is_Bidi_Control_Or_RTL (C : Natural) return Boolean is
     ((C in 16#0590# .. 16#08FF#)
      or else (C in 16#FB1D# .. 16#FDFF#)
      or else (C in 16#FE70# .. 16#FEFF#)
      or else (C in 16#200E# .. 16#200F#)
      or else (C in 16#202A# .. 16#202E#)
      or else (C in 16#2066# .. 16#2069#));

   function Is_Hebrew (C : Natural) return Boolean is
     (C in 16#0590# .. 16#05FF#);

   function Is_Arabic (C : Natural) return Boolean is
     ((C in 16#0600# .. 16#08FF#)
      or else (C in 16#FB50# .. 16#FDFF#)
      or else (C in 16#FE70# .. 16#FEFF#));

   function Is_Complex_Script (C : Natural) return Boolean is
     ((C in 16#0900# .. 16#0D7F#)
      or else (C in 16#0E00# .. 16#0E7F#)
      or else (C in 16#1780# .. 16#17FF#)
      or else (C in 16#A980# .. 16#A9DF#)
      or else (C in 16#AA00# .. 16#AA5F#));

   function Is_Latin (C : Natural) return Boolean is
     ((C in Character'Pos ('A') .. Character'Pos ('Z'))
      or else (C in Character'Pos ('a') .. Character'Pos ('z'))
      or else (C in 16#00C0# .. 16#024F#)
      or else (C in 16#1E00# .. 16#1EFF#));

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
      or else Is_Combining_Or_Format (C));

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
         Status := HB.Shaped;
      else
         Status := Primary_Status;
      end if;
   end Shape_With_Configured_Faces;

   function Direction_Of (Run : RM.Text_Run_Command) return RM.Text_Run_Direction is
   begin
      for I in 1 .. Run.Codepoint_Count loop
         if Is_Bidi_Control_Or_RTL (Run.Codepoints (I)) then
            return RM.Direction_Right_To_Left;
         elsif Is_Latin (Run.Codepoints (I))
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
            elsif Is_Arabic (C) then
               return RM.Script_Arabic;
            elsif C in 16#0900# .. 16#097F# then
               return RM.Script_Devanagari;
            elsif C in 16#0E00# .. 16#0E7F# then
               return RM.Script_Thai;
            elsif C in 16#1780# .. 16#17FF# then
               return RM.Script_Khmer;
            elsif Is_Latin (C) then
               return RM.Script_Latin;
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
            Status := RM.Needs_Shaping_Backend;
         else
            declare
               Advance : constant Float :=
                 Run.Cell_Width / Float (Run.Codepoint_Count);
            begin
               for I in 1 .. Run.Codepoint_Count loop
                  Run.Shaped_Glyphs (I) :=
                    (Glyph_ID     => Run.Codepoints (I),
                     Font_Index   => 0,
                     Codepoint    => Run.Codepoints (I),
                     Source_Index => I,
                     X_Offset     => 0.0,
                     Y_Offset     => 0.0,
                     X_Advance    => Advance,
                     Y_Advance    => 0.0);
               end loop;
            end;
            Run.Shape_Status := RM.Shape_Ok;
            Run.Fallback_Glyphs := False;
            Run.Shaped_Glyph_Count := Run.Codepoint_Count;
            Status := RM.Shape_Ok;
         end if;
      end if;
   end Prepare;
end Terminal.App.Text_Shaper;
