with Ada.Unchecked_Deallocation;
with Textrender;

with Terminal.App.Hyperlinks;
with Terminal.App.Renderer.Drawing_Commands;
with Terminal.App.Renderer.Frame_Lifecycle;
with Terminal.App.Renderer.Frame_Geometry;
with Terminal.App.Renderer.Text_Media;
with Terminal.App.Renderer.Visual_Style;
with Terminal.App.Text_Shaper;

package body Terminal.App.Renderer.Text_Pipeline is
   package Style renames Terminal.App.Renderer.Visual_Style;

   use type Terminal.Common.Code_Point;
   use type Terminal.Core.Cell_Kind;
   use type Terminal.Core.Cell_Width;
   use type RM.Text_Run_Array_Access;
   use type RM.Rectangle_Array_Access;
   use type RM.Glyph_Array_Access;
   use type RM.Colour_Glyph_Array_Access;
   use type RM.Text_Run_Direction;
   use type RM.Text_Run_Script;
   use type RM.Text_Run_Shape_Status;
   use type Shaped_Run_Map_Array_Access;
   use type Terminal.Core.Graphics_Stream_ID;
   use type Terminal.Core.Graphics_Screen_Generation;
   use type Terminal.Core.Cursor_State;
   use type Terminal.App.Renderer_State.Cached_Text_Row_Array_Access;
   use type Textrender.Status_Code;

   procedure Free_Cached_Runs is new Ada.Unchecked_Deallocation
     (RM.Text_Run_Array, RM.Text_Run_Array_Access);
   procedure Free_Cached_Rectangles is new Ada.Unchecked_Deallocation
     (RM.Rectangle_Array, RM.Rectangle_Array_Access);
   procedure Free_Cached_Glyphs is new Ada.Unchecked_Deallocation
     (RM.Glyph_Array, RM.Glyph_Array_Access);
   procedure Free_Cached_Colour_Glyphs is new Ada.Unchecked_Deallocation
     (RM.Colour_Glyph_Array, RM.Colour_Glyph_Array_Access);
   procedure Free_Cached_Rows is new Ada.Unchecked_Deallocation
     (Terminal.App.Renderer_State.Cached_Text_Row_Array,
      Terminal.App.Renderer_State.Cached_Text_Row_Array_Access);

   procedure Invalidate_Caches (R : in out Renderer) is
   begin
      for Cache of R.Frame_State.Text_Run_Caches loop
         Cache.Initialized := False;
      end loop;
   end Invalidate_Caches;

   function Append_Cached_Row
     (R           : in out Renderer;
      Cache_Index : Terminal.App.Splits.Pane_Index;
      Row         : Positive) return Boolean
   is
      Cached : Terminal.App.Renderer_State.Cached_Text_Row renames
        R.Frame_State.Text_Run_Caches (Cache_Index).Items (Row);
      Capacity_Ok : Boolean;
   begin
      if not Cached.Draw_Valid then
         return False;
      end if;
      R.Frame_State.Last_Cached_Rows :=
        R.Frame_State.Last_Cached_Rows + 1;
      if Cached.Rectangle_Count > 0 then
         Frame_Lifecycle.Ensure_Rectangle_Capacity
           (R, R.Frame_State.Rectangle_Count + Cached.Rectangle_Count,
            Capacity_Ok);
         if not Capacity_Ok then
            R.Frame_State.Frame_Command_Overflowed := True;
            return True;
         end if;
         R.Frame_State.Rectangles
           (R.Frame_State.Rectangle_Count + 1 ..
              R.Frame_State.Rectangle_Count + Cached.Rectangle_Count) :=
            Cached.Rectangles (1 .. Cached.Rectangle_Count);
         R.Frame_State.Rectangle_Count :=
           R.Frame_State.Rectangle_Count + Cached.Rectangle_Count;
      end if;
      if Cached.Glyph_Count > 0 then
         Frame_Lifecycle.Ensure_Glyph_Capacity
           (R, R.Frame_State.Glyph_Count + Cached.Glyph_Count, Capacity_Ok);
         if not Capacity_Ok then
            R.Frame_State.Frame_Command_Overflowed := True;
            return True;
         end if;
         R.Frame_State.Glyphs
           (R.Frame_State.Glyph_Count + 1 ..
              R.Frame_State.Glyph_Count + Cached.Glyph_Count) :=
            Cached.Glyphs (1 .. Cached.Glyph_Count);
         R.Frame_State.Glyph_Count :=
           R.Frame_State.Glyph_Count + Cached.Glyph_Count;
      end if;
      if Cached.Colour_Glyph_Count > 0 then
         Frame_Lifecycle.Ensure_Colour_Capacity
           (R,
            R.Frame_State.Colour_Glyph_Count + Cached.Colour_Glyph_Count,
            Capacity_Ok);
         if not Capacity_Ok then
            R.Frame_State.Frame_Command_Overflowed := True;
            return True;
         end if;
         R.Frame_State.Colour_Glyphs
           (R.Frame_State.Colour_Glyph_Count + 1 ..
              R.Frame_State.Colour_Glyph_Count + Cached.Colour_Glyph_Count) :=
            Cached.Colour_Glyphs (1 .. Cached.Colour_Glyph_Count);
         R.Frame_State.Colour_Glyph_Count :=
           R.Frame_State.Colour_Glyph_Count + Cached.Colour_Glyph_Count;
      end if;
      R.Text_State.Color_Glyph_Count :=
        R.Text_State.Color_Glyph_Count + Cached.Color_Glyph_Diagnostic_Count;
      R.Text_State.Color_Emoji_Fallback_Count :=
        R.Text_State.Color_Emoji_Fallback_Count
        + Cached.Color_Emoji_Fallback_Count;
      R.Text_State.Missing_Glyph_Count :=
        R.Text_State.Missing_Glyph_Count + Cached.Missing_Glyph_Count;
      return True;
   end Append_Cached_Row;

   procedure Capture_Row
     (R               : in out Renderer;
      Cache_Index     : Terminal.App.Splits.Pane_Index;
      Row             : Positive;
      First_Rectangle : Positive;
      First_Glyph     : Positive;
      First_Colour    : Positive;
      First_Color_Diagnostic : Natural;
      First_Emoji_Fallback   : Natural;
      First_Missing_Glyph    : Natural)
   is
      Cached : Terminal.App.Renderer_State.Cached_Text_Row renames
        R.Frame_State.Text_Run_Caches (Cache_Index).Items (Row);
      Rectangle_Count : constant Natural :=
        (if R.Frame_State.Rectangle_Count < First_Rectangle then 0
         else R.Frame_State.Rectangle_Count - First_Rectangle + 1);
      Glyph_Count : constant Natural :=
        (if R.Frame_State.Glyph_Count < First_Glyph then 0
         else R.Frame_State.Glyph_Count - First_Glyph + 1);
      Colour_Count : constant Natural :=
        (if R.Frame_State.Colour_Glyph_Count < First_Colour then 0
         else R.Frame_State.Colour_Glyph_Count - First_Colour + 1);
   begin
      Cached.Draw_Valid := False;
      if Rectangle_Count > 0
        and then
          (Cached.Rectangles = null
           or else Cached.Rectangles'Length < Rectangle_Count)
      then
         Free_Cached_Rectangles (Cached.Rectangles);
         Cached.Rectangles := new RM.Rectangle_Array (1 .. Rectangle_Count);
      end if;
      if Glyph_Count > 0
        and then
          (Cached.Glyphs = null or else Cached.Glyphs'Length < Glyph_Count)
      then
         Free_Cached_Glyphs (Cached.Glyphs);
         Cached.Glyphs := new RM.Glyph_Array (1 .. Glyph_Count);
      end if;
      if Colour_Count > 0
        and then
          (Cached.Colour_Glyphs = null
           or else Cached.Colour_Glyphs'Length < Colour_Count)
      then
         Free_Cached_Colour_Glyphs (Cached.Colour_Glyphs);
         Cached.Colour_Glyphs := new RM.Colour_Glyph_Array (1 .. Colour_Count);
      end if;
      if Rectangle_Count > 0 then
         Cached.Rectangles (1 .. Rectangle_Count) :=
           R.Frame_State.Rectangles
             (First_Rectangle .. R.Frame_State.Rectangle_Count);
      end if;
      if Glyph_Count > 0 then
         Cached.Glyphs (1 .. Glyph_Count) :=
           R.Frame_State.Glyphs (First_Glyph .. R.Frame_State.Glyph_Count);
      end if;
      if Colour_Count > 0 then
         Cached.Colour_Glyphs (1 .. Colour_Count) :=
           R.Frame_State.Colour_Glyphs
             (First_Colour .. R.Frame_State.Colour_Glyph_Count);
      end if;
      Cached.Rectangle_Count := Rectangle_Count;
      Cached.Glyph_Count := Glyph_Count;
      Cached.Colour_Glyph_Count := Colour_Count;
      Cached.Color_Glyph_Diagnostic_Count :=
        R.Text_State.Color_Glyph_Count - First_Color_Diagnostic;
      Cached.Color_Emoji_Fallback_Count :=
        R.Text_State.Color_Emoji_Fallback_Count - First_Emoji_Fallback;
      Cached.Missing_Glyph_Count :=
        R.Text_State.Missing_Glyph_Count - First_Missing_Glyph;
      Cached.Draw_Valid := True;
   exception
      when Storage_Error =>
         Cached.Draw_Valid := False;
         R.Frame_State.Frame_Command_Overflowed := True;
   end Capture_Row;

   Max_Link_Overlay_Chars : Natural renames
     Frame_Geometry.Max_Link_Overlay_Chars;

   function Origin_X (R : Renderer) return Natural renames
     Frame_Geometry.Origin_X;

   function Origin_Y (R : Renderer) return Natural renames
     Frame_Geometry.Origin_Y;

   function Is_Emoji_Scalar
     (Codepoint : Terminal.Common.Code_Point) return Boolean
     renames Text_Media.Is_Emoji_Scalar;

   function Is_Drawable (Cell : Terminal.Core.Cell_Content) return Boolean
     renames Text_Media.Is_Drawable;

   procedure Cell_Properties
     (Cell      : Terminal.Core.Cell_Content;
      Direction : out RM.Text_Run_Direction;
      Script    : out RM.Text_Run_Script)
     renames Text_Media.Cell_Properties;

   function Cell_Joins_Run
     (Snapshot  : Terminal.Core.Render_Snapshot;
      Row       : Positive;
      Col       : Positive;
      Base      : Terminal.Core.Cell_Content;
      Direction : in out RM.Text_Run_Direction;
      Script    : in out RM.Text_Run_Script) return Boolean
     renames Text_Media.Cell_Joins_Run;

   procedure Add_Text_Run
     (R         : in out Renderer;
      Snapshot  : Terminal.Core.Render_Snapshot;
      Row       : Positive;
      First_Col : Positive;
      Last_Col  : Positive;
      X         : Float;
      Y         : Float;
      Width     : Float;
      Height    : Float;
      Color     : RM.Pixel_Color)
   is separate;

   procedure Reorder_Mixed_Bidi_Row
     (R     : in out Renderer;
      First : Positive;
      Last  : Natural;
      Right : Float)
   is separate;

   procedure Build_Text_Runs
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot;
      Cache_Index : Terminal.App.Splits.Pane_Index)
   is separate;

   procedure Draw_Glyph
     (R         : in out Renderer;
      Codepoint : Terminal.Common.Code_Point;
      X         : Float;
      Y         : Float;
      Color     : RM.Pixel_Color;
      Bold      : Boolean;
      Italic    : Boolean;
      Status    : out Render_Status)
   is separate;

   function Draw_Emoji_Run_Color
     (R   : in out Renderer;
      Run : RM.Text_Run_Command) return Boolean
   is separate;

   procedure Add_Link_Overlay
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot;
      Status   : out Render_Status)
   is separate;

   procedure Draw_Label
     (R      : in out Renderer;
      Text   : String;
      X      : Float;
      Y      : Float;
      Limit  : Natural;
      Color  : RM.Pixel_Color;
      Status : out Render_Status)
   is
      Count : constant Natural := Natural'Min (Text'Length, Limit);
   begin
      if Count = 0 then
         Status := Ok;
         return;
      end if;
      for Offset in 0 .. Count - 1 loop
         Draw_Glyph
           (R,
            Codepoint =>
              Terminal.Common.Code_Point
                (Character'Pos (Text (Text'First + Offset))),
            X      => X + Float (Offset * R.Text_State.CW),
            Y      => Y,
            Color  => Color,
            Bold   => False,
            Italic => False,
            Status => Status);
         if Status /= Ok then
            return;
         end if;
      end loop;

      Status := Ok;
   end Draw_Label;

   procedure Draw_Shaped_Run
     (R      : in out Renderer;
      Run    : RM.Text_Run_Command;
      Status : out Render_Status)
   is separate;

   function Is_Shaped_Draw_Run (Run : RM.Text_Run_Command) return Boolean is
     (Run.Shape_Status = RM.Shape_Ok
      and then not Run.Fallback_Glyphs
      and then Run.Shaped_Glyph_Count > 0);

   procedure Build_Shaped_Run_Map
     (R         : in out Renderer;
      Snapshot  : Terminal.Core.Render_Snapshot;
      First_Run : Positive)
   is separate;

   function Shaped_Run_At
     (R    : Renderer;
      Cols : Positive;
      Row  : Positive;
      Col  : Positive) return Shaped_Run_Map_Entry
   is
      Index : constant Positive := (Row - 1) * Cols + Col;
   begin
      if R.Frame_State.Shaped_Run_Map = null
        or else Index > R.Frame_State.Shaped_Run_Map'Length
      then
         return (others => <>);
      else
         return R.Frame_State.Shaped_Run_Map (Index);
      end if;
   end Shaped_Run_At;
end Terminal.App.Renderer.Text_Pipeline;
