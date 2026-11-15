with Terminal.Common;
with Terminal.Core;
with Terminal.App.Render_Model;
with Terminal.App.Splits;

private package Terminal.App.Renderer.Text_Pipeline is
   package RM renames Terminal.App.Render_Model;

   procedure Build_Text_Runs
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot;
      Cache_Index : Terminal.App.Splits.Pane_Index);

   procedure Invalidate_Caches (R : in out Renderer);

   function Append_Cached_Row
     (R           : in out Renderer;
      Cache_Index : Terminal.App.Splits.Pane_Index;
      Row         : Positive) return Boolean;

   procedure Capture_Row
     (R               : in out Renderer;
      Cache_Index     : Terminal.App.Splits.Pane_Index;
      Row             : Positive;
      First_Rectangle : Positive;
      First_Glyph     : Positive;
      First_Colour    : Positive;
      First_Color_Diagnostic : Natural;
      First_Emoji_Fallback   : Natural;
      First_Missing_Glyph    : Natural);

   procedure Draw_Glyph
     (R         : in out Renderer;
      Codepoint : Terminal.Common.Code_Point;
      X         : Float;
      Y         : Float;
      Color     : RM.Pixel_Color;
      Bold      : Boolean;
      Italic    : Boolean;
      Status    : out Render_Status);

   function Draw_Emoji_Run_Color
     (R   : in out Renderer;
      Run : RM.Text_Run_Command) return Boolean;

   procedure Add_Link_Overlay
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot;
      Status   : out Render_Status);

   procedure Draw_Label
     (R      : in out Renderer;
      Text   : String;
      X      : Float;
      Y      : Float;
      Limit  : Natural;
      Color  : RM.Pixel_Color;
      Status : out Render_Status);

   procedure Draw_Shaped_Run
     (R      : in out Renderer;
      Run    : RM.Text_Run_Command;
      Status : out Render_Status);

   procedure Build_Shaped_Run_Map
     (R         : in out Renderer;
      Snapshot  : Terminal.Core.Render_Snapshot;
      First_Run : Positive);

   function Shaped_Run_At
     (R    : Renderer;
      Cols : Positive;
      Row  : Positive;
      Col  : Positive) return Shaped_Run_Map_Entry;
end Terminal.App.Renderer.Text_Pipeline;
