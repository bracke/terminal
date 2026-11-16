with Terminal.App.Render_Model;

package Terminal.App.Theme is
   package RM renames Terminal.App.Render_Model;
   Max_Status_Label_Length : constant := 64;

   type Theme_Name is
     (Default_Dark, Light, High_Contrast, Solarized_Dark, Dracula,
      Gruvbox_Dark, Nord, One_Dark);
   type Palette_16 is array (Natural range 0 .. 15) of RM.Pixel_Color;
   type Tab_Bar_Mode is (Tab_Auto, Tab_Always, Tab_Never);
   type Tab_Style is record
      Bar_Background : RM.Pixel_Color := (0.08, 0.09, 0.10, 1.0);
      Active_Background : RM.Pixel_Color := (0.18, 0.25, 0.34, 1.0);
      Inactive_Background : RM.Pixel_Color := (0.12, 0.13, 0.15, 1.0);
   end record;
   Default_Tab_Style : constant Tab_Style := (others => <>);

   type Theme is record
      Palette    : Palette_16;
      Default_FG : RM.Pixel_Color;
      Default_BG : RM.Pixel_Color;
      Cursor_FG  : RM.Pixel_Color;
      Cursor_BG  : RM.Pixel_Color;
      Selection_FG : RM.Pixel_Color;
      Selection_BG : RM.Pixel_Color;
      URL_Highlight : RM.Pixel_Color;
   end record;

   function Built_In (Name : Theme_Name) return Theme;
   function Parse_Name (Text : String; Name : out Theme_Name) return Boolean;
   function Image (Name : Theme_Name) return String;
   function Status_Label (Name : Theme_Name) return String;
   function Parse_Tab_Bar_Mode
     (Text : String; Mode : out Tab_Bar_Mode) return Boolean;
   function Image (Mode : Tab_Bar_Mode) return String;
end Terminal.App.Theme;
