with Ada.Characters.Handling;

package body Terminal.App.Theme is
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
               Cursor_FG  => (0.03, 0.035, 0.04, 1.0));
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
               Cursor_FG  => (0.97, 0.97, 0.95, 1.0));
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
               Cursor_FG  => (0.00, 0.00, 0.00, 1.0));
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
      end case;
   end Image;

   function Status_Label (Name : Theme_Name) return String is
   begin
      return "Theme " & Image (Name) & " active";
   end Status_Label;
end Terminal.App.Theme;
