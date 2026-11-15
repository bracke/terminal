with Ada.Finalization;
private with Ada.Real_Time;
with Terminal.Common.Bytes;
with Terminal.Common.Graphics_Limits;
with Interfaces;
with Terminal.Core;
private with Terminal.App.Graphics;
private with Terminal.App.Graphics_Transport;
private with Terminal.App.Frame_Image_Storage;
private with Terminal.App.ITerm2_Files;
with Terminal.App.Image_Decode;
with Terminal.App.Image_Media;
private with Terminal.App.Image_Placements;
private with Terminal.App.Placeholder_Index;
private with Terminal.App.Image_Store;
private with Terminal.App.Owned_Image_Data;
with Terminal.App.Image_Rendering;
with Terminal.App.Render_Model;
private with Terminal.App.Splits;
private with Terminal.App.Tabs;
with Terminal.App.Theme;
with Terminal.App.Vulkan_Context;
with Terminal.App.Vulkan_Limits;
private with Terminal.App.Vulkan_Submit;
private with Terminal.App.Renderer_State;

package Terminal.App.Renderer is
   Content_Margin : constant Natural := 6;
   Max_Status_Label_Length : constant :=
     Terminal.App.Image_Rendering.Max_Status_Label_Length;
   Max_Kitty_Image_Objects : constant :=
     Terminal.App.Max_Graphics_Image_Objects;
   Max_Kitty_Image_Bytes   : constant :=
     Terminal.Common.Graphics_Limits.Max_Image_Bytes;
   Max_Kitty_Placements    : constant :=
     Terminal.Common.Graphics_Limits.Max_Placements;
   Max_Kitty_Animation_Frames : constant :=
     Terminal.Common.Graphics_Limits.Max_Animation_Frames;
   --  One complete backup plus replay's two canvases and one published frame.
   Max_Theme_Transaction_Bytes : constant :=
     Max_Kitty_Image_Bytes * 4;
   Max_Relative_Placement_Depth : constant := 32;
   Max_Graphics_Pixel_Dimension : constant :=
     Terminal.Common.Graphics_Limits.Max_Pixel_Dimension;

   type Graphics_Resource_Limits is record
      Image_Objects : Positive range 1 .. Max_Kitty_Image_Objects :=
        Max_Kitty_Image_Objects;
      Image_Bytes : Positive range 1 .. Max_Kitty_Image_Bytes :=
        Max_Kitty_Image_Bytes;
      Placements : Positive range 1 .. Max_Kitty_Placements :=
        Max_Kitty_Placements;
      Animation_Frames : Positive range 1 .. Max_Kitty_Animation_Frames :=
        Max_Kitty_Animation_Frames;
      Per_Image_Bytes : Positive range 1 .. Max_Kitty_Image_Bytes :=
        Max_Kitty_Image_Bytes;
      Theme_Transaction_Bytes : Positive range
        1 .. Max_Theme_Transaction_Bytes := Max_Theme_Transaction_Bytes;
      Pixel_Dimension : Positive range 1 .. Max_Graphics_Pixel_Dimension :=
        Max_Graphics_Pixel_Dimension;
      GPU_Atlas_Bytes : Positive range
        Terminal.App.Vulkan_Limits.Min_Atlas_Bytes ..
          Terminal.App.Vulkan_Limits.Max_Atlas_Bytes :=
            Terminal.App.Vulkan_Limits.Default_Atlas_Bytes;
      GPU_Atlas_Dimension : Positive range
        Terminal.App.Vulkan_Limits.Min_Atlas_Dimension ..
          Terminal.App.Vulkan_Limits.Max_Atlas_Dimension :=
            Terminal.App.Vulkan_Limits.Default_Atlas_Dimension;
   end record;

   Default_Graphics_Resource_Limits : constant Graphics_Resource_Limits :=
     (others => <>);

   type Renderer is new Ada.Finalization.Limited_Controlled with private;
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
   type Theme_Update_Status is
     (Theme_Ok,
      Theme_Closed,
      Theme_Allocation_Failed,
      Theme_Replay_Failed);
   type Font_Update_Status is (Font_Ok, Font_Load_Failed);
   Default_Font_Pixel_Size : constant Positive := 16;

   --  Declaring the diagnostic hierarchy in a nested package prevents its
   --  tagged types from becoming additional controlling types of Renderer
   --  operations.
   package Diagnostic_Types is
   type Operational is tagged record
      Initialized         : Boolean := False;
      Text_Loaded         : Boolean := False;
      Last_Image_Count    : Natural := 0;
      Rectangle_Command_Capacity : Natural := 0;
      Image_Command_Capacity : Natural := 0;
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
      Last_Image_Preview_Decode_Complete : Boolean := False;
      Last_Image_Decode_Status :
        Terminal.App.Render_Model.Image_Decode_Status :=
          Terminal.App.Render_Model.Image_Decode_Not_Attempted;
      Last_Media_Decode_Attempted : Boolean := False;
      Last_Media_Decode_Status : Terminal.App.Image_Media.Decode_Status :=
        Terminal.App.Image_Decode.Decode_Not_Attempted;
      Last_Media_Diagnostic : Terminal.App.Image_Media.Decode_Diagnostic;
      Last_Media_Adapter_Buffer_Bytes : Natural := 0;
      Last_Media_Decoder_Configured_Bytes : Natural := 0;
      Last_Media_Warning_Count : Natural := 0;
      Last_Media_First_Warning : Terminal.App.Image_Media.Decode_Diagnostic;
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
      Last_Render_Status  : Render_Status := Not_Initialized;
   end record;

   type Snapshot is new Operational with record
      Last_Cell_Count     : Natural := 0;
      Last_Dirty_Rows     : Natural := 0;
      Last_Cached_Rows    : Natural := 0;
      Last_Rectangle_Count : Natural := 0;
      Last_Glyph_Count    : Natural := 0;
      Last_Image_Decoded_Preview_Length : Natural := 0;
      Last_Image_Decoded_Preview_Bytes : Terminal.Common.Bytes.Byte_Array
        (1 .. Terminal.App.Render_Model.Max_Image_Decoded_Preview_Length) :=
          (others => 0);
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
   end record;
   end Diagnostic_Types;

   subtype Renderer_Operational_Diagnostics is Diagnostic_Types.Operational;
   subtype Renderer_Diagnostics is Diagnostic_Types.Snapshot;

   procedure Initialize
     (R       : out Renderer;
      Context : Terminal.App.Vulkan_Context.Context;
      Status  : out Init_Status;
      Font_Path : String := "";
      Font_Pixel_Size : Positive := Default_Font_Pixel_Size);
   procedure Initialize_Headless
     (R      : out Renderer;
      Status : out Init_Status;
      Font_Path : String := "";
      Font_Pixel_Size : Positive := Default_Font_Pixel_Size);
   procedure Set_Font
     (R               : in out Renderer;
      Font_Path       : String;
      Font_Pixel_Size : Positive;
      Status          : out Font_Update_Status);
   procedure Render
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot;
      Status   : out Render_Status);
   procedure Set_Framebuffer_Size
     (R      : in out Renderer;
      Width  : Natural;
      Height : Natural);
   procedure Set_Theme
     (R : in out Renderer;
      T : Terminal.App.Theme.Theme;
      Status : out Theme_Update_Status);
   procedure Set_Hovered_Link
     (R    : in out Renderer;
      Link : Terminal.Core.Hyperlink);
   procedure Set_Status_Overlay
     (R    : in out Renderer;
      Text : String);
   overriding procedure Finalize (R : in out Renderer);

   function Cell_Width (R : Renderer) return Positive;
   function Cell_Height (R : Renderer) return Positive;
   function Diagnostics
     (R                     : Renderer;
      Include_Image_Preview : Boolean := True) return Renderer_Diagnostics;
   function Operationally_Equivalent
     (Left, Right : Renderer_Diagnostics) return Boolean;
   function Color_Emoji_Status_Label
     (Diagnostics : Renderer_Diagnostics) return String;
   function Paragraph_Bidi_Status_Label
     (Diagnostics : Renderer_Diagnostics) return String;
   function Image_Status_Label
     (Diagnostics : Renderer_Diagnostics) return String;
   function Media_Status_Label
     (Diagnostics : Renderer_Diagnostics) return String;
