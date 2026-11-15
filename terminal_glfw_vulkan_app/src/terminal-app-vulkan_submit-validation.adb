with System;

package body Terminal.App.Vulkan_Submit.Validation is
   package RM renames Terminal.App.Render_Model;
   use type RM.Colour_Glyph_Array_Access;
   use type RM.Colour_Glyph_Array_View;
   use type RM.Glyph_Array_Access;
   use type RM.Glyph_Array_View;
   use type RM.Image_Array_Access;
   use type RM.Image_Array_View;
   use type RM.Rectangle_Array_Access;
   use type RM.Rectangle_Array_View;
   use type RM.Text_Run_Array_Access;
   use type RM.Text_Run_Array_View;
   use type System.Address;

   function Finite (Value : Float) return Boolean is
     (Value >= -Float'Last and then Value <= Float'Last);

   function Color_Valid (Value : RM.Pixel_Color) return Boolean is
     (Value.R in 0.0 .. 1.0
      and then Value.G in 0.0 .. 1.0
      and then Value.B in 0.0 .. 1.0
      and then Value.A in 0.0 .. 1.0);

   function Texture_Coordinates_Valid
     (U0, V0, U1, V1 : Float) return Boolean is
     (U0 in 0.0 .. 1.0
      and then V0 in 0.0 .. 1.0
      and then U1 in 0.0 .. 1.0
      and then V1 in 0.0 .. 1.0);

   function Quad_Geometry_Valid
     (X, Y, Width, Height : Float) return Boolean
   is
      Clip_Limit : constant Float := Float'Last / 2.0;
   begin
      return Finite (X)
        and then Finite (Y)
        and then Width >= 0.0
        and then Height >= 0.0
        and then X >= -Clip_Limit
        and then X <= Clip_Limit
        and then Y >= -Clip_Limit
        and then Y <= Clip_Limit
        and then Width <= Clip_Limit - X
        and then Height <= Clip_Limit - Y;
   end Quad_Geometry_Valid;

   function Geometry_Valid (Image : RM.Image_Command) return Boolean is
     (Quad_Geometry_Valid (Image.X, Image.Y, Image.Width, Image.Height)
      and then Image.Width <= Float (Natural'Last)
      and then Image.Height <= Float (Natural'Last)
      and then Texture_Coordinates_Valid
        (Image.U0, Image.V0, Image.U1, Image.V1)
      and then Color_Valid (Image.Tint));

   function Counts_Valid (Frame : RM.Frame_Commands) return Boolean is
     ((Frame.Rectangle_Count = 0
       or else (Frame.Rectangles /= null
                and then Frame.Rectangles'First = 1
                and then Frame.Rectangle_Count <= Frame.Rectangles'Length))
      and then (Frame.Glyph_Count = 0
        or else (Frame.Glyphs /= null
                 and then Frame.Glyphs'First = 1
                 and then Frame.Glyph_Count <= Frame.Glyphs'Length))
      and then (Frame.Colour_Glyph_Count = 0
        or else (Frame.Colour_Glyphs /= null
                 and then Frame.Colour_Glyphs'First = 1
                 and then Frame.Colour_Glyph_Count <= Frame.Colour_Glyphs'Length))
      and then (Frame.Image_Count = 0
        or else (Frame.Images /= null
                 and then Frame.Images'First = 1
                 and then Frame.Image_Count <= Frame.Images'Length))
      and then (Frame.Text_Run_Count = 0
        or else (Frame.Text_Runs /= null
                 and then Frame.Text_Runs'First = 1
                 and then Frame.Text_Run_Count <= Frame.Text_Runs'Length)));

   function Vertex_Capacity
     (Frame : RM.Frame_Commands) return Natural
   is
      Total : Natural := Frame.Rectangle_Count;
   begin
      if Frame.Glyph_Count > Natural'Last - Total then
         return 0;
      end if;
      Total := Total + Frame.Glyph_Count;
      if Frame.Image_Count > Natural'Last - Total then
         return 0;
      end if;
      Total := Total + Frame.Image_Count;
      if Frame.Colour_Glyph_Count > Natural'Last - Total then
         return 0;
      end if;
      Total := Total + Frame.Colour_Glyph_Count;
      if Total > Natural'Last / 6 then
         return 0;
      end if;
      return Total * 6;
   end Vertex_Capacity;

   function Geometry_Valid (Frame : RM.Frame_Commands) return Boolean is
   begin
      for I in 1 .. Frame.Rectangle_Count loop
         if not Quad_Geometry_Valid
           (Frame.Rectangles (I).X, Frame.Rectangles (I).Y,
            Frame.Rectangles (I).Width, Frame.Rectangles (I).Height)
           or else not Color_Valid (Frame.Rectangles (I).Color)
         then
            return False;
         end if;
      end loop;
      for I in 1 .. Frame.Glyph_Count loop
         if not Quad_Geometry_Valid
           (Frame.Glyphs (I).X, Frame.Glyphs (I).Y,
            Frame.Glyphs (I).Width, Frame.Glyphs (I).Height)
           or else not Texture_Coordinates_Valid
             (Frame.Glyphs (I).U0, Frame.Glyphs (I).V0,
              Frame.Glyphs (I).U1, Frame.Glyphs (I).V1)
           or else not Color_Valid (Frame.Glyphs (I).Color)
         then
            return False;
         end if;
      end loop;
      for I in 1 .. Frame.Colour_Glyph_Count loop
         if not Quad_Geometry_Valid
           (Frame.Colour_Glyphs (I).X, Frame.Colour_Glyphs (I).Y,
            Float (Frame.Colour_Glyphs (I).Width),
            Float (Frame.Colour_Glyphs (I).Height))
           or else not Texture_Coordinates_Valid
             (Frame.Colour_Glyphs (I).U0, Frame.Colour_Glyphs (I).V0,
              Frame.Colour_Glyphs (I).U1, Frame.Colour_Glyphs (I).V1)
         then
            return False;
         end if;
      end loop;
      for I in 1 .. Frame.Image_Count loop
         if not Geometry_Valid (Frame.Images (I)) then
            return False;
         end if;
      end loop;
      for I in 1 .. Frame.Text_Run_Count loop
         if not Finite (Frame.Text_Runs (I).X)
           or else not Finite (Frame.Text_Runs (I).Y)
           or else not Finite (Frame.Text_Runs (I).Cell_Width)
           or else Frame.Text_Runs (I).Cell_Width < 0.0
           or else not Finite (Frame.Text_Runs (I).Cell_Height)
           or else Frame.Text_Runs (I).Cell_Height < 0.0
           or else not Color_Valid (Frame.Text_Runs (I).Color)
         then
            return False;
         end if;
         for J in 1 .. Frame.Text_Runs (I).Shaped_Glyph_Count loop
            if not Finite (Frame.Text_Runs (I).Shaped_Glyphs (J).X_Offset)
              or else not Finite (Frame.Text_Runs (I).Shaped_Glyphs (J).Y_Offset)
              or else not Finite (Frame.Text_Runs (I).Shaped_Glyphs (J).X_Advance)
              or else not Finite (Frame.Text_Runs (I).Shaped_Glyphs (J).Y_Advance)
            then
               return False;
            end if;
         end loop;
      end loop;
      return True;
   end Geometry_Valid;

   function Text_Atlas_Valid (Frame : RM.Frame_Commands) return Boolean is
      Required : Natural;
   begin
      if Frame.Glyph_Count = 0 then
         return True;
      elsif Frame.Atlas_Pixels = System.Null_Address
        or else Frame.Atlas_Width = 0
        or else Frame.Atlas_Height = 0
        or else Frame.Atlas_Width > Natural'Last / Frame.Atlas_Height
      then
         return False;
      end if;
      Required := Frame.Atlas_Width * Frame.Atlas_Height;
      return Required <= Max_Image_Atlas_Bytes
        and then Frame.Atlas_Width <= Max_Image_Atlas_Dimension
        and then Frame.Atlas_Height <= Max_Image_Atlas_Dimension
        and then Frame.Atlas_Bytes >= Required;
   end Text_Atlas_Valid;

   function Colour_Atlas_Valid (Frame : RM.Frame_Commands) return Boolean is
      Required : Natural;
   begin
      if Frame.Colour_Glyph_Count = 0 then
         return True;
      elsif Frame.Colour_Sheet_Pixels = System.Null_Address
        or else Frame.Colour_Sheet_Width = 0
        or else Frame.Colour_Sheet_Height = 0
        or else Frame.Colour_Sheet_Width > Max_Image_Atlas_Dimension
        or else Frame.Colour_Sheet_Height > Max_Image_Atlas_Dimension
        or else Frame.Colour_Sheet_Width > Natural'Last / 4
        or else Frame.Colour_Sheet_Height >
          Natural'Last / (Frame.Colour_Sheet_Width * 4)
      then
         return False;
      end if;
      Required := Frame.Colour_Sheet_Width * Frame.Colour_Sheet_Height * 4;
      return Required <= Max_Image_Atlas_Bytes
        and then Frame.Colour_Sheet_Bytes >= Required;
   end Colour_Atlas_Valid;

   function Shaped_Glyphs_Valid (Frame : RM.Frame_Commands) return Boolean is
      Total : Natural := 0;
   begin
      for I in 1 .. Frame.Text_Run_Count loop
         if Natural (Frame.Text_Runs (I).Shaped_Glyph_Count) >
           Natural'Last - Total
         then
            return False;
         end if;
         Total := Total + Natural (Frame.Text_Runs (I).Shaped_Glyph_Count);
      end loop;
      return True;
   end Shaped_Glyphs_Valid;

   function Is_Valid (Frame : RM.Frame_Commands) return Boolean is
     (Frame.Width > 0
      and then Frame.Height > 0
      and then Counts_Valid (Frame)
      and then (Vertex_Capacity (Frame) > 0
                or else (Frame.Rectangle_Count = 0
                         and then Frame.Glyph_Count = 0
                         and then Frame.Image_Count = 0
                         and then Frame.Colour_Glyph_Count = 0))
      and then Geometry_Valid (Frame)
      and then Text_Atlas_Valid (Frame)
      and then Colour_Atlas_Valid (Frame)
      and then Shaped_Glyphs_Valid (Frame));
end Terminal.App.Vulkan_Submit.Validation;
