with Terminal.App.Renderer.Frame_Lifecycle;

package body Terminal.App.Renderer.Drawing_Commands is
   package RM renames Terminal.App.Render_Model;
   use type RM.Rectangle_Array_Access;
   use type RM.Glyph_Array_Access;
   use type RM.Colour_Glyph_Array_Access;
   use type Textrender.Status_Code;

   procedure Add_Rectangle
     (R      : in out Renderer;
      X      : Float;
      Y      : Float;
      Width  : Float;
      Height : Float;
      Color  : RM.Pixel_Color;
      Layer  : RM.Rectangle_Layer := RM.Rectangle_Foreground) is
      Capacity_Ok : Boolean;
   begin
      if R.Frame_State.Rectangles = null
        or else R.Frame_State.Rectangle_Count >=
          R.Frame_State.Rectangles'Length
      then
         Frame_Lifecycle.Ensure_Rectangle_Capacity
           (R, R.Frame_State.Rectangle_Count + 1, Capacity_Ok);
         if not Capacity_Ok then
            R.Frame_State.Frame_Command_Overflowed := True;
            return;
         end if;
      end if;
      R.Frame_State.Rectangle_Count := R.Frame_State.Rectangle_Count + 1;
      R.Frame_State.Rectangles (R.Frame_State.Rectangle_Count) :=
        (X => X, Y => Y, Width => Width, Height => Height,
         Color => Color, Layer => Layer);
   end Add_Rectangle;

   procedure Add_Glyph
     (R         : in out Renderer;
      Placement : Textrender.Glyph_Placement;
      Metric    : Textrender.Glyph_Metric;
      Color     : RM.Pixel_Color;
      Codepoint : Natural) is
      Capacity_Ok : Boolean;
   begin
      if R.Frame_State.Glyphs = null
        or else R.Frame_State.Glyph_Count >= R.Frame_State.Glyphs'Length
      then
         Frame_Lifecycle.Ensure_Glyph_Capacity
           (R, R.Frame_State.Glyph_Count + 1, Capacity_Ok);
         if not Capacity_Ok then
            R.Frame_State.Frame_Command_Overflowed := True;
            return;
         end if;
      end if;
      R.Frame_State.Glyph_Count := R.Frame_State.Glyph_Count + 1;
      R.Frame_State.Glyphs (R.Frame_State.Glyph_Count) :=
        (X => Placement.X, Y => Placement.Y,
         Width => Float (Metric.W), Height => Float (Metric.H),
         U0 => Metric.U0, V0 => Metric.V0, U1 => Metric.U1, V1 => Metric.V1,
         Color => Color, Codepoint => Codepoint);
   end Add_Glyph;

   procedure Add_Underline
     (R      : in out Renderer;
      Kind   : Terminal.Core.Underline_Style;
      X      : Float;
      Y      : Float;
      Width  : Float;
      Color  : RM.Pixel_Color)
   is
      Base_Y : constant Float := Y + Float (R.Text_State.CH - 2);
      Step   : constant Float := 4.0;
      Dash   : constant Float := 5.0;
      Pos    : Float := X;
      Index  : Natural := 0;
   begin
      case Kind is
         when Terminal.Core.Underline_Single =>
            Add_Rectangle (R, X, Base_Y, Width, 1.0, Color);
         when Terminal.Core.Underline_Double =>
            Add_Rectangle (R, X, Base_Y - 2.0, Width, 1.0, Color);
            Add_Rectangle (R, X, Base_Y, Width, 1.0, Color);
         when Terminal.Core.Underline_Curly =>
            while Pos < X + Width loop
               Add_Rectangle
                 (R, Pos, Base_Y - Float (Index mod 2),
                  Float'Min (2.0, X + Width - Pos), 1.0, Color);
               Pos := Pos + 2.0;
               Index := Index + 1;
            end loop;
         when Terminal.Core.Underline_Dotted =>
            while Pos < X + Width loop
               Add_Rectangle
                 (R, Pos, Base_Y, Float'Min (1.0, X + Width - Pos),
                  1.0, Color);
               Pos := Pos + Step;
            end loop;
         when Terminal.Core.Underline_Dashed =>
            while Pos < X + Width loop
               Add_Rectangle
                 (R, Pos, Base_Y, Float'Min (Dash, X + Width - Pos),
                  1.0, Color);
               Pos := Pos + Dash + 3.0;
            end loop;
      end case;
   end Add_Underline;

   function Add_Colour_Glyph
     (R         : in out Renderer;
      Codepoint : Terminal.Common.Code_Point;
      X         : Float;
      Y         : Float) return Boolean
   is
      Code   : constant Textrender.Codepoint :=
        Textrender.Codepoint (Natural (Codepoint));
      Colour : Textrender.Colour_Glyph;
      Capacity_Ok : Boolean;
   begin
      if not R.Text_State.Text_Loaded
        or else not Textrender.Has_Colour_Glyph (R.Text_State.Text, Code)
      then
         return False;
      elsif Textrender.Get_Colour_Glyph
        (R.Text_State.Text, Code, Colour) /= Textrender.Success
        or else Colour.Width = 0
        or else Colour.Height = 0
      then
         return False;
      end if;

      if R.Frame_State.Colour_Glyphs = null
        or else R.Frame_State.Colour_Glyph_Count >=
          R.Frame_State.Colour_Glyphs'Length
      then
         Frame_Lifecycle.Ensure_Colour_Capacity
           (R, R.Frame_State.Colour_Glyph_Count + 1, Capacity_Ok);
         if not Capacity_Ok then
            R.Frame_State.Frame_Command_Overflowed := True;
            return False;
         end if;
      end if;

      R.Frame_State.Colour_Glyph_Count :=
        R.Frame_State.Colour_Glyph_Count + 1;
      declare
         Tile : RM.Colour_Glyph_Command renames
           R.Frame_State.Colour_Glyphs (R.Frame_State.Colour_Glyph_Count);
      begin
         Tile :=
           (X      => X,
            Y      => Y + Textrender.Ascent (R.Text_State.Text)
              - Colour.Bearing_Y,
            Width  => Colour.Width,
            Height => Colour.Height,
            U0     => Colour.U0,
            V0     => Colour.V0,
            U1     => Colour.U1,
            V1     => Colour.V1);
      end;
      return True;
   end Add_Colour_Glyph;
end Terminal.App.Renderer.Drawing_Commands;
