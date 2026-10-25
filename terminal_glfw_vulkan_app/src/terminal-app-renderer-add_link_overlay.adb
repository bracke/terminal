separate (Terminal.App.Renderer)
procedure Add_Link_Overlay
  (R        : in out Renderer;
   Snapshot : Terminal.Core.Render_Snapshot;
   Status   : out Render_Status)
is
   Label : constant String :=
     Terminal.App.Hyperlinks.Status_Label (R.Hovered_Link);
   Count : constant Natural :=
     Natural'Min
       (Natural'Min (Label'Length, Max_Link_Overlay_Chars),
        Snapshot.Cols);
   X : constant Float := Float (Origin_X (R));
   Y : constant Float :=
     Float (Origin_Y (R) + (Snapshot.Rows - 1) * R.CH);
begin
   if Count = 0 then
      Status := Ok;
      return;
   end if;

   Add_Rectangle
     (R,
      X      => X,
      Y      => Y,
      Width  => Float (Count * R.CW),
      Height => Float (R.CH),
      Color  => (R => 0.0, G => 0.0, B => 0.0, A => 0.92));

   for Offset in 0 .. Count - 1 loop
      Draw_Glyph
        (R,
         Codepoint =>
           Terminal.Common.Code_Point
             (Character'Pos (Label (Label'First + Offset))),
         X      => X + Float (Offset * R.CW),
         Y      => Y,
         Color  => R.Color_Theme.Default_FG,
         Bold   => False,
         Italic => False,
         Status => Status);
      if Status /= Ok then
         return;
      end if;
   end loop;

   Status := Ok;
end Add_Link_Overlay;
