--  Font discovery for the terminal text renderer.
package Terminal.App.Fonts is
   Max_Fallback_Fonts : constant := 128;
   Max_Status_Label_Length : constant := 96;

   type Font_Path is record
      Length : Natural := 0;
      Text   : String (1 .. 512) := (others => ASCII.NUL);
   end record;

   type Font_Path_Array is array (Positive range <>) of Font_Path;

   type Font_Style is (Monospace, Sans_Serif, Serif, Symbol);

   function Default_Font_Path return String;
   function Fallback_Font_Paths return Font_Path_Array;
   function Font_Path_For (Style : Font_Style) return String;
   --  Resolve an optional exact QuickDraw family override first, then the
   --  semantic fallback. For example, Chicago consults
   --  TERMINAL_PICT_FONT_CHICAGO and TERMINAL_PICT_FONT_SANS_SERIF.
   function PICT_Font_Path (Family : String; Style : Font_Style) return String;
   function To_String (Path : Font_Path) return String;
   function Status_Label
     (Default_Path   : String;
      Fallback_Count : Natural) return String;
end Terminal.App.Fonts;
