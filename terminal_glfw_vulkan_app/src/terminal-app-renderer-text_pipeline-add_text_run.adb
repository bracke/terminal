separate (Terminal.App.Renderer.Text_Pipeline)
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
   First_Cell : constant Terminal.Core.Cell_Content :=
     Terminal.Core.Cell_Content_At (Snapshot, Row, First_Col);
   Capacity_Ok : Boolean;
begin
   if R.Frame_State.Text_Runs = null
     or else R.Frame_State.Text_Run_Count >= R.Frame_State.Text_Runs'Length
   then
      Frame_Lifecycle.Ensure_Text_Run_Capacity
        (R, R.Frame_State.Text_Run_Count + 1, Capacity_Ok);
      if not Capacity_Ok then
         R.Frame_State.Frame_Command_Overflowed := True;
         return;
      end if;
   elsif First_Cell.Text.Code_Point = 0 then
      return;
   end if;

   R.Frame_State.Text_Run_Count := R.Frame_State.Text_Run_Count + 1;
   R.Frame_State.Text_Runs (R.Frame_State.Text_Run_Count) :=
     (X               => X,
      Y               => Y,
      Cell_Width      => Width,
      Cell_Height     => Height,
      Cell_Span       => Last_Col - First_Col
        + Style.Cell_Column_Span (First_Cell),
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
         Cell : constant Terminal.Core.Cell_Content :=
           Terminal.Core.Cell_Content_At (Snapshot, Row, Col);
      begin
         if Cell.Kind /= Terminal.Core.Wide_Continuation then
            exit when Count = RM.Max_Text_Run_Codepoints;
            Count := Count + 1;
            R.Frame_State.Text_Runs (R.Frame_State.Text_Run_Count).Codepoints (Count) :=
              Natural (Cell.Text.Code_Point);

            for I in 1 .. Cell.Text.Attachment_Count loop
               exit when Count = RM.Max_Text_Run_Codepoints;
               Count := Count + 1;
               R.Frame_State.Text_Runs (R.Frame_State.Text_Run_Count).Codepoints (Count) :=
                 Natural (Cell.Text.Attachments (I));
            end loop;
         end if;
      end;
   end loop;

   R.Frame_State.Text_Runs (R.Frame_State.Text_Run_Count).Codepoint_Count := Count;
   Terminal.App.Text_Shaper.Prepare
     (R.Text_State.Shaper,
      R.Frame_State.Text_Runs (R.Frame_State.Text_Run_Count),
      Shape_Status);
   R.Text_State.Shaped_Glyph_Count :=
     R.Text_State.Shaped_Glyph_Count
     + Natural (R.Frame_State.Text_Runs (R.Frame_State.Text_Run_Count).Shaped_Glyph_Count);
   if R.Frame_State.Text_Runs (R.Frame_State.Text_Run_Count).Fallback_Glyphs then
      R.Text_State.Text_Fallback_Run_Count := R.Text_State.Text_Fallback_Run_Count + 1;
   end if;
   if Shape_Status = RM.Needs_Shaping_Backend then
      R.Text_State.Shaping_Fallback_Count := R.Text_State.Shaping_Fallback_Count + 1;
   end if;
end Add_Text_Run;
