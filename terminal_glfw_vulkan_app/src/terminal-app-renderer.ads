with Ada.Real_Time;
with Terminal.Common.Bytes;
with Interfaces;
with Terminal.Core;
with Terminal.App.Graphics;
with Terminal.App.Graphics_Transport;
with Terminal.App.ITerm2_Files;
with Terminal.App.Image_Media;
with Terminal.App.Render_Model;
with Terminal.App.Splits;
with Terminal.App.Tabs;
with Terminal.App.Theme;
with Terminal.App.Vulkan_Context;
with Terminal.App.Vulkan_Presenter;
with Terminal.App.Vulkan_Submit;
with Textrender;

package Terminal.App.Renderer is
   Content_Margin : constant Natural := 6;
   Max_Status_Label_Length : constant := 64;
   Max_Kitty_Image_Objects : constant :=
     Terminal.App.Vulkan_Submit.Max_Image_Atlas_Sources;
   Max_Kitty_Image_Bytes   : constant := 64 * 1024 * 1024;
   Max_Kitty_Placements    : constant := 16 * 1024;
   Max_Kitty_Animation_Frames : constant := 4_096;
   Max_Relative_Placement_Depth : constant := 32;
   Max_Graphics_Pixel_Dimension : constant := 16_384;

   type Graphics_Resource_Limits is record
      Image_Objects : Positive range 1 .. Max_Kitty_Image_Objects :=
        Max_Kitty_Image_Objects;
      Image_Bytes   : Positive range 1 .. Max_Kitty_Image_Bytes :=
        Max_Kitty_Image_Bytes;
      Placements    : Positive range 1 .. Max_Kitty_Placements :=
        Max_Kitty_Placements;
      Animation_Frames : Positive range 1 .. Max_Kitty_Animation_Frames :=
        Max_Kitty_Animation_Frames;
      Per_Image_Bytes : Positive range
        1 .. Terminal.App.Render_Model.Max_Image_Decoded_Data_Length :=
          Terminal.App.Render_Model.Max_Image_Decoded_Data_Length;
      Pixel_Dimension : Positive range 1 .. Max_Graphics_Pixel_Dimension :=
        Max_Graphics_Pixel_Dimension;
      GPU_Atlas_Bytes : Positive range
        Terminal.App.Vulkan_Submit.Min_Image_Atlas_Bytes ..
          Terminal.App.Vulkan_Submit.Max_Image_Atlas_Bytes :=
          Terminal.App.Vulkan_Submit.Default_Image_Atlas_Bytes;
      GPU_Atlas_Dimension : Positive range
        Terminal.App.Vulkan_Submit.Min_Image_Atlas_Dimension ..
          Terminal.App.Vulkan_Submit.Max_Image_Atlas_Dimension :=
          Terminal.App.Vulkan_Submit.Default_Image_Atlas_Dimension;
   end record;

   Default_Graphics_Resource_Limits : constant Graphics_Resource_Limits :=
     (others => <>);

   type Renderer is limited private;
   type Snapshot_Array is array (Positive range <>) of Terminal.Core.Render_Snapshot;

   type Init_Status is (Ok, Vulkan_Adapter_Missing, Failed);
   type Render_Status is
     (Ok,
      Not_Initialized,
      Invalid_Snapshot,
      Allocation_Failed,
      Glyph_Load_Failed,
      Batch_Build_Failed,
      Failed);

   type Renderer_Diagnostics is record
      Initialized         : Boolean := False;
      Text_Loaded         : Boolean := False;
      Last_Cell_Count     : Natural := 0;
      Last_Dirty_Rows     : Natural := 0;
      Last_Rectangle_Count : Natural := 0;
      Last_Glyph_Count    : Natural := 0;
      Last_Image_Count    : Natural := 0;
      Last_Image_Protocol : Terminal.App.Render_Model.Image_Protocol :=
        Terminal.App.Render_Model.Image_Sixel;
      Last_Image_Width : Natural := 0;
      Last_Image_Height : Natural := 0;
      Last_Image_Raw_Format : Natural := 0;
      Last_Image_Pixel_Width : Natural := 0;
      Last_Image_Pixel_Height : Natural := 0;
      Last_Image_Payload_Length : Natural := 0;
      Last_Image_Staging_Byte_Length : Natural := 0;
      Last_Image_Payload_Preview_Complete : Boolean := False;
      Last_Image_Encoded_Preview_Length : Natural := 0;
      Last_Image_Decoded_Preview_Length : Natural := 0;
      Last_Image_Decoded_Preview_Bytes : Terminal.Common.Bytes.Byte_Array
        (1 .. Terminal.App.Render_Model.Max_Image_Decoded_Preview_Length) :=
          (others => 0);
      Last_Image_Preview_Decode_Complete : Boolean := False;
      Last_Image_Decode_Status :
        Terminal.App.Render_Model.Image_Decode_Status :=
          Terminal.App.Render_Model.Image_Decode_Not_Attempted;
      Last_Media_Diagnostic : Terminal.App.Image_Media.Decode_Diagnostic;
      Last_Media_Peak_Working_Bytes : Natural := 0;
      Last_Image_Placeholder : Boolean := False;
      Image_Object_Count : Natural := 0;
      Image_Object_Bytes : Natural := 0;
      Placement_Count    : Natural := 0;
      --  Compatibility aliases retained for callers written before Sixel and
      --  iTerm2 images began sharing the same bounded object store.
      Kitty_Image_Object_Count : Natural := 0;
      Kitty_Image_Object_Bytes : Natural := 0;
      Kitty_Placement_Count    : Natural := 0;
      Kitty_Animation_Frame_Count : Natural := 0;
      Graphics_Event_Count : Interfaces.Unsigned_64 := 0;
      Kitty_Command_Count : Interfaces.Unsigned_64 := 0;
      Kitty_Success_Count : Interfaces.Unsigned_64 := 0;
      Kitty_Error_Count : Interfaces.Unsigned_64 := 0;
      Image_Install_Count : Interfaces.Unsigned_64 := 0;
      Image_Installed_Bytes : Interfaces.Unsigned_64 := 0;
      Image_Eviction_Count : Interfaces.Unsigned_64 := 0;
      Placement_Create_Count : Interfaces.Unsigned_64 := 0;
      Placement_Delete_Count : Interfaces.Unsigned_64 := 0;
      Transport_Failure_Count : Interfaces.Unsigned_64 := 0;
      Decode_Failure_Count : Interfaces.Unsigned_64 := 0;
      Allocation_Failure_Count : Interfaces.Unsigned_64 := 0;
      Animation_Advance_Count : Interfaces.Unsigned_64 := 0;
      Chunk_Cancel_Count : Interfaces.Unsigned_64 := 0;
      Last_Text_Run_Count : Natural := 0;
      Last_Shaped_Glyph_Count : Natural := 0;
      Last_Shaping_Fallback_Count : Natural := 0;
      Last_Text_Fallback_Run_Count : Natural := 0;
      Last_Color_Glyph_Count : Natural := 0;
      Last_Color_Emoji_Fallback_Count : Natural := 0;
      Last_Paragraph_Bidi_Fallback_Count : Natural := 0;
      Last_Vertex_Count   : Natural := 0;
      Missing_Glyph_Count : Natural := 0;
      Atlas_Dirty         : Boolean := False;
      Last_Render_Status  : Render_Status := Not_Initialized;
   end record;

   procedure Initialize
     (R       : out Renderer;
      Context : Terminal.App.Vulkan_Context.Context;
      Status  : out Init_Status);
   procedure Initialize_Headless
     (R      : out Renderer;
      Status : out Init_Status);
   procedure Set_Graphics_Resource_Limits
     (R      : in out Renderer;
      Limits : Graphics_Resource_Limits);
   function Graphics_Resource_Limit
     (R : Renderer) return Graphics_Resource_Limits;
   procedure Set_Graphics_Access_Policy
     (R      : in out Renderer;
      Policy : Terminal.App.Graphics_Transport.Access_Policy);
   function Graphics_Access_Policy
     (R : Renderer) return Terminal.App.Graphics_Transport.Access_Policy;
   procedure Set_ITerm2_Download_Policy
     (R      : in out Renderer;
      Policy : Terminal.App.ITerm2_Files.Download_Policy);
   function ITerm2_Download_Policy
     (R : Renderer) return Terminal.App.ITerm2_Files.Download_Policy;
   procedure Stage_Graphics_Event
     (R       : in out Renderer;
      Event   : Terminal.Core.Graphics_Event;
      Payload : String);
   procedure Render
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot;
      Status   : out Render_Status);
   procedure Render_App
     (R              : in out Renderer;
      Snapshots      : Snapshot_Array;
      Active_Index   : Positive;
      Tabs           : Terminal.App.Tabs.Tab_Snapshot;
      Splits         : Terminal.App.Splits.Split_Snapshot;
      Status         : out Render_Status);
   procedure Set_Framebuffer_Size
     (R      : in out Renderer;
      Width  : Natural;
      Height : Natural);
   procedure Set_Theme
     (R : in out Renderer;
      T : Terminal.App.Theme.Theme);
   procedure Set_Hovered_Link
     (R    : in out Renderer;
      Link : Terminal.Core.Hyperlink);
   procedure Present
     (R         : Renderer;
      Context   : Terminal.App.Vulkan_Context.Context;
      Presenter : in out Terminal.App.Vulkan_Presenter.Presenter;
      Status    : out Terminal.App.Vulkan_Presenter.Present_Status);
   procedure Present_Retained
     (R         : Renderer;
      Context   : Terminal.App.Vulkan_Context.Context;
      Presenter : in out Terminal.App.Vulkan_Presenter.Presenter;
      Status    : out Terminal.App.Vulkan_Presenter.Present_Status);
   --  Forget retry guards only after the frame containing the corresponding
   --  graphics events has been accepted by the presentation backend.
   procedure Commit_Graphics_Events (R : in out Renderer);
   --  Finish protocol processing performed for a non-visible session.  Image
   --  atlas changes stay dirty so the next presented frame uploads them.
   procedure Commit_Offscreen_Graphics_Events (R : in out Renderer);
   procedure Release_Graphics_Stream
     (R         : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID);
   function Graphics_Result
     (R     : Renderer;
      Event : Terminal.Core.Graphics_Event)
      return Terminal.Core.Kitty_Graphics_Result;
   function Graphics_Event_Processed
     (R     : Renderer;
      Event : Terminal.Core.Graphics_Event) return Boolean;
   procedure Finalize (R : in out Renderer);

   function Cell_Width (R : Renderer) return Positive;
   function Cell_Height (R : Renderer) return Positive;
   function Diagnostics (R : Renderer) return Renderer_Diagnostics;
   function Color_Emoji_Status_Label
     (Diagnostics : Renderer_Diagnostics) return String;
   function Paragraph_Bidi_Status_Label
     (Diagnostics : Renderer_Diagnostics) return String;
   function Image_Status_Label
     (Diagnostics : Renderer_Diagnostics) return String;
   function Last_Frame (R : Renderer) return Terminal.App.Render_Model.Frame_Commands;

