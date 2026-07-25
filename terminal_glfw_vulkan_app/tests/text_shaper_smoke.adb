with AUnit.Assertions;
with Terminal.App.Fonts;
with Terminal.App.Render_Model;
with Terminal.App.Text_Shaper;

procedure Text_Shaper_Smoke is
   use AUnit.Assertions;
   package RM renames Terminal.App.Render_Model;
   package TS renames Terminal.App.Text_Shaper;
   use type TS.Backend_Status;
   use type RM.Text_Run_Direction;
   use type RM.Text_Run_Kind;
   use type RM.Text_Run_Script;
   use type RM.Text_Run_Shape_Status;

   function Run
     (A : Natural;
      B : Natural := 0;
      C : Natural := 0;
      D : Natural := 0;
      Width : Float := 10.0) return RM.Text_Run_Command
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
         Cell_Width      => Width,
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
         Direction       => RM.Direction_Neutral,
         Script          => RM.Script_Common,
         Shaped_Glyphs   => (others => <>),
         Shaped_Glyph_Count => 0,
         Fallback_Glyphs => True);
   end Run;

   Simple    : RM.Text_Run_Command := Run (Character'Pos ('A'));
   Text      : RM.Text_Run_Command :=
     Run
       (Character'Pos ('a'),
        Character'Pos ('b'),
        Character'Pos ('c'),
        Width => 30.0);
   Ligature  : RM.Text_Run_Command :=
     Run
       (Character'Pos ('f'),
        Character'Pos ('i'),
        Character'Pos ('l'),
        Character'Pos ('e'),
        Width => 40.0);
   Combining : RM.Text_Run_Command := Run (Character'Pos ('e'), 16#0301#);
   Joined    : RM.Text_Run_Command := Run (16#1F469#, 16#200D#, 16#1F468#);
   Modified  : RM.Text_Run_Command := Run (16#1F469#, 16#1F3FD#);
   RTL       : RM.Text_Run_Command := Run (16#05D0#);
   LRM_Text  : RM.Text_Run_Command := Run (16#200E#, Character'Pos ('A'));
   RLM_Text  : RM.Text_Run_Command := Run (16#200F#, Character'Pos ('A'));
   Arabic    : RM.Text_Run_Command := Run (16#0627#);
   Deva      : RM.Text_Run_Command := Run (16#0915#);
   Bengali   : RM.Text_Run_Command := Run (16#0995#);
   Gurmukhi  : RM.Text_Run_Command := Run (16#0A15#);
   Gujarati  : RM.Text_Run_Command := Run (16#0A95#);
   Oriya     : RM.Text_Run_Command := Run (16#0B15#);
   Tamil     : RM.Text_Run_Command := Run (16#0B95#);
   Telugu    : RM.Text_Run_Command := Run (16#0C15#);
   Kannada   : RM.Text_Run_Command := Run (16#0C95#);
   Malayalam : RM.Text_Run_Command := Run (16#0D15#);
   Sinhala   : RM.Text_Run_Command := Run (16#0D9A#);
   Thai      : RM.Text_Run_Command := Run (16#0E01#);
   Lao       : RM.Text_Run_Command := Run (16#0E81#);
   Myanmar   : RM.Text_Run_Command := Run (16#1000#);
   Khmer     : RM.Text_Run_Command := Run (16#1780#);
   Javanese  : RM.Text_Run_Command := Run (16#A984#);
   Cham      : RM.Text_Run_Command := Run (16#AA00#);
   Emoji     : RM.Text_Run_Command := Run (16#1F642#);
   Status    : TS.Shape_Status;
   Backend   : TS.Backend_Status;
   Missing   : RM.Text_Run_Command := Run (16#10FFFF#);
   Backendless : RM.Text_Run_Command := Run (Character'Pos ('Z'));

   procedure Assert_Shaped_Or_Needs_Backend
     (Text   : RM.Text_Run_Command;
      Status : RM.Text_Run_Shape_Status;
      Label  : String)
   is
   begin
      Assert
        (Status in RM.Shape_Ok | RM.Needs_Shaping_Backend,
         Label & " should shape or report explicit backend need");
      Assert
        ((Status = RM.Shape_Ok
          and then not Text.Fallback_Glyphs
          and then Text.Shaped_Glyph_Count > 0)
         or else
           (Status = RM.Needs_Shaping_Backend
            and then Text.Fallback_Glyphs
            and then Text.Shaped_Glyph_Count = 0),
         Label & " shaped/fallback state");
   end Assert_Shaped_Or_Needs_Backend;

   procedure Assert_Complex_Script
     (Text     : in out RM.Text_Run_Command;
      Script   : RM.Text_Run_Script;
      Label    : String)
   is
   begin
      Assert (TS.Classify (Text) = RM.Complex_Script, Label & " class");
      TS.Prepare (Text, Status);
      Assert
        (Text.Direction = RM.Direction_Left_To_Right,
         Label & " direction");
      Assert (Text.Script = Script, Label & " script");
      Assert_Shaped_Or_Needs_Backend (Text, Status, Label);
   end Assert_Complex_Script;
begin
   TS.Configure_Font
     (Path       => Terminal.App.Fonts.Default_Font_Path,
      Pixel_Size => 16,
      Status     => Backend);
   Assert
     (Backend = TS.Backend_Ok and then TS.Backend_Available,
      "HarfBuzz shaping backend should load the default font");

   Assert (TS.Classify (Simple) = RM.Simple_Glyph, "simple glyph class");
   TS.Prepare (Simple, Status);
   Assert (Status = RM.Shape_Ok, "simple glyph status");
   Assert (Simple.Run_Kind = RM.Simple_Glyph, "simple glyph stored class");
   Assert (Simple.Shape_Status = RM.Shape_Ok, "simple glyph stored status");
   Assert
     (Simple.Direction = RM.Direction_Left_To_Right,
      "simple glyph direction");
   Assert (Simple.Script = RM.Script_Latin, "simple glyph script");
   Assert (Simple.Shaped_Glyph_Count = 1, "simple glyph shaped count");
   Assert
     (Simple.Shaped_Glyphs (1).Codepoint = Character'Pos ('A'),
      "simple glyph shaped codepoint");
   Assert
     (Simple.Shaped_Glyphs (1).Glyph_ID > 0,
      "simple glyph should have a real font glyph id");
   Assert
     (Simple.Shaped_Glyphs (1).Font_Index = 0,
      "simple glyph should use primary font index");
   Assert
     (Simple.Shaped_Glyphs (1).Source_Index = 1,
      "simple glyph source index");
   Assert
     (Simple.Shaped_Glyphs (1).X_Advance > 0.0,
      "simple glyph advance");
   Assert (not Simple.Fallback_Glyphs, "simple glyph should not need fallback");

   Assert (TS.Classify (Text) = RM.Simple_Text, "simple text class");
   TS.Prepare (Text, Status);
   Assert (Status = RM.Shape_Ok, "simple text status");
   Assert (Text.Run_Kind = RM.Simple_Text, "simple text stored class");
   Assert (Text.Direction = RM.Direction_Left_To_Right, "simple text direction");
   Assert (Text.Script = RM.Script_Latin, "simple text script");
   Assert (Text.Shaped_Glyph_Count = 3, "simple text shaped count");
   Assert
     (Text.Shaped_Glyphs (2).Codepoint = Character'Pos ('b'),
      "simple text second glyph codepoint");
   Assert
     (Text.Shaped_Glyphs (2).Glyph_ID > 0,
      "simple text second real font glyph id");
   Assert
     (Text.Shaped_Glyphs (2).Font_Index = 0,
      "simple text second primary font index");
   Assert
     (Text.Shaped_Glyphs (2).Source_Index = 2,
      "simple text second source index");
   Assert
     (Text.Shaped_Glyphs (2).X_Advance > 0.0,
      "simple text per-cell advance");
   Assert (not Text.Fallback_Glyphs, "simple text fallback flag");

   Assert
     (TS.Classify (Ligature) = RM.Ligature_Candidate,
      "ligature text class");
   TS.Prepare (Ligature, Status);
   Assert
     (Status = RM.Shape_Ok,
      "ligature text should shape through HarfBuzz");
   Assert
     (Ligature.Shaped_Glyph_Count > 0,
      "ligature text shaped glyph count");
   Assert
     (Ligature.Direction = RM.Direction_Left_To_Right,
      "ligature text direction");
   Assert (Ligature.Script = RM.Script_Latin, "ligature text script");
   Assert (not Ligature.Fallback_Glyphs, "ligature text fallback flag");

   Assert
     (TS.Classify (Combining) = RM.Combining_Cluster,
      "combining cluster class");
   TS.Prepare (Combining, Status);
   Assert
     (Status = RM.Shape_Ok,
      "combining cluster should shape through HarfBuzz");
   Assert
     (Combining.Run_Kind = RM.Combining_Cluster,
      "combining cluster stored class");
   Assert
     (Combining.Shape_Status = RM.Shape_Ok,
      "combining cluster stored status");
   Assert
     (Combining.Direction = RM.Direction_Left_To_Right,
      "combining cluster direction");
   Assert (Combining.Script = RM.Script_Latin, "combining cluster script");
   Assert
     (Combining.Shaped_Glyph_Count > 0,
      "combining cluster shaped glyph count");
   Assert (not Combining.Fallback_Glyphs, "combining cluster fallback");

   Assert
     (TS.Classify (Joined) = RM.Joined_Emoji_Cluster,
      "joined emoji class");
   TS.Prepare (Joined, Status);
   Assert
     (Status in RM.Shape_Ok | RM.Needs_Shaping_Backend,
      "joined emoji should shape or report explicit backend need");
   Assert
     ((Status = RM.Shape_Ok
       and then not Joined.Fallback_Glyphs
       and then Joined.Shaped_Glyph_Count > 0)
      or else
        (Status = RM.Needs_Shaping_Backend
         and then Joined.Fallback_Glyphs
         and then Joined.Shaped_Glyph_Count = 0),
      "joined emoji shaped/fallback state");

   Assert
     (TS.Classify (Modified) = RM.Emoji_Modified_Cluster,
      "emoji modifier class");
   TS.Prepare (Modified, Status);
   Assert
     (Status in RM.Shape_Ok | RM.Needs_Shaping_Backend,
      "modifier should shape or report explicit backend need");

   Assert (TS.Classify (RTL) = RM.Bidi_Text, "RTL class");
   TS.Prepare (RTL, Status);
   Assert_Shaped_Or_Needs_Backend (RTL, Status, "RTL");
   Assert (RTL.Direction = RM.Direction_Right_To_Left, "RTL direction");
   Assert (RTL.Script = RM.Script_Hebrew, "RTL script");

   Assert (TS.Classify (LRM_Text) = RM.Bidi_Text, "LRM text class");
   TS.Prepare (LRM_Text, Status);
   Assert (Status = RM.Shape_Ok, "LRM text should shape through HarfBuzz");
   Assert
     (LRM_Text.Direction = RM.Direction_Left_To_Right,
      "LRM text direction");
   Assert (LRM_Text.Script = RM.Script_Latin, "LRM text script");

   Assert (TS.Classify (RLM_Text) = RM.Bidi_Text, "RLM text class");
   TS.Prepare (RLM_Text, Status);
   Assert (Status = RM.Shape_Ok, "RLM text should shape through HarfBuzz");
   Assert
     (RLM_Text.Direction = RM.Direction_Right_To_Left,
      "RLM text direction");
   Assert (RLM_Text.Script = RM.Script_Latin, "RLM text script");

   Assert (TS.Classify (Arabic) = RM.Bidi_Text, "Arabic class");
   TS.Prepare (Arabic, Status);
   Assert_Shaped_Or_Needs_Backend (Arabic, Status, "Arabic");
   Assert
     (Arabic.Direction = RM.Direction_Right_To_Left,
      "Arabic direction");
   Assert (Arabic.Script = RM.Script_Arabic, "Arabic script");

   Assert_Complex_Script (Deva, RM.Script_Devanagari, "Devanagari");
   Assert_Complex_Script (Bengali, RM.Script_Bengali, "Bengali");
   Assert_Complex_Script (Gurmukhi, RM.Script_Gurmukhi, "Gurmukhi");
   Assert_Complex_Script (Gujarati, RM.Script_Gujarati, "Gujarati");
   Assert_Complex_Script (Oriya, RM.Script_Oriya, "Oriya");
   Assert_Complex_Script (Tamil, RM.Script_Tamil, "Tamil");
   Assert_Complex_Script (Telugu, RM.Script_Telugu, "Telugu");
   Assert_Complex_Script (Kannada, RM.Script_Kannada, "Kannada");
   Assert_Complex_Script (Malayalam, RM.Script_Malayalam, "Malayalam");
   Assert_Complex_Script (Sinhala, RM.Script_Sinhala, "Sinhala");
   Assert_Complex_Script (Thai, RM.Script_Thai, "Thai");
   Assert_Complex_Script (Lao, RM.Script_Lao, "Lao");
   Assert_Complex_Script (Myanmar, RM.Script_Myanmar, "Myanmar");
   Assert_Complex_Script (Khmer, RM.Script_Khmer, "Khmer");
   Assert_Complex_Script (Javanese, RM.Script_Javanese, "Javanese");
   Assert_Complex_Script (Cham, RM.Script_Cham, "Cham");

   Assert (TS.Classify (Emoji) = RM.Simple_Glyph, "emoji scalar class");
   TS.Prepare (Emoji, Status);
   Assert (Status = RM.Shape_Ok, "emoji scalar status");
   Assert (Emoji.Script = RM.Script_Emoji, "emoji scalar script");

   TS.Prepare (Missing, Status);
   Assert
     (Status = RM.Shape_Ok,
      "simple missing scalar should fall back to codepoint rendering");
   Assert
     (Missing.Fallback_Glyphs,
      "simple missing scalar should use renderer fallback");
   Assert
     (Missing.Shaped_Glyph_Count = 0,
      "simple missing scalar should not expose notdef as shaped glyph");

   TS.Configure_Font ("", 16, Backend);
   Assert
     (Backend = TS.Backend_Unavailable,
      "empty shaping font path should disable backend");
   TS.Prepare (Backendless, Status);
   Assert
     (Status = RM.Shape_Ok,
      "simple text should still be renderable without shaping backend");
   Assert
     (Backendless.Fallback_Glyphs,
      "backendless simple text should use renderer codepoint fallback");
   Assert
     (Backendless.Shaped_Glyph_Count = 0,
      "backendless simple text should not fabricate glyph indexes");
end Text_Shaper_Smoke;
