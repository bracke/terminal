private package Terminal.App.Graphics.PNG_Types is
   type PNG_Info is record
      Width      : Natural := 0;
      Height     : Natural := 0;
      Color_Type : Natural := 0;
   end record;
   type PNG_Palette is array (Natural range 0 .. 255) of Sixel_Color;
end Terminal.App.Graphics.PNG_Types;
