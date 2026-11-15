with Terminal.App.Frame_Image_Storage;
with Terminal.App.Placeholder_Index;
with Terminal.App.Render_Model;
with Terminal.App.Splits;
with Terminal.App.Theme;
with Terminal.App.Text_Shaper;
with Terminal.App.Vulkan_Submit;
with Terminal.Core;
with Textrender;

private package Terminal.App.Renderer_State is
   type Shaped_Run_Map_Entry is record
      Run_Index   : Natural := 0;
      Starts_Here : Boolean := False;
   end record;
   type Shaped_Run_Map_Array is
     array (Positive range <>) of Shaped_Run_Map_Entry;
   type Shaped_Run_Map_Array_Access is access Shaped_Run_Map_Array;

   type Cached_Text_Row is record
      Runs  : Terminal.App.Render_Model.Text_Run_Array_Access := null;
      Count : Natural := 0;
      Text_Valid : Boolean := False;
      Rectangles : Terminal.App.Render_Model.Rectangle_Array_Access := null;
      Rectangle_Count : Natural := 0;
      Glyphs : Terminal.App.Render_Model.Glyph_Array_Access := null;
      Glyph_Count : Natural := 0;
      Colour_Glyphs : Terminal.App.Render_Model.Colour_Glyph_Array_Access := null;
      Colour_Glyph_Count : Natural := 0;
      Color_Glyph_Diagnostic_Count : Natural := 0;
      Color_Emoji_Fallback_Count : Natural := 0;
      Missing_Glyph_Count : Natural := 0;
      Draw_Valid : Boolean := False;
   end record;
   type Cached_Text_Row_Array is array (Positive range <>) of Cached_Text_Row;
   type Cached_Text_Row_Array_Access is access Cached_Text_Row_Array;
   type Text_Run_Cache is record
      Initialized       : Boolean := False;
      Stream_ID         : Terminal.Core.Graphics_Stream_ID := 0;
      Alternate_Screen  : Boolean := False;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation := 0;
      Rows              : Natural := 0;
      Cols              : Natural := 0;
      Origin_X          : Natural := 0;
      Origin_Y          : Natural := 0;
      Last_Cursor       : Terminal.Core.Cursor_State := (others => <>);
      Items             : Cached_Text_Row_Array_Access := null;
   end record;
   type Text_Run_Cache_Array is
     array (Terminal.App.Splits.Pane_Index) of Text_Run_Cache;

   type Text_State is limited record
      Text        : Textrender.Renderer;
      Shaper      : Terminal.App.Text_Shaper.Shaper;
      Text_Loaded : Boolean := False;
      CW          : Positive := 10;
      CH          : Positive := 20;
      Shaped_Glyph_Count : Natural := 0;
      Shaping_Fallback_Count : Natural := 0;
      Text_Fallback_Run_Count : Natural := 0;
      Color_Glyph_Count : Natural := 0;
      Color_Emoji_Fallback_Count : Natural := 0;
      Paragraph_Bidi_Fallback_Count : Natural := 0;
      Missing_Glyph_Count : Natural := 0;
      Atlas_Dirty : Boolean := False;
      Colour_Sheet_Dirty : Boolean := False;
   end record;

   type Frame_State is record
      Rectangles  : Terminal.App.Render_Model.Rectangle_Array_Access := null;
      Glyphs      : Terminal.App.Render_Model.Glyph_Array_Access := null;
      Colour_Glyphs : Terminal.App.Render_Model.Colour_Glyph_Array_Access := null;
      Frame_Images : Terminal.App.Frame_Image_Storage.Storage;
      Text_Runs   : Terminal.App.Render_Model.Text_Run_Array_Access := null;
      Shaped_Run_Map : Shaped_Run_Map_Array_Access := null;
      Text_Run_Caches : Text_Run_Cache_Array := (others => <>);
      Placement_Index : Terminal.App.Placeholder_Index.Index;
      Placement_Index_Dirty : Boolean := True;
      Frame_Command_Overflowed : Boolean := False;
      Batch       : Terminal.App.Vulkan_Submit.Submission_Batch;
      Rectangle_Count : Natural := 0;
      Glyph_Count : Natural := 0;
      Colour_Glyph_Count : Natural := 0;
      Text_Run_Count : Natural := 0;
      Vertex_Count : Natural := 0;
      Last_Cell_Count : Natural := 0;
      Last_Dirty_Rows : Natural := 0;
      Last_Cached_Rows : Natural := 0;
      Last_Frame_Width : Natural := 0;
      Last_Frame_Height : Natural := 0;
      Target_Frame_Width : Natural := 0;
      Target_Frame_Height : Natural := 0;
      Draw_Offset_X : Natural := 0;
      Draw_Offset_Y : Natural := 0;
   end record;

   type View_State is record
      Color_Theme : Terminal.App.Theme.Theme :=
        Terminal.App.Theme.Built_In (Terminal.App.Theme.Default_Dark);
      Hovered_Link : Terminal.Core.Hyperlink;
      Overlay_Length : Natural range 0 .. 160 := 0;
      Overlay_Text : String (1 .. 160) := (others => ' ');
   end record;
end Terminal.App.Renderer_State;
