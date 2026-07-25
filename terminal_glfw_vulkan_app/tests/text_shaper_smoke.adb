with AUnit.Assertions;

with Terminal.App.Render_Model;
with Terminal.App.Text_Shaper;

procedure Text_Shaper_Smoke is
   use AUnit.Assertions;
   package RM renames Terminal.App.Render_Model;
   package TS renames Terminal.App.Text_Shaper;
   use type RM.Text_Run_Kind;
   use type RM.Text_Run_Shape_Status;

   function Run
     (A : Natural;
      B : Natural := 0;
      C : Natural := 0;
      D : Natural := 0) return RM.Text_Run_Command
   is
      Count : RM.Text_Run_Codepoint_Count := 1;
   begin
      if B /= 0 then
         Count := Count + 1;
      end if;
      if C /= 0 then
         Count := Count + 1;
      end if;
      if D /= 0 then
         Count := Count + 1;
      end if;

      return
        (X               => 0.0,
         Y               => 0.0,
         Cell_Width      => 10.0,
         Cell_Height     => 20.0,
         Cell_Span       => 1,
         Color           => (R => 1.0, G => 1.0, B => 1.0, A => 1.0),
         Bold            => False,
         Italic          => False,
         Codepoints      =>
           [1 => A,
            2 => B,
            3 => C,
            4 => D,
            others => 0],
         Codepoint_Count => Count,
         Run_Kind        => RM.Invalid_Run,
         Shape_Status    => RM.Invalid_Run,
         Fallback_Glyphs => True);
   end Run;

   Simple    : RM.Text_Run_Command := Run (Character'Pos ('A'));
   Combining : RM.Text_Run_Command := Run (Character'Pos ('e'), 16#0301#);
   Joined    : RM.Text_Run_Command := Run (16#1F469#, 16#200D#, 16#1F468#);
   Modified  : RM.Text_Run_Command := Run (16#1F469#, 16#1F3FD#);
   RTL       : RM.Text_Run_Command := Run (16#05D0#);
   Deva      : RM.Text_Run_Command := Run (16#0915#);
   Status    : TS.Shape_Status;
begin
   Assert (TS.Classify (Simple) = RM.Simple_Glyph, "simple glyph class");
   TS.Prepare (Simple, Status);
   Assert (Status = RM.Shape_Ok, "simple glyph status");
   Assert (Simple.Run_Kind = RM.Simple_Glyph, "simple glyph stored class");
   Assert (Simple.Shape_Status = RM.Shape_Ok, "simple glyph stored status");
   Assert (not Simple.Fallback_Glyphs, "simple glyph should not need fallback");

   Assert
     (TS.Classify (Combining) = RM.Combining_Cluster,
      "combining cluster class");
   TS.Prepare (Combining, Status);
   Assert
     (Status = RM.Needs_Shaping_Backend,
      "combining cluster needs shaping");
   Assert
     (Combining.Run_Kind = RM.Combining_Cluster,
      "combining cluster stored class");
   Assert
     (Combining.Shape_Status = RM.Needs_Shaping_Backend,
      "combining cluster stored status");
   Assert (Combining.Fallback_Glyphs, "combining cluster fallback");

   Assert
     (TS.Classify (Joined) = RM.Joined_Emoji_Cluster,
      "joined emoji class");
   TS.Prepare (Joined, Status);
   Assert (Status = RM.Needs_Shaping_Backend, "joined emoji needs shaping");

   Assert
     (TS.Classify (Modified) = RM.Emoji_Modified_Cluster,
      "emoji modifier class");
   TS.Prepare (Modified, Status);
   Assert (Status = RM.Needs_Shaping_Backend, "modifier needs shaping");

   Assert (TS.Classify (RTL) = RM.Bidi_Text, "RTL class");
   TS.Prepare (RTL, Status);
   Assert (Status = RM.Needs_Shaping_Backend, "RTL needs shaping");

   Assert (TS.Classify (Deva) = RM.Complex_Script, "complex script class");
   TS.Prepare (Deva, Status);
   Assert (Status = RM.Needs_Shaping_Backend, "complex script needs shaping");
end Text_Shaper_Smoke;
