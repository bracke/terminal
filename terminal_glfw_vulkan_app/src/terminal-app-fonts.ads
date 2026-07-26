--  Font discovery for the terminal text renderer.
package Terminal.App.Fonts is
   Max_Fallback_Fonts : constant := 128;

   type Font_Path is record
      Length : Natural := 0;
      Text   : String (1 .. 512) := (others => ASCII.NUL);
   end record;

   type Font_Path_Array is array (Positive range <>) of Font_Path;

   function Default_Font_Path return String;
   function Fallback_Font_Paths return Font_Path_Array;
   function To_String (Path : Font_Path) return String;
end Terminal.App.Fonts;
