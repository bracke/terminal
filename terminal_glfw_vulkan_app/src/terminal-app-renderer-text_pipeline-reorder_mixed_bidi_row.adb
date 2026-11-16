separate (Terminal.App.Renderer.Text_Pipeline)
procedure Reorder_Mixed_Bidi_Row
  (R     : in out Renderer;
   First : Positive;
   Last  : Natural;
   Right : Float)
is
   package Bidi renames Terminal.App.Bidi;
   use type Bidi.Resolve_Status;
   use type Bidi.Paragraph_Direction;

   Run_Count : constant Natural :=
     (if Last < First then 0 else Last - First + 1);
   Codepoint_Count : Natural := 0;
begin
   if Run_Count = 0 then
      return;
   end if;

   for I in First .. Last loop
      Codepoint_Count := Codepoint_Count
        + Natural (R.Frame_State.Text_Runs (I).Codepoint_Count);
   end loop;
   if Codepoint_Count = 0 then
      return;
   end if;

   declare
      Logical   : Bidi.Codepoint_Array (1 .. Codepoint_Count);
      Positions : Bidi.Visual_Position_Array (1 .. Codepoint_Count);
      Levels    : Bidi.Embedding_Level_Array (1 .. Codepoint_Count);
      Visual    : Bidi.Codepoint_Array (1 .. Codepoint_Count);
      Run_Start : array (1 .. Run_Count) of Positive;
      Visual_To_Run : array (0 .. Codepoint_Count - 1) of Natural :=
        (others => 0);
      Base   : Bidi.Paragraph_Direction;
      Status : Bidi.Resolve_Status;
      Next_Codepoint : Positive := 1;
      Total_Width : Float := 0.0;
      Left : Float := R.Frame_State.Text_Runs (First).X;

      procedure Remove_Accounting (Run : RM.Text_Run_Command) is
      begin
         R.Text_State.Shaped_Glyph_Count :=
           R.Text_State.Shaped_Glyph_Count
           - Natural (Run.Shaped_Glyph_Count);
         if Run.Fallback_Glyphs then
            R.Text_State.Text_Fallback_Run_Count :=
              R.Text_State.Text_Fallback_Run_Count - 1;
         end if;
         if Run.Shape_Status = RM.Needs_Shaping_Backend then
            R.Text_State.Shaping_Fallback_Count :=
              R.Text_State.Shaping_Fallback_Count - 1;
         end if;
      end Remove_Accounting;

      procedure Add_Accounting (Run : RM.Text_Run_Command) is
      begin
         R.Text_State.Shaped_Glyph_Count :=
           R.Text_State.Shaped_Glyph_Count
           + Natural (Run.Shaped_Glyph_Count);
         if Run.Fallback_Glyphs then
            R.Text_State.Text_Fallback_Run_Count :=
              R.Text_State.Text_Fallback_Run_Count + 1;
         end if;
         if Run.Shape_Status = RM.Needs_Shaping_Backend then
            R.Text_State.Shaping_Fallback_Count :=
              R.Text_State.Shaping_Fallback_Count + 1;
         end if;
      end Add_Accounting;
   begin
      for Run_Offset in 1 .. Run_Count loop
         declare
            Run : RM.Text_Run_Command renames
              R.Frame_State.Text_Runs (First + Run_Offset - 1);
         begin
            Run_Start (Run_Offset) := Next_Codepoint;
            Left := Float'Min (Left, Run.X);
            Total_Width := Total_Width
              + Run.Cell_Width * Float (Run.Cell_Span);
            for I in 1 .. Run.Codepoint_Count loop
               Logical (Next_Codepoint) := Run.Codepoints (I);
               if Next_Codepoint < Codepoint_Count then
                  Next_Codepoint := Next_Codepoint + 1;
               end if;
            end loop;
         end;
      end loop;

      Bidi.Resolve
        (Logical, Positions, Levels, Visual, Base, Status);
      if Status /= Bidi.Resolved then
         R.Text_State.Paragraph_Bidi_Fallback_Count :=
           R.Text_State.Paragraph_Bidi_Fallback_Count + 1;
         return;
      end if;

      for Run_Offset in 1 .. Run_Count loop
         Visual_To_Run (Positions (Run_Start (Run_Offset))) := Run_Offset;
      end loop;

      --  FriBidi's visual output includes UAX #9 mirroring.  Neutral runs are
      --  deliberately single-cell boundaries, so a changed representative is
      --  a bracket or similar mirrored glyph and can safely be reshaped.
      for Run_Offset in 1 .. Run_Count loop
         declare
            Run : RM.Text_Run_Command renames
              R.Frame_State.Text_Runs (First + Run_Offset - 1);
            Start : constant Positive := Run_Start (Run_Offset);
            Mirrored : constant Natural := Visual (Positions (Start) + 1);
         begin
            if Run.Direction = RM.Direction_Neutral
              and then Run.Codepoint_Count > 0
              and then Mirrored /= Run.Codepoints (1)
            then
               declare
                  Shape_Status : Terminal.App.Text_Shaper.Shape_Status;
               begin
                  Remove_Accounting (Run);
                  Run.Codepoints (1) := Mirrored;
                  Terminal.App.Text_Shaper.Prepare
                    (R.Text_State.Shaper, Run, Shape_Status);
                  Add_Accounting (Run);
               end;
            end if;
            Run.Direction := Bidi.Direction_For (Levels (Start));
         end;
      end loop;

      declare
         Cursor : Float :=
           (if Base = Bidi.Right_To_Left
            then Right - Total_Width
            else Left);
      begin
         for Visual_Position in Visual_To_Run'Range loop
            if Visual_To_Run (Visual_Position) /= 0 then
               declare
                  Run : RM.Text_Run_Command renames
                    R.Frame_State.Text_Runs
                      (First + Visual_To_Run (Visual_Position) - 1);
               begin
                  Run.X := Cursor;
                  Cursor := Cursor
                    + Run.Cell_Width * Float (Run.Cell_Span);
               end;
            end if;
         end loop;
      end;
   end;
end Reorder_Mixed_Bidi_Row;
