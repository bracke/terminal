with Terminal.App.Render_Model;

package Terminal.App.Theme is
   package RM renames Terminal.App.Render_Model;
   Max_Status_Label_Length : constant := 64;

   type Theme_Name is (Default_Dark, Light, High_Contrast);
   type Palette_16 is array (Natural range 0 .. 15) of RM.Pixel_Color;

   type Theme is record
      Palette    : Palette_16;
      Default_FG : RM.Pixel_Color;
      Default_BG : RM.Pixel_Color;
      Cursor_FG  : RM.Pixel_Color;
      Cursor_BG  : RM.Pixel_Color;
   end record;

   function Built_In (Name : Theme_Name) return Theme;
   function Parse_Name (Text : String; Name : out Theme_Name) return Boolean;
   function Image (Name : Theme_Name) return String;
   function Status_Label (Name : Theme_Name) return String;
end Terminal.App.Theme;
