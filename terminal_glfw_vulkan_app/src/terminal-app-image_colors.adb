package body Terminal.App.Image_Colors is
   package RM renames Terminal.App.Render_Model;
   use type RM.Image_Data_Access;
   use type RM.Image_Data_View;

   function XTerm_Cube_Component (Value : Natural) return Float is
     (if Value = 0 then 0.0 else Float (55 + Value * 40) / 255.0);

   function XTerm_Indexed
     (Theme : Terminal.App.Theme.Theme;
      Index : Natural) return RM.Pixel_Color
   is
   begin
      if Index <= Theme.Palette'Last then
         return Theme.Palette (Index);
      elsif Index <= 231 then
         declare
            Offset : constant Natural := Index - 16;
         begin
            return
              (R => XTerm_Cube_Component (Offset / 36),
               G => XTerm_Cube_Component ((Offset / 6) mod 6),
               B => XTerm_Cube_Component (Offset mod 6),
               A => 1.0);
         end;
      else
         declare
            Level : constant Float := Float (8 + (Index - 232) * 10) / 255.0;
         begin
            return (Level, Level, Level, 1.0);
         end;
      end if;
   end XTerm_Indexed;

   function Kitty_Indexed
     (Theme : Terminal.App.Theme.Theme;
      Index : Natural) return RM.Pixel_Color
   is
   begin
      case Index is
         when 0 .. 247 =>
            return XTerm_Indexed (Theme, Index);
         when 248 =>
            return Theme.Default_BG;
         when 249 | 255 =>
            return Theme.Default_FG;
         when 250 =>
            return Theme.Selection_BG;
         when 251 =>
            return Theme.Selection_FG;
         when 252 =>
            return Theme.Cursor_BG;
         when 253 =>
            return Theme.Cursor_FG;
         when 254 =>
            return Theme.URL_Highlight;
         when others =>
            return Theme.Default_FG;
      end case;
   end Kitty_Indexed;

   function Color_Byte
     (Value : Float) return Terminal.Common.Bytes.Byte
   is
      Scaled : constant Float :=
        Float'Max (0.0, Float'Min (1.0, Value)) * 255.0;
   begin
      return Terminal.Common.Bytes.Byte (Natural (Scaled));
   end Color_Byte;

   function Expand_Kitty_Indexed
     (Theme          : Terminal.App.Theme.Theme;
      Indexed_Format : Natural;
      Pixel_Width    : Natural;
      Pixel_Height   : Natural;
      Source         : RM.Image_Data_View;
      Target         : RM.Image_Data_Access) return Boolean
   is
      Source_BPP : constant Natural :=
        (if Indexed_Format = 8 then 1
         elsif Indexed_Format = 16 then 2
         else 0);
      Pixels : Natural := 0;
   begin
      if Source_BPP = 0
        or else Pixel_Width = 0
        or else Pixel_Height = 0
        or else Pixel_Width > Natural'Last / Pixel_Height
        or else Source = null
        or else Target = null
      then
         return False;
      end if;
      Pixels := Pixel_Width * Pixel_Height;
      if Pixels > Natural'Last / 4
        or else Pixels > Natural'Last / Source_BPP
        or else Source'Length < Pixels * Source_BPP
        or else Target'Length < Pixels * 4
      then
         return False;
      end if;

      for Pixel in 0 .. Pixels - 1 loop
         declare
            Source_At : constant Positive :=
              Source'First + Pixel * Source_BPP;
            Target_At : constant Positive := Target'First + Pixel * 4;
            Color : constant RM.Pixel_Color :=
              Kitty_Indexed (Theme, Natural (Source (Source_At)));
            Alpha : constant Terminal.Common.Bytes.Byte :=
              (if Indexed_Format = 16 then Source (Source_At + 1) else 255);
         begin
            Target (Target_At) := Color_Byte (Color.R);
            Target (Target_At + 1) := Color_Byte (Color.G);
            Target (Target_At + 2) := Color_Byte (Color.B);
            Target (Target_At + 3) := Alpha;
         end;
      end loop;
      return True;
   end Expand_Kitty_Indexed;
end Terminal.App.Image_Colors;
