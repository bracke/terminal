package body Terminal.App.Text_Shaper is
   package RM renames Terminal.App.Render_Model;
   use type RM.Text_Run_Kind;

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
   end Prepare;
end Terminal.App.Text_Shaper;
