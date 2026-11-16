with Ada.Characters.Handling;

package body Terminal.App.Theme is
   function Parse_Tab_Bar_Mode
     (Text : String; Mode : out Tab_Bar_Mode) return Boolean
   is
      Lower : constant String := Ada.Characters.Handling.To_Lower (Text);
   begin
      if Lower = "auto" then Mode := Tab_Auto;
      elsif Lower = "always" then Mode := Tab_Always;
      elsif Lower = "never" or else Lower = "hidden" then Mode := Tab_Never;
      else return False;
      end if;
      return True;
   end Parse_Tab_Bar_Mode;

   function Image (Mode : Tab_Bar_Mode) return String is
     (case Mode is
        when Tab_Auto => "auto",
        when Tab_Always => "always",
        when Tab_Never => "never");

   function Built_In (Name : Theme_Name) return Theme is
   begin
      case Name is
         when Default_Dark =>
            return
              (Palette =>
                 [0  => (0.05, 0.05, 0.06, 1.0),
                  1  => (0.80, 0.18, 0.18, 1.0),
                  2  => (0.22, 0.68, 0.30, 1.0),
                  3  => (0.78, 0.62, 0.22, 1.0),
                  4  => (0.25, 0.45, 0.86, 1.0),
                  5  => (0.70, 0.36, 0.80, 1.0),
                  6  => (0.22, 0.67, 0.72, 1.0),
                  7  => (0.78, 0.80, 0.82, 1.0),
                  8  => (0.36, 0.38, 0.40, 1.0),
                  9  => (1.00, 0.36, 0.32, 1.0),
                  10 => (0.45, 0.88, 0.45, 1.0),
                  11 => (0.95, 0.78, 0.30, 1.0),
                  12 => (0.45, 0.62, 1.00, 1.0),
                  13 => (0.88, 0.50, 1.00, 1.0),
                  14 => (0.38, 0.88, 0.92, 1.0),
                  15 => (0.95, 0.95, 0.95, 1.0)],
               Default_FG => (0.86, 0.88, 0.88, 1.0),
               Default_BG => (0.03, 0.035, 0.04, 1.0),
               Cursor_BG  => (0.86, 0.88, 0.88, 1.0),
               Cursor_FG  => (0.03, 0.035, 0.04, 1.0),
               Selection_BG => (0.25, 0.45, 0.86, 1.0),
               Selection_FG => (0.95, 0.95, 0.95, 1.0),
               URL_Highlight => (0.38, 0.88, 0.92, 1.0));
         when Light =>
            return
              (Palette =>
                 [0  => (0.14, 0.15, 0.16, 1.0),
                  1  => (0.75, 0.10, 0.13, 1.0),
                  2  => (0.05, 0.52, 0.20, 1.0),
                  3  => (0.62, 0.44, 0.02, 1.0),
                  4  => (0.10, 0.32, 0.78, 1.0),
                  5  => (0.55, 0.20, 0.70, 1.0),
                  6  => (0.00, 0.48, 0.58, 1.0),
                  7  => (0.84, 0.85, 0.86, 1.0),
                  8  => (0.45, 0.47, 0.49, 1.0),
                  9  => (0.95, 0.22, 0.20, 1.0),
                  10 => (0.20, 0.68, 0.24, 1.0),
                  11 => (0.82, 0.58, 0.08, 1.0),
                  12 => (0.26, 0.46, 0.92, 1.0),
                  13 => (0.70, 0.30, 0.88, 1.0),
                  14 => (0.12, 0.64, 0.70, 1.0),
                  15 => (0.08, 0.09, 0.10, 1.0)],
               Default_FG => (0.11, 0.12, 0.13, 1.0),
               Default_BG => (0.97, 0.97, 0.95, 1.0),
               Cursor_BG  => (0.11, 0.12, 0.13, 1.0),
               Cursor_FG  => (0.97, 0.97, 0.95, 1.0),
               Selection_BG => (0.10, 0.32, 0.78, 1.0),
               Selection_FG => (0.97, 0.97, 0.95, 1.0),
               URL_Highlight => (0.00, 0.48, 0.58, 1.0));
         when High_Contrast =>
            return
              (Palette =>
                 [0  => (0.00, 0.00, 0.00, 1.0),
                  1  => (1.00, 0.10, 0.10, 1.0),
                  2  => (0.10, 1.00, 0.10, 1.0),
                  3  => (1.00, 0.85, 0.00, 1.0),
                  4  => (0.25, 0.55, 1.00, 1.0),
                  5  => (1.00, 0.25, 1.00, 1.0),
                  6  => (0.10, 1.00, 1.00, 1.0),
                  7  => (0.90, 0.90, 0.90, 1.0),
                  8  => (0.45, 0.45, 0.45, 1.0),
                  9  => (1.00, 0.35, 0.35, 1.0),
                  10 => (0.35, 1.00, 0.35, 1.0),
                  11 => (1.00, 1.00, 0.20, 1.0),
                  12 => (0.45, 0.70, 1.00, 1.0),
                  13 => (1.00, 0.45, 1.00, 1.0),
                  14 => (0.35, 1.00, 1.00, 1.0),
                  15 => (1.00, 1.00, 1.00, 1.0)],
               Default_FG => (1.00, 1.00, 1.00, 1.0),
               Default_BG => (0.00, 0.00, 0.00, 1.0),
               Cursor_BG  => (1.00, 1.00, 1.00, 1.0),
               Cursor_FG  => (0.00, 0.00, 0.00, 1.0),
               Selection_BG => (0.25, 0.55, 1.00, 1.0),
               Selection_FG => (1.00, 1.00, 1.00, 1.0),
               URL_Highlight => (0.10, 1.00, 1.00, 1.0));
         when Solarized_Dark | Dracula | Gruvbox_Dark | Nord | One_Dark =>
            declare
               Result : Theme := Built_In (Default_Dark);
            begin
               case Name is
                  when Solarized_Dark =>
                     Result.Default_BG := (0.00, 0.17, 0.21, 1.0);
                     Result.Default_FG := (0.51, 0.58, 0.59, 1.0);
                     Result.Palette (1) := (0.86, 0.20, 0.18, 1.0);
                     Result.Palette (2) := (0.52, 0.60, 0.00, 1.0);
                     Result.Palette (3) := (0.71, 0.54, 0.00, 1.0);
                     Result.Palette (4) := (0.15, 0.55, 0.82, 1.0);
                     Result.Palette (5) := (0.83, 0.21, 0.51, 1.0);
                     Result.Palette (6) := (0.16, 0.63, 0.60, 1.0);
                     Result.Cursor_BG := (0.58, 0.63, 0.63, 1.0);
                     Result.Cursor_FG := Result.Default_BG;
                     Result.Selection_BG := (0.03, 0.21, 0.26, 1.0);
                     Result.URL_Highlight := Result.Palette (6);
                  when Dracula =>
                     Result.Default_BG := (0.16, 0.16, 0.21, 1.0);
                     Result.Default_FG := (0.97, 0.97, 0.95, 1.0);
                     Result.Palette (1) := (1.00, 0.33, 0.33, 1.0);
                     Result.Palette (2) := (0.31, 0.98, 0.48, 1.0);
                     Result.Palette (3) := (0.95, 0.98, 0.55, 1.0);
                     Result.Palette (4) := (0.40, 0.56, 1.00, 1.0);
                     Result.Palette (5) := (1.00, 0.47, 0.78, 1.0);
                     Result.Palette (6) := (0.55, 0.91, 0.99, 1.0);
                     Result.Cursor_BG := Result.Default_FG;
                     Result.Cursor_FG := Result.Default_BG;
                     Result.Selection_BG := (0.27, 0.28, 0.35, 1.0);
                     Result.URL_Highlight := Result.Palette (6);
                  when Gruvbox_Dark =>
                     Result.Default_BG := (0.16, 0.16, 0.13, 1.0);
                     Result.Default_FG := (0.92, 0.86, 0.70, 1.0);
                     Result.Palette (1) := (0.80, 0.14, 0.11, 1.0);
                     Result.Palette (2) := (0.60, 0.59, 0.10, 1.0);
                     Result.Palette (3) := (0.84, 0.60, 0.13, 1.0);
                     Result.Palette (4) := (0.27, 0.52, 0.53, 1.0);
                     Result.Palette (5) := (0.69, 0.38, 0.53, 1.0);
                     Result.Palette (6) := (0.41, 0.62, 0.42, 1.0);
                     Result.Cursor_BG := Result.Default_FG;
                     Result.Cursor_FG := Result.Default_BG;
                     Result.Selection_BG := (0.31, 0.29, 0.22, 1.0);
                     Result.URL_Highlight := Result.Palette (6);
                  when Nord =>
                     Result.Default_BG := (0.18, 0.20, 0.25, 1.0);
                     Result.Default_FG := (0.85, 0.87, 0.91, 1.0);
                     Result.Palette (1) := (0.75, 0.38, 0.42, 1.0);
                     Result.Palette (2) := (0.64, 0.75, 0.55, 1.0);
                     Result.Palette (3) := (0.92, 0.80, 0.55, 1.0);
                     Result.Palette (4) := (0.51, 0.63, 0.76, 1.0);
                     Result.Palette (5) := (0.71, 0.56, 0.68, 1.0);
                     Result.Palette (6) := (0.53, 0.75, 0.82, 1.0);
                     Result.Cursor_BG := Result.Default_FG;
                     Result.Cursor_FG := Result.Default_BG;
                     Result.Selection_BG := (0.26, 0.30, 0.37, 1.0);
                     Result.URL_Highlight := Result.Palette (6);
                  when One_Dark =>
                     Result.Default_BG := (0.15, 0.16, 0.19, 1.0);
                     Result.Default_FG := (0.67, 0.70, 0.75, 1.0);
                     Result.Palette (1) := (0.88, 0.42, 0.46, 1.0);
                     Result.Palette (2) := (0.60, 0.76, 0.47, 1.0);
                     Result.Palette (3) := (0.90, 0.75, 0.48, 1.0);
                     Result.Palette (4) := (0.38, 0.69, 0.94, 1.0);
                     Result.Palette (5) := (0.78, 0.47, 0.87, 1.0);
                     Result.Palette (6) := (0.34, 0.71, 0.76, 1.0);
                     Result.Cursor_BG := Result.Default_FG;
                     Result.Cursor_FG := Result.Default_BG;
                     Result.Selection_BG := (0.24, 0.28, 0.35, 1.0);
                     Result.URL_Highlight := Result.Palette (6);
                  when others => null;
               end case;
               Result.Selection_FG := Result.Default_FG;
               return Result;
            end;
      end case;
   end Built_In;

   function Parse_Name (Text : String; Name : out Theme_Name) return Boolean is
      Lower : constant String := Ada.Characters.Handling.To_Lower (Text);
   begin
      if Lower = "default" or else Lower = "dark" or else Lower = "default-dark" then
         Name := Default_Dark;
         return True;
      elsif Lower = "light" then
         Name := Light;
         return True;
      elsif Lower = "high-contrast" or else Lower = "high_contrast" then
         Name := High_Contrast;
         return True;
      elsif Lower = "solarized-dark" or else Lower = "solarized_dark" then
         Name := Solarized_Dark;
         return True;
      elsif Lower = "dracula" then
         Name := Dracula;
         return True;
      elsif Lower = "gruvbox-dark" or else Lower = "gruvbox_dark" then
         Name := Gruvbox_Dark;
         return True;
      elsif Lower = "nord" then
         Name := Nord;
         return True;
      elsif Lower = "one-dark" or else Lower = "one_dark" then
         Name := One_Dark;
         return True;
      else
         Name := Default_Dark;
         return False;
      end if;
   end Parse_Name;

   function Image (Name : Theme_Name) return String is
   begin
      case Name is
         when Default_Dark  => return "default-dark";
         when Light         => return "light";
         when High_Contrast => return "high-contrast";
         when Solarized_Dark => return "solarized-dark";
         when Dracula        => return "dracula";
         when Gruvbox_Dark   => return "gruvbox-dark";
         when Nord           => return "nord";
         when One_Dark       => return "one-dark";
      end case;
   end Image;

   function Status_Label (Name : Theme_Name) return String is
   begin
      return "Theme " & Image (Name) & " active";
   end Status_Label;
end Terminal.App.Theme;