private
   type String_Access is access all String;

   type Image_Object;
   type Image_Object_Access is access Image_Object;

   type Animation_Playback_State is
     (Animation_Stopped, Animation_Loading, Animation_Running);
   type Image_Frame;
   type Image_Frame_Access is access Image_Frame;
   type Image_Frame is record
      Number     : Positive := 2;
      Gap_MS     : Integer := 40;
      Usage_Hint : Natural := 0;
      Bytes      : Terminal.App.Render_Model.Image_Data_Access := null;
      Length     : Natural := 0;
      Next       : Image_Frame_Access := null;
   end record;

   type Theme_Operation;
   type Theme_Operation_Access is access Theme_Operation;
   type Theme_Operation is record
      Is_Composition : Boolean := False;
      Archived_Frames : Boolean := False;
      New_Frame      : Boolean := False;
      Target_Frame   : Positive := 1;
      Base_Frame     : Natural := 0;
      Source_Frame   : Natural := 0;
      Raw_Format     : Natural := 32;
      Data_Width     : Natural := 0;
      Data_Height    : Natural := 0;
      Data_Row_Stride_Bytes : Natural := 0;
      Target_X       : Natural := 0;
      Target_Y       : Natural := 0;
      Source_X       : Natural := 0;
      Source_Y       : Natural := 0;
      Region_Width   : Natural := 0;
      Region_Height  : Natural := 0;
      Composition_Mode : Natural := 0;
      Background_Color : Terminal.Core.Graphics_ID := 0;
      Bytes          : Terminal.App.Render_Model.Image_Data_Access := null;
      Length         : Natural := 0;
      Next           : Theme_Operation_Access := null;
   end record;

   type Image_Object is record
      Stream_ID      : Terminal.Core.Graphics_Stream_ID := 0;
      ID             : Terminal.Core.Graphics_ID := 0;
      Number         : Terminal.Core.Graphics_ID := 0;
      Protocol       : Terminal.App.Render_Model.Image_Protocol :=
        Terminal.App.Render_Model.Image_Kitty;
      Raw_Format     : Natural := 0;
      Pixel_Width    : Natural := 0;
      Pixel_Height   : Natural := 0;
      Decoded_Length : Natural := 0;
      Decoded_Row_Stride_Bytes : Natural := 0;
      Usage_Hint     : Natural := 0;
      Storage_Order  : Interfaces.Unsigned_64 := 0;
      Content_Serial : Interfaces.Unsigned_64 := 0;
      Bytes          : Terminal.App.Render_Model.Image_Data_Access := null;
      Indexed_Format : Natural := 0;
      Indexed_Length : Natural := 0;
      Indexed_Row_Stride_Bytes : Natural := 0;
      Indexed_Bytes  : Terminal.App.Render_Model.Image_Data_Access := null;
      Frames         : Image_Frame_Access := null;
      Frame_Count    : Positive := 1;
      Frame_Bytes    : Natural := 0;
      Theme_Operations : Theme_Operation_Access := null;
      Theme_Operations_Tail : Theme_Operation_Access := null;
      Theme_Operation_Count : Natural := 0;
      Theme_Operation_Bytes : Natural := 0;
      Root_Gap_MS    : Integer := 0;
      Current_Frame  : Positive := 1;
      Playback       : Animation_Playback_State := Animation_Stopped;
      Loop_Count     : Positive := 1;
      Loops_Completed : Natural := 0;
      Next_Frame_At  : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Deadline_Set   : Boolean := False;
      Next           : Image_Object_Access := null;
   end record;

   type Virtual_Placement;
   type Virtual_Placement_Access is access Virtual_Placement;

   type Virtual_Placement is record
      Stream_ID      : Terminal.Core.Graphics_Stream_ID := 0;
      Alternate_Screen : Boolean := False;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation := 0;
      Image_ID       : Terminal.Core.Graphics_ID := 0;
      Image_Storage_Order : Interfaces.Unsigned_64 := 0;
      Placement_ID   : Terminal.Core.Graphics_ID := 0;
      Columns        : Positive := 1;
      Rows           : Positive := 1;
      Source_X       : Natural := 0;
      Source_Y       : Natural := 0;
      Source_Width   : Natural := 0;
      Source_Height  : Natural := 0;
      Cell_X         : Natural := 0;
      Cell_Y         : Natural := 0;
      Draw_Offset_X  : Natural := 0;
      Draw_Offset_Y  : Natural := 0;
      Draw_Width     : Positive := 1;
      Draw_Height    : Positive := 1;
      Z_Index        : Integer := 0;
      Parent_Offset_X : Integer := 0;
      Parent_Offset_Y : Integer := 0;
      Next           : Virtual_Placement_Access := null;
   end record;

   type Conventional_Placement;
   type Conventional_Placement_Access is access Conventional_Placement;

   type Conventional_Placement is record
      Stream_ID      : Terminal.Core.Graphics_Stream_ID := 0;
      Alternate_Screen : Boolean := False;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation := 0;
      Image_ID       : Terminal.Core.Graphics_ID := 0;
      Image_Storage_Order : Interfaces.Unsigned_64 := 0;
      Protocol       : Terminal.App.Render_Model.Image_Protocol :=
        Terminal.App.Render_Model.Image_Kitty;
      Placement_ID   : Terminal.Core.Graphics_ID := 0;
      Row            : Integer := 1;
      Col            : Positive := 1;
      Columns        : Positive := 1;
      Rows           : Positive := 1;
      Source_X       : Natural := 0;
      Source_Y       : Natural := 0;
      Source_Width   : Natural := 0;
      Source_Height  : Natural := 0;
      Cell_X         : Natural := 0;
      Cell_Y         : Natural := 0;
      Draw_Offset_X  : Natural := 0;
      Draw_Offset_Y  : Natural := 0;
      Draw_Width     : Positive := 1;
      Draw_Height    : Positive := 1;
      Z_Index        : Integer := 0;
      Parent_Image_ID : Terminal.Core.Graphics_ID := 0;
      Parent_Placement_ID : Terminal.Core.Graphics_ID := 0;
      Parent_Offset_X : Integer := 0;
      Parent_Offset_Y : Integer := 0;
      Scroll_Sequence : Terminal.Core.Graphics_Scroll_Sequence := 0;
      Clip_Top        : Natural := 0;
      Clip_Bottom     : Natural := 0;
      History_Attached : Boolean := False;
      Next           : Conventional_Placement_Access := null;
   end record;

   --  A frame can consume at most one pending event from each pane.  Results
   --  are committed before the next application frame, so reserving the pane
   --  limit avoids both a late allocation and a large per-renderer object.
   Max_Processed_Graphics_Events : constant := Terminal.App.Splits.Max_Panes;
   type Processed_Graphics_Event is record
      Stream_ID : Terminal.Core.Graphics_Stream_ID := 0;
      Sequence  : Terminal.Core.Graphics_Event_Sequence := 0;
      Result    : Terminal.Core.Kitty_Graphics_Result := (others => <>);
   end record;
   type Processed_Graphics_Event_Array is
     array (Positive range 1 .. Max_Processed_Graphics_Events) of
       Processed_Graphics_Event;

   type Staged_Graphics_Event;
   type Staged_Graphics_Event_Access is access Staged_Graphics_Event;
   type Staged_Graphics_Event is record
      Stream_ID : Terminal.Core.Graphics_Stream_ID := 0;
      Sequence  : Terminal.Core.Graphics_Event_Sequence := 0;
      Payload   : String_Access := null;
      Next      : Staged_Graphics_Event_Access := null;
   end record;

   type Sixel_Palette_Entry;
   type Sixel_Palette_Entry_Access is access Sixel_Palette_Entry;
   type Sixel_Palette_Entry is record
      Stream_ID : Terminal.Core.Graphics_Stream_ID := 0;
      Palette   : Terminal.App.Graphics.Sixel_Palette_State :=
        Terminal.App.Graphics.Default_Sixel_Palette;
      Next      : Sixel_Palette_Entry_Access := null;
   end record;

   type Shaped_Run_Map_Entry is record
      Run_Index   : Natural := 0;
      Starts_Here : Boolean := False;
   end record;
   type Shaped_Run_Map_Array is
     array (Positive range <>) of Shaped_Run_Map_Entry;
   type Shaped_Run_Map_Array_Access is access Shaped_Run_Map_Array;

   type Renderer is limited record
      Initialized : Boolean := False;
      Has_Context : Boolean := False;
      Text        : Textrender.Renderer;
      Text_Loaded : Boolean := False;
      CW          : Positive := 10;
      CH          : Positive := 20;
      Rectangles  : Terminal.App.Render_Model.Rectangle_Array_Access := null;
      Glyphs      : Terminal.App.Render_Model.Glyph_Array_Access := null;
      Colour_Glyphs : Terminal.App.Render_Model.Colour_Glyph_Array_Access := null;
      Images      : Terminal.App.Render_Model.Image_Array_Access := null;
      Text_Runs   : Terminal.App.Render_Model.Text_Run_Array_Access := null;
      Shaped_Run_Map : Shaped_Run_Map_Array_Access := null;
      Batch       : Terminal.App.Vulkan_Submit.Submission_Batch;
      Rectangle_Count : Natural := 0;
      Glyph_Count : Natural := 0;
      Colour_Glyph_Count : Natural := 0;
      Image_Count : Natural := 0;
      Text_Run_Count : Natural := 0;
      Shaped_Glyph_Count : Natural := 0;
      Shaping_Fallback_Count : Natural := 0;
      Text_Fallback_Run_Count : Natural := 0;
      Color_Glyph_Count : Natural := 0;
      Color_Emoji_Fallback_Count : Natural := 0;
      Paragraph_Bidi_Fallback_Count : Natural := 0;
      Vertex_Count : Natural := 0;
      Missing_Glyph_Count : Natural := 0;
      Last_Cell_Count : Natural := 0;
      Last_Dirty_Rows : Natural := 0;
      Last_Frame_Width : Natural := 0;
      Last_Frame_Height : Natural := 0;
      Target_Frame_Width : Natural := 0;
      Target_Frame_Height : Natural := 0;
      Color_Theme : Terminal.App.Theme.Theme :=
        Terminal.App.Theme.Built_In (Terminal.App.Theme.Default_Dark);
      Hovered_Link : Terminal.Core.Hyperlink;
      Draw_Offset_X : Natural := 0;
      Draw_Offset_Y : Natural := 0;
      Atlas_Dirty : Boolean := False;
      Colour_Sheet_Dirty : Boolean := False;
      Image_Objects : Image_Object_Access := null;
      Next_Automatic_Image_ID : Terminal.Core.Graphics_ID := 1;
      Graphics_Limits : Graphics_Resource_Limits :=
        Default_Graphics_Resource_Limits;
      Graphics_Access : Terminal.App.Graphics_Transport.Access_Policy :=
        Terminal.App.Graphics_Transport.Default_Access_Policy;
      ITerm2_Downloads : Terminal.App.ITerm2_Files.Download_Policy :=
        Terminal.App.ITerm2_Files.Disabled_Policy;
      Next_Storage_Order : Interfaces.Unsigned_64 := 1;
      Next_Content_Serial : Interfaces.Unsigned_64 := 1;
      Last_Stored_Image_Order : Interfaces.Unsigned_64 := 0;
      Last_Stored_Image_Content_Serial : Interfaces.Unsigned_64 := 0;
      Image_Store_Allocation_Failed : Boolean := False;
      Image_Transport_Failed : Boolean := False;
      Last_Animation_Result : Terminal.Core.Kitty_Graphics_Result_Code :=
        Terminal.Core.Kitty_No_Response;
      Image_Object_Count : Natural range 0 .. Max_Kitty_Image_Objects := 0;
      Image_Object_Bytes : Natural range 0 .. Max_Kitty_Image_Bytes := 0;
      Animation_Frame_Count : Natural range 0 .. Max_Kitty_Animation_Frames := 0;
      Graphics_Event_Count : Interfaces.Unsigned_64 := 0;
      Kitty_Command_Count : Interfaces.Unsigned_64 := 0;
      Kitty_Success_Count : Interfaces.Unsigned_64 := 0;
      Kitty_Error_Count : Interfaces.Unsigned_64 := 0;
      Image_Install_Count : Interfaces.Unsigned_64 := 0;
      Image_Installed_Bytes : Interfaces.Unsigned_64 := 0;
      Image_Eviction_Count : Interfaces.Unsigned_64 := 0;
      Placement_Create_Count : Interfaces.Unsigned_64 := 0;
      Placement_Delete_Count : Interfaces.Unsigned_64 := 0;
      Transport_Failure_Count : Interfaces.Unsigned_64 := 0;
      Decode_Failure_Count : Interfaces.Unsigned_64 := 0;
      Allocation_Failure_Count : Interfaces.Unsigned_64 := 0;
      Animation_Advance_Count : Interfaces.Unsigned_64 := 0;
      Chunk_Cancel_Count : Interfaces.Unsigned_64 := 0;
      Last_Media_Diagnostic : Terminal.App.Image_Media.Decode_Diagnostic;
      Last_Media_Peak_Working_Bytes : Natural := 0;
      Virtual_Placements : Virtual_Placement_Access := null;
      Conventional_Placements : Conventional_Placement_Access := null;
      Kitty_Placement_Count : Natural range 0 .. Max_Kitty_Placements := 0;
      Processed_Graphics_Events : Processed_Graphics_Event_Array :=
        (others => (others => <>));
      Processed_Graphics_Event_Count : Natural range
        0 .. Max_Processed_Graphics_Events := 0;
      Graphics_Event_Tracking_Failed : Boolean := False;
      Staged_Graphics_Events : Staged_Graphics_Event_Access := null;
      Sixel_Palettes : Sixel_Palette_Entry_Access := null;
      Last_Render_Status : Render_Status := Not_Initialized;
   end record;
end Terminal.App.Renderer;
