separate (Terminal.App.Renderer)
procedure Add_Text_Run
  (R       : in out Renderer;
   Snapshot : Terminal.Core.Render_Snapshot;
   Row     : Positive;
   First_Col : Positive;
   Last_Col  : Positive;
   X       : Float;
   Y       : Float;
   Width   : Float;
   Height  : Float;
   Color   : RM.Pixel_Color)
is
   Count : RM.Text_Run_Codepoint_Count := 0;
   Shape_Status : Terminal.App.Text_Shaper.Shape_Status;
   First_Cell : constant Terminal.Core.Cell :=
     Terminal.Core.Cell_At (Snapshot, Row, First_Col);
begin
   if R.Text_Runs = null
     or else R.Text_Run_Count >= R.Text_Runs'Length
   then
      R.Frame_Command_Overflowed := True;
      return;
   elsif First_Cell.Text.Code_Point = 0 then
      return;
   end if;

   R.Text_Run_Count := R.Text_Run_Count + 1;
   R.Text_Runs (R.Text_Run_Count) :=
     (X               => X,
      Y               => Y,
      Cell_Width      => Width,
      Cell_Height     => Height,
      Cell_Span       => Last_Col - First_Col + Cell_Column_Span (First_Cell),
      Color           => Color,
      Bold            => First_Cell.Style.Bold,
      Italic          => First_Cell.Style.Italic,
      Codepoints      => (others => 0),
      Codepoint_Count => 0,
      Run_Kind        => RM.Invalid_Run,
      Shape_Status    => RM.Invalid_Run,
      Direction       => RM.Direction_Neutral,
      Script          => RM.Script_Common,
      Shaped_Glyphs   => (others => <>),
      Shaped_Glyph_Count => 0,
      Fallback_Glyphs => True);

   for Col in First_Col .. Last_Col loop
      declare
         Cell : constant Terminal.Core.Cell :=
           Terminal.Core.Cell_At (Snapshot, Row, Col);
      begin
         if Cell.Kind /= Terminal.Core.Wide_Continuation then
            exit when Count = RM.Max_Text_Run_Codepoints;
            Count := Count + 1;
            R.Text_Runs (R.Text_Run_Count).Codepoints (Count) :=
              Natural (Cell.Text.Code_Point);

            for I in 1 .. Cell.Text.Attachment_Count loop
               exit when Count = RM.Max_Text_Run_Codepoints;
               Count := Count + 1;
               R.Text_Runs (R.Text_Run_Count).Codepoints (Count) :=
                 Natural (Cell.Text.Attachments (I));
            end loop;
         end if;
      end;
   end loop;

   R.Text_Runs (R.Text_Run_Count).Codepoint_Count := Count;
   Terminal.App.Text_Shaper.Prepare
     (R.Text_Runs (R.Text_Run_Count),
      Shape_Status);
   R.Shaped_Glyph_Count :=
     R.Shaped_Glyph_Count
     + Natural (R.Text_Runs (R.Text_Run_Count).Shaped_Glyph_Count);
   if R.Text_Runs (R.Text_Run_Count).Fallback_Glyphs then
      R.Text_Fallback_Run_Count := R.Text_Fallback_Run_Count + 1;
   end if;
   if Shape_Status = RM.Needs_Shaping_Backend then
      R.Shaping_Fallback_Count := R.Shaping_Fallback_Count + 1;
   end if;
end Add_Text_Run;
