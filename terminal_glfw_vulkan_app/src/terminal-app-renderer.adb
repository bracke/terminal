with System;
with Textrender;

with Terminal.Common;
with Terminal.Common.Counters;
with Terminal.App.Fonts;
with Terminal.App.Graphics;
with Terminal.App.Cleanup_Diagnostics;
with Terminal.App.Image_Animation;
with Terminal.App.Owned_Image_Data;
with Terminal.App.Image_Ingestion;
with Terminal.App.Image_Store.Frames;
with Terminal.App.Image_Store.Playback_State;
with Terminal.App.Image_Store.Themes;
with Terminal.App.Renderer.Animations;
with Terminal.App.Renderer.Event_Tracking;
with Terminal.App.Renderer.Diagnostics_State;
with Terminal.App.Renderer.Drawing_Commands;
with Terminal.App.Renderer.Frame_Commands;
with Terminal.App.Renderer.Frame_Geometry;
with Terminal.App.Renderer.Frame_Lifecycle;
with Terminal.App.Renderer.Frame_Planning;
with Terminal.App.Renderer.Graphics_State_Lifecycle;
with Terminal.App.Renderer.Graphics_Synchronization;
with Terminal.App.Renderer.Image_Buffers;
with Terminal.App.Renderer.Image_Objects;
with Terminal.App.Renderer.Placement_Operations;
with Terminal.App.Renderer.Placement_State;
with Terminal.App.Renderer.Theme_State;
with Terminal.App.Renderer.Text_Media;
with Terminal.App.Renderer.Text_Pipeline;
with Terminal.App.Renderer.Visual_Style;
with Terminal.App.Renderer.Visible_Views;
with Terminal.App.Size_Arithmetic;
with Terminal.App.Text_Shaper;

