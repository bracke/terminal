with System;

--  Renderer-neutral terminal draw commands.
--
--  The terminal renderer builds these commands from Terminal.Core snapshots.
--  A Vulkan adapter can consume them without parsing terminal data or owning
--  terminal state.
package Terminal.App.Render_Model is
   type Pixel_Color is record
      R : Float := 0.0;
      G : Float := 0.0;
      B : Float := 0.0;
      A : Float := 1.0;
   end record;

   type Rectangle_Command is record
      X      : Float := 0.0;
      Y      : Float := 0.0;
      Width  : Float := 0.0;
      Height : Float := 0.0;
      Color  : Pixel_Color;
   end record;

   type Glyph_Command is record
      X         : Float := 0.0;
      Y         : Float := 0.0;
      Width     : Float := 0.0;
      Height    : Float := 0.0;
      U0        : Float := 0.0;
      V0        : Float := 0.0;
      U1        : Float := 0.0;
      V1        : Float := 0.0;
      Color     : Pixel_Color;
      Codepoint : Natural := 0;
   end record;

   Max_Text_Run_Codepoints : constant := 9;
   subtype Text_Run_Codepoint_Count is Natural range 0 .. Max_Text_Run_Codepoints;
   subtype Text_Run_Codepoint_Index is Positive range 1 .. Max_Text_Run_Codepoints;
   type Text_Run_Codepoint_Array is
     array (Text_Run_Codepoint_Index) of Natural;

   type Text_Run_Command is record
      X                : Float := 0.0;
      Y                : Float := 0.0;
      Cell_Width       : Float := 0.0;
      Cell_Height      : Float := 0.0;
      Cell_Span        : Positive := 1;
      Color            : Pixel_Color;
      Bold             : Boolean := False;
      Italic           : Boolean := False;
      Codepoints       : Text_Run_Codepoint_Array := (others => 0);
      Codepoint_Count  : Text_Run_Codepoint_Count := 0;
      Fallback_Glyphs  : Boolean := True;
   end record;

   type Rectangle_Array is array (Positive range <>) of Rectangle_Command;
   type Glyph_Array is array (Positive range <>) of Glyph_Command;
   type Text_Run_Array is array (Positive range <>) of Text_Run_Command;
   type Rectangle_Array_Access is access all Rectangle_Array;
   type Glyph_Array_Access is access all Glyph_Array;
   type Text_Run_Array_Access is access all Text_Run_Array;

   type Frame_Commands is record
      Width           : Natural := 0;
      Height          : Natural := 0;
      Rectangles      : Rectangle_Array_Access := null;
      Rectangle_Count : Natural := 0;
      Glyphs          : Glyph_Array_Access := null;
      Glyph_Count     : Natural := 0;
      Text_Runs       : Text_Run_Array_Access := null;
      Text_Run_Count  : Natural := 0;
      Atlas_Width     : Natural := 0;
      Atlas_Height    : Natural := 0;
      Atlas_Pixels    : System.Address := System.Null_Address;
      Atlas_Bytes     : Natural := 0;
      Atlas_Dirty     : Boolean := False;
   end record;
end Terminal.App.Render_Model;
