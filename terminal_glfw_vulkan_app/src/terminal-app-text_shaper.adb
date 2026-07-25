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

   function Is_Complex_Script (C : Natural) return Boolean is
     ((C in 16#0900# .. 16#0D7F#)
      or else (C in 16#0E00# .. 16#0E7F#)
      or else (C in 16#1780# .. 16#17FF#)
      or else (C in 16#A980# .. 16#A9DF#)
      or else (C in 16#AA00# .. 16#AA5F#));

   function Is_ASCII_Letter (C : Natural) return Boolean is
     ((C in Character'Pos ('A') .. Character'Pos ('Z'))
      or else (C in Character'Pos ('a') .. Character'Pos ('z')));

   function Classify (Run : RM.Text_Run_Command) return Run_Kind is
      Saw_Combining : Boolean := False;
      Saw_Letter    : Natural := 0;
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
            elsif Is_ASCII_Letter (C) then
               Saw_Letter := Saw_Letter + 1;
            end if;
         end;
      end loop;

      if Saw_Combining then
         return RM.Combining_Cluster;
      elsif Saw_Letter >= 2 then
         return RM.Ligature_Candidate;
      else
         return RM.Simple_Glyph;
      end if;
   end Classify;

   function Requires_Backend (Kind : Run_Kind) return Boolean is
     (Kind /= RM.Simple_Glyph);

   procedure Prepare
     (Run    : in out RM.Text_Run_Command;
      Status : out Shape_Status)
   is
      Kind : constant Run_Kind := Classify (Run);
   begin
      Run.Run_Kind := Kind;
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
         Run.Shape_Status := RM.Shape_Ok;
         Run.Fallback_Glyphs := False;
         Run.Shaped_Glyph_Count := 1;
         Run.Shaped_Glyphs (1) :=
           (Glyph_ID     => 0,
            Codepoint    => Run.Codepoints (1),
            Source_Index => 1,
            X_Offset     => 0.0,
            Y_Offset     => 0.0,
            X_Advance    => Run.Cell_Width,
            Y_Advance    => 0.0);
         Status := RM.Shape_Ok;
      end if;
   end Prepare;
end Terminal.App.Text_Shaper;