private

   --  Domain child packages expose these implementation primitives through
   --  focused public interfaces.  Keeping them private prevents production
   --  callers from bypassing the graphics/layout/presentation boundaries.
   procedure Commit_Graphics_Events (R : in out Renderer);
   procedure Commit_Offscreen_Graphics_Event
     (R     : in out Renderer;
      Event : Terminal.Core.Graphics_Event);
   procedure Build_App_Frame
     (R              : in out Renderer;
      Snapshots      : Snapshot_Array;
      Active_Index   : Positive;
      Tabs           : Terminal.App.Tabs.Tab_Snapshot;
      Splits         : Terminal.App.Splits.Split_Snapshot;
      Status         : out Render_Status);
   procedure Set_Render_Status
     (R      : in out Renderer;
      Status : out Render_Status;
      Value  : Render_Status);
   function Submission_Render_Status
     (Status : Terminal.App.Vulkan_Submit.Build_Status) return Render_Status;
   procedure Release_Graphics_Stream
     (R         : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID);
   function Animation_Frame_Due (R : in out Renderer) return Boolean;

   --  Borrowed frame storage is intentionally private.  The Testing child
   --  exposes it to white-box tests, while production callers receive frame
   --  commands only through the presentation path that owns their lifetime.
   function Last_Frame
     (R : Renderer) return Terminal.App.Render_Model.Frame_Commands;

   type String_Access is access all String;

   subtype Image_Object is Terminal.App.Image_Store.Image_Object;
   subtype Image_Object_Access is Terminal.App.Image_Store.Image_Object_Access;
   subtype Image_Frame is Terminal.App.Image_Store.Image_Frame;
   subtype Image_Frame_Access is Terminal.App.Image_Store.Image_Frame_Access;
   subtype Theme_Operation is Terminal.App.Image_Store.Theme_Operation;
   subtype Theme_Operation_Access is
     Terminal.App.Image_Store.Theme_Operation_Access;
   subtype Animation_Playback_State is
     Terminal.App.Image_Store.Animation_Playback_State;
   Animation_Stopped : constant Animation_Playback_State :=
     Terminal.App.Image_Store.Animation_Stopped;
   Animation_Loading : constant Animation_Playback_State :=
     Terminal.App.Image_Store.Animation_Loading;
   Animation_Running : constant Animation_Playback_State :=
     Terminal.App.Image_Store.Animation_Running;

   procedure Take_Image_Object
     (R              : in out Renderer;
      Stream_ID      : Terminal.Core.Graphics_Stream_ID;
      ID             : Terminal.Core.Graphics_ID;
      Image_Number   : Terminal.Core.Graphics_ID;
      Usage_Hint     : Natural;
      Protocol       : Terminal.App.Render_Model.Image_Protocol;
      Raw_Format     : Natural;
      Pixel_Width    : Natural;
      Pixel_Height   : Natural;
      Decoded_Length : Natural;
      Decoded_Row_Stride_Bytes : Natural;
      Bytes          : in out Terminal.App.Owned_Image_Data.Owner;
      Stored_Object  : out Image_Object_Access;
      Additional_Bytes : Natural := 0;
      Index_Control  : access Terminal.App.Image_Store.Allocation_Control :=
        null);

   subtype Virtual_Placement is
     Terminal.App.Image_Placements.Virtual_Placement;
   subtype Virtual_Placement_State is
     Terminal.App.Image_Placements.Virtual_Placement_State;
   subtype Virtual_Placement_Access is
     Terminal.App.Image_Placements.Virtual_Placement_Access;
   subtype Conventional_Placement is
     Terminal.App.Image_Placements.Conventional_Placement;
   subtype Conventional_Placement_State is
     Terminal.App.Image_Placements.Conventional_Placement_State;
   subtype Conventional_Placement_Access is
     Terminal.App.Image_Placements.Conventional_Placement_Access;

   --  A frame can consume at most one pending event from each pane.  One
   --  additional slot lets the offscreen consumer complete a hidden event
   --  while a visible presentation-retry transaction remains retained.
   Max_Processed_Graphics_Events : constant :=
     Terminal.App.Splits.Max_Panes + 1;
   Max_Staged_Graphics_Events : constant :=
     Max_Processed_Graphics_Events;
   Max_Staged_Graphics_Bytes : constant :=
     Terminal.Common.Graphics_Limits.Max_Transaction_Bytes
       * Max_Staged_Graphics_Events;
   type Processed_Graphics_Event is record
      Stream_ID : Terminal.Core.Graphics_Stream_ID := 0;
      Sequence  : Terminal.Core.Graphics_Event_Sequence := 0;
      Result    : Terminal.Core.Graphics_Completion := (others => <>);
   end record;
   type Processed_Graphics_Event_Array is array
     (Positive range 1 .. Max_Processed_Graphics_Events) of
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

   type Graphics_Resource_State is limited record
      Image_Objects : aliased Terminal.App.Image_Store.Store;
      Allocation_Control : Terminal.App.Image_Store.Allocation_Control;
      Placements : Terminal.App.Image_Placements.Store;
      Sixel_Palettes : Sixel_Palette_Entry_Access := null;
   end record;

   type Graphics_Policy_State is record
      Limits : Graphics_Resource_Limits := Default_Graphics_Resource_Limits;
      Access_Policy : Terminal.App.Graphics_Transport.Access_Policy :=
        Terminal.App.Graphics_Transport.Default_Access_Policy;
      ITerm2_Downloads : Terminal.App.ITerm2_Files.Download_Policy :=
        Terminal.App.ITerm2_Files.Disabled_Policy;
   end record;

   type Graphics_Transaction_State is record
      Next_Automatic_Image_ID : Terminal.Core.Graphics_ID := 1;
      Last_Stored_Image_Order : Interfaces.Unsigned_64 := 0;
      Last_Stored_Image_Content_Serial : Interfaces.Unsigned_64 := 0;
      Transactional_Image_Install : Boolean := False;
      Replaced_Image_Order : Interfaces.Unsigned_64 := 0;
      Image_Store_Allocation_Failed : Boolean := False;
      Image_Transport_Failed : Boolean := False;
      Last_Animation_Result : Terminal.Core.Graphics_Completion_Code :=
        Terminal.Core.Graphics_No_Response;
      Processed_Events : Processed_Graphics_Event_Array :=
        (others => (others => <>));
      Processed_Event_Count :
        Natural range 0 .. Max_Processed_Graphics_Events := 0;
      Event_Tracking_Failed : Boolean := False;
      Staged_Events : Staged_Graphics_Event_Access := null;
      Staged_Event_Count : Natural range 0 .. Max_Staged_Graphics_Events := 0;
      Staged_Byte_Count : Natural range 0 .. Max_Staged_Graphics_Bytes := 0;
      Staged_Payload_Borrows : Natural := 0;
   end record;

   type Graphics_Telemetry_State is record
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
      Last_Media : Terminal.App.Image_Rendering.Media_Diagnostics;
   end record;

   type Graphics_View_Identity is record
      Stream_ID : Terminal.Core.Graphics_Stream_ID := 0;
      Alternate_Screen : Boolean := False;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation := 0;
   end record;
   type Graphics_View_Identity_Array is
     array (Terminal.App.Splits.Pane_Index) of Graphics_View_Identity;

   type Renderer_Graphics_State is
     new Ada.Finalization.Limited_Controlled with record
      Resources   : Graphics_Resource_State;
      Policy      : Graphics_Policy_State;
      Transaction : Graphics_Transaction_State;
      Telemetry   : Graphics_Telemetry_State;
      Animation_Schedule_Valid : Boolean := False;
      Animation_Schedule_Immediate : Boolean := False;
      Animation_Schedule_Has_Deadline : Boolean := False;
      Animation_Schedule_Deadline : Ada.Real_Time.Time :=
        Ada.Real_Time.Time_First;
      Visible_Views : Graphics_View_Identity_Array := (others => <>);
      Visible_View_Count : Terminal.App.Splits.Pane_Count := 0;
      Cleanup_Complete : Boolean := False;
   end record;
   overriding procedure Finalize (Object : in out Renderer_Graphics_State);

   subtype Shaped_Run_Map_Entry is
     Terminal.App.Renderer_State.Shaped_Run_Map_Entry;
   subtype Shaped_Run_Map_Array is
     Terminal.App.Renderer_State.Shaped_Run_Map_Array;
   subtype Shaped_Run_Map_Array_Access is
     Terminal.App.Renderer_State.Shaped_Run_Map_Array_Access;

   type Renderer_Lifecycle_State is record
      Needs_Finalization : Boolean := False;
      Closed      : Boolean := False;
      Initialized : Boolean := False;
      Has_Context : Boolean := False;
      Last_Render_Status : Render_Status := Not_Initialized;
   end record;

   subtype Renderer_Text_State is Terminal.App.Renderer_State.Text_State;
   subtype Renderer_Frame_State is Terminal.App.Renderer_State.Frame_State;
   subtype Renderer_View_State is Terminal.App.Renderer_State.View_State;

   type Renderer is new Ada.Finalization.Limited_Controlled with record
      Lifecycle    : Renderer_Lifecycle_State;
      Text_State   : Renderer_Text_State;
      Frame_State  : Renderer_Frame_State;
      View_State   : Renderer_View_State;
      Graphics_State : Renderer_Graphics_State;
   end record;

   --  Shared mechanics used by the graphics domain child and the ordinary
   --  render lifecycle; policy and public orchestration remain in the child.
   procedure Set_Visible_Graphics_Views
     (R         : in out Renderer;
      Snapshots : Snapshot_Array);
   procedure Set_Visible_Graphics_View
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot);
end Terminal.App.Renderer;
