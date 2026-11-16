with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;
with Terminal.App.Fonts;
with Terminal.App.HarfBuzz;
with Terminal.App.Render_Model;

private package Terminal.App.Text_Shaper_State is
   package RM renames Terminal.App.Render_Model;
   package HB renames Terminal.App.HarfBuzz;

   type Shape_Cache_Entry is record
      Run_Kind           : RM.Text_Run_Kind;
      Shape_Status       : RM.Text_Run_Shape_Status;
      Direction          : RM.Text_Run_Direction;
      Script             : RM.Text_Run_Script;
      Shaped_Glyphs      : RM.Shaped_Glyph_Array;
      Shaped_Glyph_Count : RM.Shaped_Glyph_Total;
      Fallback_Glyphs    : Boolean;
   end record;

   package Shape_Cache_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Shape_Cache_Entry,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   type Fallback_Face_Array is array
     (Positive range 1 .. Terminal.App.Fonts.Max_Fallback_Fonts) of HB.Font_Face;
   type Style_Face_Array is array (Positive range 1 .. 3) of HB.Font_Face;
   type Style_Enabled_Array is array (Positive range 1 .. 3) of Boolean;

   type State is limited record
      Default_Face        : HB.Font_Face;
      Default_Face_Loaded : Boolean := False;
      Default_Face_Tried  : Boolean := False;
      Style_Faces         : Style_Face_Array;
      Style_Face_Count    : Natural range 0 .. 3 := 0;
      Style_Enabled       : Style_Enabled_Array := (others => False);
      Feature_Length      : Natural range 0 .. 512 := 0;
      Feature_Text        : String (1 .. 512) := (others => ASCII.NUL);
      Variation_Length    : Natural range 0 .. 512 := 0;
      Variation_Text      : String (1 .. 512) := (others => ASCII.NUL);
      Fallback_Faces      : Fallback_Face_Array;
      Fallback_Face_Count : Natural := 0;
      Shape_Cache         : Shape_Cache_Maps.Map;
   end record;
end Terminal.App.Text_Shaper_State;