package body Terminal.App.Renderer is
   package RM renames Terminal.App.Render_Model;
   package VS renames Terminal.App.Vulkan_Submit;
   package FIS renames Terminal.App.Frame_Image_Storage;
   package Themes renames Terminal.App.Image_Store.Themes;
   package Frames renames Terminal.App.Image_Store.Frames;
   package Style renames Terminal.App.Renderer.Visual_Style;
   package Animation_State renames Terminal.App.Renderer.Animations;
   package Diagnostic_State renames Terminal.App.Renderer.Diagnostics_State;
   package Image_Commands renames Terminal.App.Renderer.Frame_Commands;
   package Graphics_Lifecycle renames
     Terminal.App.Renderer.Graphics_State_Lifecycle;
   package Placements_State renames Terminal.App.Renderer.Placement_State;
   package Image_Theme_State renames Terminal.App.Renderer.Theme_State;
   package Visible_View_State renames Terminal.App.Renderer.Visible_Views;

   use type Terminal.Core.Cell_Kind;
   use type Terminal.App.ITerm2_Files.Save_Status;
   use type Terminal.App.Image_Media.Decode_Status;
   use type Terminal.App.Image_Store.Image_Frame_Access;
   use type Terminal.App.Image_Store.Image_Object_Access;
   use type Terminal.App.Image_Store.Theme_Operation_Access;
   use type Terminal.App.Image_Placements.Virtual_Placement_Access;
   use type Terminal.App.Image_Placements.Conventional_Placement_Access;
   use type Terminal.Core.Cell_Width;
   use type Terminal.Core.Color_Kind;
   use type Terminal.Core.Cursor_Shape;
   use type Terminal.Core.Graphics_Protocol_Kind;
   use type Terminal.Core.Graphics_ID;
   use type Terminal.Core.Graphics_Stream_ID;
   use type Terminal.Core.Graphics_Screen_Generation;
   use type Terminal.Core.Graphics_Event_Sequence;
   use type Terminal.Core.Graphics_Scroll_Sequence;
   use type Terminal.Core.Graphics_Scroll_Direction;
   use type Terminal.Core.Graphics_Completion_Code;
   use type Terminal.Core.Style;
   use type Terminal.Common.Code_Point;
   use type Terminal.App.Splits.Split_Orientation;
   use type Terminal.App.Graphics_Transport.Load_Status;
   use type Interfaces.Unsigned_64;
   use type Interfaces.Unsigned_32;
   use type RM.Colour_Glyph_Array_Access;
   use type RM.Glyph_Array_Access;
   use type RM.Image_Array_View;
   use type RM.Image_Data_View;
   use type RM.Image_Decoded_Source_Kind;
   use type RM.Image_Protocol;
   use type RM.Rectangle_Array_Access;
   use type RM.Text_Run_Array_Access;
   use type RM.Text_Run_Direction;
   use type RM.Text_Run_Script;
   use type RM.Text_Run_Shape_Status;
   use type Terminal.App.Renderer_State.Shaped_Run_Map_Array_Access;
   use type Terminal.App.Text_Shaper.Backend_Status;
   use type Textrender.Status_Code;
   use type VS.Build_Status;
   use Terminal.App.Renderer.Placement_Operations;

   Atlas_Width  : constant Positive := 1024;
   Atlas_Height : constant Positive := 1024;
   Max_Link_Overlay_Chars : Natural renames
     Frame_Geometry.Max_Link_Overlay_Chars;
   Pane_Border_Pixels : constant Natural := 2;

   function Origin_X (R : Renderer) return Natural renames
     Frame_Geometry.Origin_X;

   function Origin_Y (R : Renderer) return Natural renames
     Frame_Geometry.Origin_Y;

   procedure Clear_Last_Media_Diagnostics (R : in out Renderer)
     renames Diagnostics_State.Clear_Last_Media;

   function Stored_Image_Bytes (R : Renderer) return Natural
     renames Image_Objects.Stored_Bytes;

   function Stored_Animation_Frame_Count (R : Renderer) return Natural
     renames Image_Objects.Stored_Animation_Frame_Count;

   procedure Release_Graphics_State_Storage
     (Object : in out Renderer_Graphics_State)
     renames Graphics_Lifecycle.Release;

   overriding procedure Finalize (Object : in out Renderer_Graphics_State) is
   begin
      Release_Graphics_State_Storage (Object);
   exception
      when E : others =>
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Renderer_State,
            E,
            "finalize graphics state component");
   end Finalize;

   procedure Set_Visible_Graphics_Views
     (R         : in out Renderer;
      Snapshots : Snapshot_Array)
     renames Visible_View_State.Set_All;

   procedure Set_Visible_Graphics_View
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot)
     renames Visible_View_State.Set_One;

   procedure Append_Borrowed_Frame_Command
     (R                : in out Renderer;
      Command          : RM.Image_Command;
      Borrowed_Object  : not null Image_Object_Access;
      Frame_Number     : Positive;
      Use_As_Decoded   : Boolean := True;
      Use_As_Preview   : Boolean := True) is
   begin
      Image_Commands.Append_Borrowed_Frame
        (R, Command, Borrowed_Object, Frame_Number,
         Use_As_Decoded, Use_As_Preview);
   end Append_Borrowed_Frame_Command;

   procedure Append_Image_Command
     (R       : in out Renderer;
      Command : RM.Image_Command;
      Decoded : in out Terminal.App.Owned_Image_Data.Owner;
      Encoded : in out Terminal.App.Owned_Image_Data.Owner;
      Preview : in out Terminal.App.Owned_Image_Data.Owner)
   is
      Prepared     : RM.Image_Command := Command;
   begin
      if not Terminal.App.Owned_Image_Data.Is_Empty (Decoded) then
         if Prepared.Decoded_Source = RM.Image_Decoded_Source_Buffer then
            Prepared.Decoded_Bytes :=
              Terminal.App.Owned_Image_Data.Unsafe_View (Decoded);
         end if;
      end if;
      if not Terminal.App.Owned_Image_Data.Is_Empty (Encoded) then
         Prepared.Encoded_Source_Bytes :=
           Terminal.App.Owned_Image_Data.Unsafe_View (Encoded);
         Prepared.Encoded_Source_Length :=
           Terminal.App.Owned_Image_Data.Length (Encoded);
      end if;
      if not Terminal.App.Owned_Image_Data.Is_Empty (Preview) then
         Prepared.Decoded_Preview_Bytes :=
           Terminal.App.Owned_Image_Data.Unsafe_View (Preview);
      end if;
      Image_Commands.Append
        (R, Prepared, Decoded, Encoded, Preview);
   end Append_Image_Command;

   function Sixel_Palette_For
     (R         : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID)
      return Sixel_Palette_Entry_Access
   is
      Current : Sixel_Palette_Entry_Access := R.Graphics_State.Resources.Sixel_Palettes;
   begin
      while Current /= null loop
         if Current.Stream_ID = Stream_ID then
            return Current;
         end if;
         Current := Current.Next;
      end loop;
      Current := new Sixel_Palette_Entry'
        (Stream_ID => Stream_ID,
         Palette   => Terminal.App.Graphics.Default_Sixel_Palette,
         Next      => R.Graphics_State.Resources.Sixel_Palettes);
      R.Graphics_State.Resources.Sixel_Palettes := Current;
      return Current;
   exception
      when Storage_Error =>
         return null;
   end Sixel_Palette_For;

   function Ceiling_Positive (Value : Float) return Positive
     renames Text_Media.Ceiling_Positive;

   function Measured_Cell_Width
     (Text     : in out Textrender.Renderer;
      Fallback : Positive)
      return Positive
     renames Text_Media.Measured_Cell_Width;

   function Colour_PNG_Extent
     (Data   : Textrender.Encoded_Image;
      Width  : out Natural;
      Height : out Natural)
      return Boolean
     renames Text_Media.Colour_PNG_Extent;

   function Decode_Colour_PNG
     (Data   : Textrender.Encoded_Image;
      Width  : Natural;
      Height : Natural;
      Pixels : out Textrender.Rgba_Buffer)
      return Boolean
   is separate;

   procedure Set_Render_Status
     (R      : in out Renderer;
      Status : out Render_Status;
      Value  : Render_Status) is
   begin
      R.Lifecycle.Last_Render_Status := Value;
      Status := Value;
   end Set_Render_Status;

   function Submission_Render_Status
     (Status : Terminal.App.Vulkan_Submit.Build_Status) return Render_Status is
     (Frame_Lifecycle.Submission_Render_Status (Status));

   subtype Placement_Geometry is Placements_State.Placement_Geometry;

   procedure Delete_Visible_Conventional_Placements
     (R           : in out Renderer;
      Snapshot    : Terminal.Core.Render_Snapshot;
      Delete_Data : Boolean);

   procedure Delete_Orphaned_Relative_Placements
     (R         : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Preserve_Image_ID : Terminal.Core.Graphics_ID := 0;
      Delete_Data : Boolean := False)
     renames Graphics_Synchronization.Delete_Orphaned_Relative_Placements;

   procedure Synchronize_Graphics_Screen
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot)
     renames Graphics_Synchronization.Synchronize_Screen;

   procedure Synchronize_Graphics_Scroll
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot;
      Through  : Terminal.Core.Graphics_Scroll_Sequence)
     renames Graphics_Synchronization.Synchronize_Scroll;

   type Image_Storage_Order_List is
     array (Positive range 1 .. Max_Kitty_Image_Objects) of
       Interfaces.Unsigned_64;

   procedure Remember_Deleted_Image
     (Orders : in out Image_Storage_Order_List;
      Count  : in out Natural;
      Order  : Interfaces.Unsigned_64)
   is
   begin
      for I in 1 .. Count loop
         if Orders (I) = Order then
            return;
         end if;
      end loop;
      if Order /= 0 and then Count < Orders'Length then
         Count := Count + 1;
         Orders (Count) := Order;
      end if;
   end Remember_Deleted_Image;

   procedure Delete_Selected_Unplaced_Image_Objects
     (R         : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Orders    : Image_Storage_Order_List;
      Count     : Natural);

   procedure Delete_Conventional_Placements_By_Z
     (R       : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Z_Index : Integer;
      Alternate_Screen : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation;
      Delete_Data : Boolean)
   is separate;

   procedure Delete_Conventional_Placements_Intersecting
     (R          : in out Renderer;
      Stream_ID  : Terminal.Core.Graphics_Stream_ID;
      Row        : Positive;
      Col        : Positive;
      Match_Row  : Boolean := True;
      Match_Col  : Boolean := True;
      Match_Z    : Boolean := False;
      Z_Index    : Integer := 0;
      Match_Screen : Boolean := False;
      Alternate_Screen : Boolean := False;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation := 0;
      Snapshot     : Terminal.Core.Render_Snapshot;
      Delete_Data  : Boolean)
   is separate;

   function Additional_Frame_Image_Commands
     (R     : Renderer;
      Event : Terminal.Core.Graphics_Event) return Natural
     renames Frame_Planning.Additional_Image_Command_Count;

   function Animation_Frame_Due (R : in out Renderer) return Boolean is
     (Animation_State.Frame_Due (R));

   procedure Delete_Image_Object
     (R         : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      ID        : Terminal.Core.Graphics_ID)
     renames Image_Objects.Delete_Object;

   procedure Delete_Selected_Unplaced_Image_Objects
     (R         : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Orders    : Image_Storage_Order_List;
      Count     : Natural)
   is separate;

   procedure Delete_Visible_Conventional_Placements
     (R           : in out Renderer;
      Snapshot    : Terminal.Core.Render_Snapshot;
      Delete_Data : Boolean)
   is separate;

   procedure Delete_Image_ID_Range
     (R           : in out Renderer;
      Stream_ID   : Terminal.Core.Graphics_Stream_ID;
      First_ID    : Terminal.Core.Graphics_ID;
      Last_ID     : Terminal.Core.Graphics_ID;
      Delete_Data : Boolean)
     renames Image_Objects.Delete_ID_Range;

   procedure Touch_Image_Object
     (R      : in out Renderer;
      Object : Image_Object_Access)
     renames Image_Objects.Touch;

   procedure Take_Image_Object
     (R              : in out Renderer;
      Stream_ID      : Terminal.Core.Graphics_Stream_ID;
      ID             : Terminal.Core.Graphics_ID;
      Image_Number   : Terminal.Core.Graphics_ID;
      Usage_Hint     : Natural;
      Protocol       : RM.Image_Protocol;
      Raw_Format     : Natural;
      Pixel_Width    : Natural;
      Pixel_Height   : Natural;
      Decoded_Length : Natural;
      Decoded_Row_Stride_Bytes : Natural;
      Bytes          : in out Terminal.App.Owned_Image_Data.Owner;
      Stored_Object  : out Image_Object_Access;
      Additional_Bytes : Natural := 0;
      Index_Control  : access Terminal.App.Image_Store.Allocation_Control :=
        null)
   is separate;






   procedure Composite_Animation_Frame
     (R      : in out Renderer;
      Object : Image_Object_Access;
      Header : Terminal.App.Graphics.Graphics_Header;
      Data   : Terminal.App.Graphics.Graphics_Data_Preview;
      Canvas : in out Terminal.App.Owned_Image_Data.Owner)
     renames Animation_State.Composite_Frame;

   procedure Apply_Animation_Frame
     (R      : in out Renderer;
      Event  : Terminal.Core.Graphics_Event;
      Header : Terminal.App.Graphics.Graphics_Header;
      Text   : String;
      Allow_Unknown_Compressed_PNG_Size : Boolean := False)
     renames Animation_State.Apply_Frame;


   procedure Apply_Animation_Composition
     (R      : in out Renderer;
      Event  : Terminal.Core.Graphics_Event;
      Header : Terminal.App.Graphics.Graphics_Header)
     renames Animation_State.Apply_Composition;






   procedure Add_Image_Event
     (R                     : in out Renderer;
      Event                 : Terminal.Core.Graphics_Event;
      Resolved_Image_ID     : Terminal.Core.Graphics_ID := 0;
      Resolved_Image_Number : Terminal.Core.Graphics_ID := 0) is separate;

   procedure Apply_Image_Event
     (R      : in out Renderer;
      Event  : Terminal.Core.Graphics_Event;
      Snapshot : Terminal.Core.Render_Snapshot;
      Placement_Status : out Placement_Store_Status) is separate;

   function Graphics_Event_Already_Processed
     (R     : Renderer;
      Event : Terminal.Core.Graphics_Event) return Boolean
     renames Event_Tracking.Already_Processed;

   function Can_Remember_Graphics_Event
     (R     : Renderer;
      Event : Terminal.Core.Graphics_Event) return Boolean
     renames Event_Tracking.Can_Remember;

   procedure Remember_Processed_Graphics_Event
     (R     : in out Renderer;
      Event : Terminal.Core.Graphics_Event;
      Result : Terminal.Core.Graphics_Completion)
     renames Event_Tracking.Remember;

   procedure Add_Image
     (R      : in out Renderer;
      Event  : Terminal.Core.Graphics_Event;
      Snapshot : Terminal.Core.Render_Snapshot)
   is separate;

   procedure Prepare_Placement_Index
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot)
     renames Placements_State.Prepare_Index;

   procedure Add_Conventional_Images
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot)
   is separate;

   procedure Add_Placeholder_Images
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot)
   is separate;

   procedure Add_Underline
     (R      : in out Renderer;
      Kind   : Terminal.Core.Underline_Style;
      X      : Float;
      Y      : Float;
      Width  : Float;
      Color  : RM.Pixel_Color)
     renames Drawing_Commands.Add_Underline;


   function Is_Drawable (Cell : Terminal.Core.Cell_Content) return Boolean
     renames Text_Media.Is_Drawable;

   procedure Build_Text_Runs
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot;
      Cache_Index : Terminal.App.Splits.Pane_Index)
     renames Text_Pipeline.Build_Text_Runs;

   procedure Initialize_Text
     (R      : in out Renderer;
      Font_Path : String;
      Font_Pixel_Size : Positive;
      Bold_Font_Path : String;
      Italic_Font_Path : String;
      Bold_Italic_Font_Path : String;
      Font_Features : String;
      Font_Variations : String;
      Status  : out Init_Status)
   is separate;

   procedure Initialize
     (R       : out Renderer;
      Context : Terminal.App.Vulkan_Context.Context;
      Status  : out Init_Status;
      Font_Path : String := "";
      Font_Pixel_Size : Positive := Default_Font_Pixel_Size;
      Bold_Font_Path : String := "";
      Italic_Font_Path : String := "";
      Bold_Italic_Font_Path : String := "";
      Font_Features : String := "";
      Font_Variations : String := "") is
   begin
      R.Lifecycle.Closed := False;
      R.Lifecycle.Needs_Finalization := True;
      R.Graphics_State.Cleanup_Complete := False;
      if not Terminal.App.Vulkan_Context.Is_Initialized (Context) then
         R.Lifecycle.Initialized := False;
         R.Lifecycle.Has_Context := False;
         Status := Failed;
         return;
      end if;

      R.Lifecycle.Has_Context := True;
      Initialize_Text
        (R, Font_Path, Font_Pixel_Size, Bold_Font_Path, Italic_Font_Path,
         Bold_Italic_Font_Path, Font_Features, Font_Variations, Status);
      if Status /= Ok then
         R.Lifecycle.Has_Context := False;
      end if;
   end Initialize;

   procedure Initialize_Headless
     (R      : out Renderer;
      Status : out Init_Status;
      Font_Path : String := "";
      Font_Pixel_Size : Positive := Default_Font_Pixel_Size;
      Bold_Font_Path : String := "";
      Italic_Font_Path : String := "";
      Bold_Italic_Font_Path : String := "";
      Font_Features : String := "";
      Font_Variations : String := "") is
   begin
      R.Lifecycle.Closed := False;
      R.Lifecycle.Needs_Finalization := True;
      R.Graphics_State.Cleanup_Complete := False;
      R.Lifecycle.Has_Context := False;
      Initialize_Text
        (R, Font_Path, Font_Pixel_Size, Bold_Font_Path, Italic_Font_Path,
         Bold_Italic_Font_Path, Font_Features, Font_Variations, Status);
   end Initialize_Headless;

   procedure Set_Font
     (R               : in out Renderer;
      Font_Path       : String;
      Font_Pixel_Size : Positive;
      Status          : out Font_Update_Status;
      Bold_Font_Path : String := "";
      Italic_Font_Path : String := "";
      Bold_Italic_Font_Path : String := "";
      Font_Features : String := "";
      Font_Variations : String := "")
   is
      Init : Init_Status;
   begin
      Textrender.Reset (R.Text_State.Text);
      Terminal.App.Text_Shaper.Reset (R.Text_State.Shaper);
      R.Text_State.Text_Loaded := False;
      Text_Pipeline.Invalidate_Caches (R);
      Initialize_Text
        (R, Font_Path, Font_Pixel_Size, Bold_Font_Path, Italic_Font_Path,
         Bold_Italic_Font_Path, Font_Features, Font_Variations, Init);
      Status := (if Init = Ok then Font_Ok else Font_Load_Failed);
   exception
      when Storage_Error =>
         R.Text_State.Text_Loaded := False;
         Status := Font_Load_Failed;
   end Set_Font;

   procedure Set_Background_Image
     (R               : in out Renderer;
      Path            : String;
      Opacity_Percent : Natural;
      Status          : out Background_Update_Status)
   is separate;

   procedure Add_Background_Image (R : in out Renderer) is separate;

   procedure Draw_Glyph
     (R         : in out Renderer;
      Codepoint : Terminal.Common.Code_Point;
      X         : Float;
      Y         : Float;
      Color     : RM.Pixel_Color;
      Bold      : Boolean;
      Italic    : Boolean;
      Status    : out Render_Status)
     renames Text_Pipeline.Draw_Glyph;

   function Draw_Emoji_Run_Color
     (R   : in out Renderer;
      Run : RM.Text_Run_Command)
      return Boolean
     renames Text_Pipeline.Draw_Emoji_Run_Color;

   procedure Add_Link_Overlay
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot;
      Status   : out Render_Status)
     renames Text_Pipeline.Add_Link_Overlay;

   procedure Draw_Label
     (R      : in out Renderer;
      Text   : String;
      X      : Float;
      Y      : Float;
      Limit  : Natural;
      Color  : RM.Pixel_Color;
      Status : out Render_Status)
     renames Text_Pipeline.Draw_Label;

   procedure Draw_Shaped_Run
     (R      : in out Renderer;
      Run    : RM.Text_Run_Command;
      Status : out Render_Status)
     renames Text_Pipeline.Draw_Shaped_Run;

   procedure Build_Shaped_Run_Map
     (R         : in out Renderer;
      Snapshot  : Terminal.Core.Render_Snapshot;
      First_Run : Positive)
     renames Text_Pipeline.Build_Shaped_Run_Map;

   function Shaped_Run_At
     (R    : Renderer;
      Cols : Positive;
      Row  : Positive;
      Col  : Positive) return Shaped_Run_Map_Entry
     renames Text_Pipeline.Shaped_Run_At;

   procedure Draw_Snapshot_Into
     (R            : in out Renderer;
      Snapshot     : Terminal.Core.Render_Snapshot;
      Cache_Index  : Terminal.App.Splits.Pane_Index;
      Show_Overlay : Boolean;
      Status       : out Render_Status)
   is separate;

   procedure Render
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot;
      Status   : out Render_Status)
   is separate;

   procedure Build_App_Frame
     (R              : in out Renderer;
      Snapshots      : Snapshot_Array;
      Active_Index   : Positive;
      Tabs           : Terminal.App.Tabs.Tab_Snapshot;
      Layout         : Terminal.App.Splits.Pane_Layout;
      Status         : out Render_Status)
   is separate;

   procedure Set_Framebuffer_Size
     (R      : in out Renderer;
      Width  : Natural;
      Height : Natural) is
   begin
      R.Frame_State.Target_Frame_Width := Width;
      R.Frame_State.Target_Frame_Height := Height;
   end Set_Framebuffer_Size;

   procedure Set_Theme
     (R : in out Renderer;
      T : Terminal.App.Theme.Theme;
      Status : out Theme_Update_Status) is separate;

   procedure Set_Hovered_Link
     (R    : in out Renderer;
      Link : Terminal.Core.Hyperlink) is
   begin
      R.View_State.Hovered_Link := Link;
      Text_Pipeline.Invalidate_Caches (R);
   end Set_Hovered_Link;

   procedure Set_Status_Overlay
     (R    : in out Renderer;
      Text : String)
   is
      Count : constant Natural := Natural'Min (Text'Length, 160);
   begin
      if R.View_State.Overlay_Length = Count
        and then (Count = 0
          or else R.View_State.Overlay_Text (1 .. Count) =
            Text (Text'First .. Text'First + Count - 1))
      then
         return;
      end if;
      R.View_State.Overlay_Length := Count;
      R.View_State.Overlay_Text := (others => ' ');
      if Count > 0 then
         R.View_State.Overlay_Text (1 .. Count) :=
           Text (Text'First .. Text'First + Count - 1);
      end if;
      Text_Pipeline.Invalidate_Caches (R);
   end Set_Status_Overlay;

   procedure Commit_Graphics_Events (R : in out Renderer) is
   begin
      --  Atlas changes remain dirty until the frame carrying them is accepted
      --  by the presentation backend.  A fence deferral or swapchain retry can
      --  therefore rebuild the batch without losing the required upload.
      if R.Text_State.Atlas_Dirty then
         Textrender.Clear_Atlas_Dirty (R.Text_State.Text);
         R.Text_State.Atlas_Dirty := False;
      end if;
      if R.Text_State.Colour_Sheet_Dirty then
         Textrender.Clear_Colour_Sheet_Dirty (R.Text_State.Text);
         R.Text_State.Colour_Sheet_Dirty := False;
      end if;
      Event_Tracking.Clear (R);
   end Commit_Graphics_Events;

   procedure Commit_Offscreen_Graphics_Event
     (R     : in out Renderer;
      Event : Terminal.Core.Graphics_Event) is
   begin
      Event_Tracking.Remove
        (R, Event.Stream_ID, Event.Sequence, Match_Sequence => True);
   end Commit_Offscreen_Graphics_Event;

   procedure Release_Graphics_Stream
     (R         : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID)
   is separate;

   overriding procedure Finalize (R : in out Renderer) is
   begin
      Graphics_Lifecycle.Finalize_Renderer (R);
   end Finalize;

   function Cell_Width (R : Renderer) return Positive is
   begin
      return R.Text_State.CW;
   end Cell_Width;

   function Cell_Height (R : Renderer) return Positive is
   begin
      return R.Text_State.CH;
   end Cell_Height;

   function Content_Padding (R : Renderer) return Natural is
     (R.View_State.Content_Padding);

   procedure Set_Content_Padding
     (R       : in out Renderer;
      Padding : Natural) is
   begin
      R.View_State.Content_Padding :=
        Natural'Min (Padding, Max_Content_Padding);
      Text_Pipeline.Invalidate_Caches (R);
   end Set_Content_Padding;

   procedure Set_Tab_Style
     (R     : in out Renderer;
      Mode  : Terminal.App.Theme.Tab_Bar_Mode;
      Style : Terminal.App.Theme.Tab_Style) is
   begin
      R.View_State.Tab_Bar := Mode;
      R.View_State.Tabs := Style;
   end Set_Tab_Style;

   function Tab_Bar_Visible
     (R : Renderer; Tab_Count : Natural) return Boolean is
     (case R.View_State.Tab_Bar is
        when Terminal.App.Theme.Tab_Auto => Tab_Count > 1,
        when Terminal.App.Theme.Tab_Always => Tab_Count > 0,
        when Terminal.App.Theme.Tab_Never => False);

   function Diagnostics
     (R                     : Renderer;
      Include_Image_Preview : Boolean := True)
      return Renderer_Diagnostics is
     (Diagnostic_State.Capture (R, Include_Image_Preview));

   function Operationally_Equivalent
     (Left, Right : Renderer_Diagnostics) return Boolean is
     (Diagnostic_State.Equivalent (Left, Right));

   function Color_Emoji_Status_Label
     (Diagnostics : Renderer_Diagnostics) return String is
     (Diagnostic_State.Color_Emoji_Label (Diagnostics));

   function Paragraph_Bidi_Status_Label
     (Diagnostics : Renderer_Diagnostics) return String is
     (Diagnostic_State.Paragraph_Bidi_Label (Diagnostics));

   function Image_Status_Label
     (Diagnostics : Renderer_Diagnostics) return String is
     (Diagnostic_State.Image_Label (Diagnostics));

   function Media_Status_Label
     (Diagnostics : Renderer_Diagnostics) return String is
     (Diagnostic_State.Media_Label (Diagnostics));

   function Last_Frame (R : Renderer) return RM.Frame_Commands is separate;
end Terminal.App.Renderer;
