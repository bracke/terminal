with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Interfaces;

with Terminal.Common.Bytes;
with Terminal.App;
with Terminal.App.Cursor_Blink;
with Terminal.App.Fonts;
with Terminal.App.Graphics;
with Terminal.App.Input_Map;
with Terminal.App.PTY_Write;
with Terminal.App.Queues;
with Terminal.App.Render_Model;
with Terminal.App.Text_Blink;
with Terminal.App.Theme;
with Terminal.App.Vulkan_Device;
with Terminal.App.Vulkan_Submit;
with Terminal.PTY.Backend;

package body Terminal.App.Diagnostics is
   use type Terminal.Core.Ignored_Graphics_Protocol;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Diagnostic_Snapshot;
   use type Terminal.Common.Bytes.Byte_Array;
   use type Terminal.App.PTY_Write.Write_All_Status;
   use type Terminal.App.Cleanup_Diagnostics.Failure_Counts;
   use type Terminal.App.Render_Model.Image_Decode_Status;
   use type Terminal.App.Render_Model.Image_Protocol;
   use type Terminal.App.Renderer.Renderer_Diagnostics;
   use type Terminal.App.Renderer.Render_Status;
   use type Terminal.App.Vulkan_Presenter.Diagnostic_Snapshot;
   use type Terminal.App.Vulkan_Presenter.Present_Status;
   use type Terminal.App.Vulkan_Submit.Texture_Source;
   use type Interfaces.Unsigned_64;

   function Natural_Label (Value : Natural) return String is
     (Ada.Strings.Fixed.Trim (Natural'Image (Value), Ada.Strings.Left));

   Last_Initialized : Boolean := False;
   Last_Snapshot : Snapshot;

   procedure Put (Message : String) is
   begin
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, "terminal: " & Message);
   end Put;

   procedure Set
     (Statuses : in out Runtime_Statuses;
      Kind     : Runtime_Status_Kind;
      Value    : String)
   is
      Length : constant Natural :=
        Natural'Min (Value'Length, Max_Runtime_Status_Length);
   begin
      Statuses (Kind).Length := Length;
      for I in 1 .. Length loop
         Statuses (Kind).Text (I) := Value (Value'First + I - 1);
      end loop;
   end Set;

   function Value
     (Statuses : Runtime_Statuses;
      Kind     : Runtime_Status_Kind) return String is
     (Statuses (Kind).Text (1 .. Statuses (Kind).Length));

   function Collect
     (Core     : Terminal.Core.Terminal;
      PTY      : Terminal.App.Queues.PTY_Output_Queue;
      Input    : Terminal.App.Queues.Input_Event_Queue;
      Renderer : Terminal.App.Renderer.Renderer;
      Presenter : Terminal.App.Vulkan_Presenter.Presenter;
      Last_Feed_Status : Terminal.Core.Feed_Status := Terminal.Core.Ok;
      Last_Write_Status : Terminal.App.PTY_Write.Write_All_Status :=
        Terminal.App.PTY_Write.Ok;
      Statuses : Runtime_Statuses := (others => <>))
      return Snapshot
   is
   begin
      return
        (Core            => Terminal.Core.Diagnostics (Core),
         Last_Feed_Status => Last_Feed_Status,
         Last_Write_Status => Last_Write_Status,
         Statuses        => Statuses,
         Cleanup         => Terminal.App.Cleanup_Diagnostics.Snapshot,
         PTY_Length      => PTY.Length,
         PTY_Overflows   => PTY.Overflow_Count,
         Input_Length    => Input.Length,
         Input_Overflows => Input.Overflow_Count,
         Renderer        => Terminal.App.Renderer.Diagnostics (Renderer),
         Presenter       => Terminal.App.Vulkan_Presenter.Diagnostics (Presenter));
   end Collect;

   procedure Log_Startup_Failure
     (Stage  : String;
      Status : String) is
   begin
      Put ("startup failed at " & Stage & ": " & Status);
   end Log_Startup_Failure;

   function Core_Changed (S : Snapshot) return Boolean is
   begin
      return S.Last_Feed_Status /= Last_Snapshot.Last_Feed_Status
        or else S.Last_Write_Status /= Last_Snapshot.Last_Write_Status
        or else S.Statuses /= Last_Snapshot.Statuses
        or else S.Cleanup /= Last_Snapshot.Cleanup
        or else S.Core /= Last_Snapshot.Core;
   end Core_Changed;

   function Queue_Changed (S : Snapshot) return Boolean is
   begin
      return S.PTY_Overflows /= Last_Snapshot.PTY_Overflows
        or else S.Input_Overflows /= Last_Snapshot.Input_Overflows;
   end Queue_Changed;

   function Renderer_Changed (S : Snapshot) return Boolean is
   begin
      return S.Renderer /= Last_Snapshot.Renderer;
   end Renderer_Changed;

   function Presenter_Change_State
     (Value : Terminal.App.Vulkan_Presenter.Diagnostic_Snapshot)
      return Terminal.App.Vulkan_Presenter.Diagnostic_Snapshot
   is
      Result : Terminal.App.Vulkan_Presenter.Diagnostic_Snapshot := Value;
   begin
      --  Ignore only counters and transient frame measurements that advance
      --  during healthy presentation.  Newly added fields remain observable
      --  by default because Result starts as a complete record copy.
      Result.Accepted_Frames := 0;
      Result.Last_Vertex_Count := 0;
      Result.Last_Text_Run_Count := 0;
      Result.Last_Shaped_Glyph_Count := 0;
      Result.Last_Frame_Width := 0;
      Result.Last_Frame_Height := 0;
      Result.Last_Atlas_Bytes := 0;
      Result.Atlas_Dirty := False;
      Result.Logical_Device.Uploaded_Vertex_Count := 0;
      Result.Logical_Device.Uploaded_Text_Run_Count := 0;
      Result.Logical_Device.Uploaded_Shaped_Glyph_Count := 0;
      Result.Logical_Device.Rendered_Frame_Count := 0;
      Result.Logical_Device.Image_Texture_Cache_Hit_Count := 0;
      Result.Logical_Device.Atlas_Width := 0;
      Result.Logical_Device.Atlas_Height := 0;
      Result.Logical_Device.Atlas_Bytes := 0;
      Result.Logical_Device.Fence_Deferred_Upload_Count := 0;
      return Result;
   end Presenter_Change_State;

   function Presenter_Changed (S : Snapshot) return Boolean is
     (Presenter_Change_State (S.Presenter) /=
        Presenter_Change_State (Last_Snapshot.Presenter));

   procedure Remember (S : Snapshot) is
   begin
      Last_Initialized := True;
      Last_Snapshot := S;
   end Remember;

   function Image_Texture_Pipeline_Status_Label (S : Snapshot) return String is
      function Renderer_Stage return String is
      begin
         if S.Renderer.Last_Image_Count = 0 then
            return "none";
         elsif S.Renderer.Last_Image_Placeholder then
            return "placeholder";
         else
            return "textured";
         end if;
      end Renderer_Stage;

      function Presenter_Stage return String is
      begin
         if S.Presenter.Last_Image_Command_Count = 0 then
            return "none";
         elsif S.Presenter.Last_Image_Texture_Downgraded then
            return "downgraded";
         elsif S.Presenter.Last_Image_Texture_Source =
           Terminal.App.Vulkan_Submit.Texture_Image
           and then S.Presenter.Last_Image_Texture_Vertex_Count > 0
           and then not S.Presenter.Last_Image_Placeholder
         then
            return "ready";
         else
            return "unavailable";
         end if;
      end Presenter_Stage;

      function Device_Stage return String is
      begin
         if S.Presenter.Logical_Device.Uploaded_Image_Command_Count = 0 then
            return "none";
         elsif S.Presenter.Logical_Device.Uploaded_Image_Texture_Downgraded then
            return "downgraded";
         elsif S.Presenter.Logical_Device.Uploaded_Image_Texture_Source =
           Terminal.App.Vulkan_Submit.Texture_Image
           and then S.Presenter.Logical_Device.Uploaded_Image_Texture_Vertex_Count > 0
           and then
             S.Presenter.Logical_Device.Image_Texture_Descriptor_Bound_Count > 0
         then
            return "ready";
         elsif S.Presenter.Logical_Device.Uploaded_Image_Texture_Source =
           Terminal.App.Vulkan_Submit.Texture_Image
         then
            return "pending";
         else
            return "inactive";
         end if;
      end Device_Stage;

      function Overall_Stage return String is
      begin
         if Presenter_Stage = "ready" and then Device_Stage = "ready" then
            return "ready";
         elsif Presenter_Stage = "downgraded"
           or else Device_Stage = "downgraded"
         then
            return "downgraded";
         elsif Device_Stage = "pending" then
            return "pending";
         elsif Renderer_Stage = "placeholder" or else Device_Stage = "inactive" then
            return "placeholder";
         else
            return "unavailable";
         end if;
      end Overall_Stage;
   begin
      if S.Renderer.Last_Image_Count = 0
        and then S.Presenter.Last_Image_Command_Count = 0
        and then S.Presenter.Logical_Device.Uploaded_Image_Command_Count = 0
      then
         return "";
      end if;

      return
        "image texture pipeline " & Overall_Stage
        & "; renderer=" & Renderer_Stage
        & " presenter=" & Presenter_Stage
        & " device=" & Device_Stage
        & (if S.Presenter.Logical_Device.Uploaded_Image_Payload_Preview_Complete
           then " payload=complete"
           else " payload=preview")
        & " texture_vertices=" &
          Natural_Label
            (S.Presenter.Logical_Device.Uploaded_Image_Texture_Vertex_Count)
        & " descriptors=" &
          Natural_Label
            (S.Presenter.Logical_Device.Image_Texture_Descriptor_Bound_Count)
        & "/" &
          Natural_Label
            (S.Presenter.Logical_Device.Image_Texture_Descriptor_Capacity);
   end Image_Texture_Pipeline_Status_Label;

   function Status_Line (S : Snapshot) return String is
      function Field
        (Label : String;
         Kind  : Runtime_Status_Kind) return String
      is
         Text : constant String := Value (S.Statuses, Kind);
      begin
         return (if Text'Length = 0 then "" else " " & Label & "=" & Text);
      end Field;

      Core_Status : constant String :=
        Terminal.Core.Diagnostics_Status_Label (S.Core);
      Feed_Status : constant String :=
        Terminal.Core.Feed_Status_Label (S.Last_Feed_Status);
      Write_Status : constant String :=
        Terminal.App.PTY_Write.Status_Label (S.Last_Write_Status);
      Graphics_Status : constant String :=
        Terminal.App.Graphics.Ignored_Status_Label (S.Core);
      Emoji_Status : constant String :=
        Terminal.App.Renderer.Color_Emoji_Status_Label (S.Renderer);
      Bidi_Status : constant String :=
        Terminal.App.Renderer.Paragraph_Bidi_Status_Label (S.Renderer);
      Image_Status : constant String :=
        Terminal.App.Renderer.Image_Status_Label (S.Renderer);
      Media_Status : constant String :=
        Terminal.App.Renderer.Media_Status_Label (S.Renderer);
      Presenter_Image_Status : constant String :=
        Terminal.App.Vulkan_Presenter.Image_Status_Label (S.Presenter);
      Presenter_Image_Texture_Status : constant String :=
        Terminal.App.Vulkan_Presenter.Image_Texture_Status_Label (S.Presenter);
      Device_Image_Status : constant String :=
        Terminal.App.Vulkan_Device.Image_Status_Label (S.Presenter.Logical_Device);
      Device_Image_Texture_Status : constant String :=
        Terminal.App.Vulkan_Device.Image_Texture_Status_Label
          (S.Presenter.Logical_Device);
      Device_Image_Texture_Resource_Status : constant String :=
        Terminal.App.Vulkan_Presenter.Image_Texture_Resource_Status_Label
          (S.Presenter);
      Image_Texture_Pipeline_Status : constant String :=
        Image_Texture_Pipeline_Status_Label (S);
      Mux_Status : constant String :=
        Terminal.App.Multiplexer_Diagnostic_Label (S.Core);
      PTY_Queue_Status : constant String :=
        Terminal.App.Queues.Queue_Status_Label
          ("pty",
           S.PTY_Length,
           Terminal.App.Queues.Max_Chunks,
           S.PTY_Overflows);
      Input_Queue_Status : constant String :=
        Terminal.App.Queues.Queue_Status_Label
          ("input",
           S.Input_Length,
           Terminal.App.Queues.Max_Input_Events,
           S.Input_Overflows);
      Cleanup_Status : constant String :=
        Terminal.App.Cleanup_Diagnostics.Status_Label (S.Cleanup);
   begin
      return
        ("diag"
         & " presenter_status=" &
           Terminal.App.Vulkan_Presenter.Status_Label
             (S.Presenter.Last_Status)
         & " accepted=" & Natural'Image (S.Presenter.Accepted_Frames)
         & " rejected=" & Natural'Image (S.Presenter.Rejected_Frames)
         & " vertices=" & Natural'Image (S.Presenter.Last_Vertex_Count)
         & " atlas_uploads=" &
           Natural'Image (S.Presenter.Logical_Device.Atlas_Upload_Count)
         & " image_texture_uploads=" &
           Natural'Image
             (S.Presenter.Logical_Device.Image_Texture_Upload_Count)
         & " image_texture_cache_hits=" &
           Natural'Image
             (S.Presenter.Logical_Device.Image_Texture_Cache_Hit_Count)
         & " pty_overflows=" & Natural'Image (S.PTY_Overflows)
         & " input_overflows=" & Natural'Image (S.Input_Overflows)
         & " pty_queue_status=" & PTY_Queue_Status
         & " input_queue_status=" & Input_Queue_Status
         & " feed_status=" & Feed_Status
         & " write_status=" & Write_Status
         & (if Terminal.App.Cleanup_Diagnostics.Total (S.Cleanup) = 0
            then ""
            else " cleanup_status=" & Cleanup_Status)
         & Field ("grid_status", Grid_Status)
         & Field ("render_policy", Policy_Status)
         & Field ("scrollback_status", Scrollback_Status)
         & Field ("selection_status", Selection_Status)
         & Field ("link_status", Link_Status)
         & Field ("link_activation", Link_Activation_Status)
         & Field ("clipboard_status", Clipboard_Status)
         & Field ("tab_status", Tab_Status)
         & Field ("split_status", Split_Status)
         & Field ("config_status", Config_Status)
         & Field ("profile_status", Profile_Status)
         & Field ("input_status", Input_Status)
         & Field ("mouse_status", Mouse_Status)
         & Field ("cursor_status", Cursor_Status)
         & Field ("text_blink_status", Text_Blink_Status)
         & Field ("theme_status", Theme_Status)
         & Field ("font_status", Font_Status)
         & Field ("pty_backend_status", PTY_Backend_Status)
         & Field ("conpty_status", ConPTY_Status)
         & Field ("multiplexer_status", Multiplexer_Status)
         & Field ("graphics_header_status", Graphics_Header_Status)
         & Field ("graphics_data_status", Graphics_Data_Status)
         & " core_status=" & Core_Status
         & " utf8_bad=" & Natural'Image (S.Core.Malformed_UTF8)
         & " parser_overflow=" & Natural'Image (S.Core.Parser_Overflow)
         & " unsupported=" & Natural'Image (S.Core.Unsupported_Sequence)
         & " cluster_overflow=" &
           Natural'Image (S.Core.Text_Cluster_Overflow)
         & " graphics_ignored=" &
           Natural'Image (S.Core.Graphics_Protocol_Ignored)
         & " sixel_ignored=" &
           Natural'Image (S.Core.Sixel_Ignored)
         & " kitty_graphics_ignored=" &
           Natural'Image (S.Core.Kitty_Graphics_Ignored)
         & " iterm2_image_ignored=" &
           Natural'Image (S.Core.ITerm2_Image_Ignored)
         & " last_graphics=" &
           Terminal.App.Graphics.Name (S.Core.Last_Graphics_Protocol)
         & " last_graphics_payload=" &
           Natural'Image (S.Core.Last_Graphics_Payload_Length)
         & (if Graphics_Status = ""
            then ""
            else " graphics_status=" & Graphics_Status)
         & " render=" &
           Terminal.App.Renderer.Render_Status'Image
             (S.Renderer.Last_Render_Status)
         & " graphics_events=" &
           Interfaces.Unsigned_64'Image (S.Renderer.Graphics_Event_Count)
         & " kitty_commands=" &
           Interfaces.Unsigned_64'Image (S.Renderer.Kitty_Command_Count)
         & " kitty_ok=" &
           Interfaces.Unsigned_64'Image (S.Renderer.Kitty_Success_Count)
         & " kitty_errors=" &
           Interfaces.Unsigned_64'Image (S.Renderer.Kitty_Error_Count)
         & " image_objects=" & Natural'Image (S.Renderer.Image_Object_Count)
         & " image_bytes=" & Natural'Image (S.Renderer.Image_Object_Bytes)
         & " image_installs=" &
           Interfaces.Unsigned_64'Image (S.Renderer.Image_Install_Count)
         & " installed_bytes=" &
           Interfaces.Unsigned_64'Image (S.Renderer.Image_Installed_Bytes)
         & " image_evictions=" &
           Interfaces.Unsigned_64'Image (S.Renderer.Image_Eviction_Count)
         & " placements=" & Natural'Image (S.Renderer.Placement_Count)
         & " placement_creates=" &
           Interfaces.Unsigned_64'Image (S.Renderer.Placement_Create_Count)
         & " placement_deletes=" &
           Interfaces.Unsigned_64'Image (S.Renderer.Placement_Delete_Count)
         & " animation_frames=" &
           Natural'Image (S.Renderer.Kitty_Animation_Frame_Count)
         & " animation_advances=" &
           Interfaces.Unsigned_64'Image (S.Renderer.Animation_Advance_Count)
         & " transport_failures=" &
           Interfaces.Unsigned_64'Image (S.Renderer.Transport_Failure_Count)
         & " decode_failures=" &
           Interfaces.Unsigned_64'Image (S.Renderer.Decode_Failure_Count)
         & " allocation_failures=" &
           Interfaces.Unsigned_64'Image (S.Renderer.Allocation_Failure_Count)
         & " chunk_cancels=" &
           Interfaces.Unsigned_64'Image (S.Renderer.Chunk_Cancel_Count)
         & " missing_glyphs=" &
           Natural'Image (S.Renderer.Missing_Glyph_Count)
         & " shaped_glyphs=" &
           Natural'Image (S.Renderer.Last_Shaped_Glyph_Count)
         & " shaping_fallbacks=" &
           Natural'Image (S.Renderer.Last_Shaping_Fallback_Count)
         & " text_fallback_runs=" &
           Natural'Image (S.Renderer.Last_Text_Fallback_Run_Count)
         & " color_glyphs=" &
           Natural'Image (S.Renderer.Last_Color_Glyph_Count)
         & " color_emoji_fallbacks=" &
         Natural'Image (S.Renderer.Last_Color_Emoji_Fallback_Count)
         & " paragraph_bidi_fallbacks=" &
          Natural'Image (S.Renderer.Last_Paragraph_Bidi_Fallback_Count)
         & (if Emoji_Status = ""
            then ""
            else " emoji_status=" & Emoji_Status)
         & (if Bidi_Status = ""
            then ""
            else " bidi_status=" & Bidi_Status)
         & (if Image_Status = ""
            then ""
            else " renderer_image_status=" & Image_Status)
         & (if Media_Status = ""
            then ""
            else " media_status=" & Media_Status)
         & (if Presenter_Image_Status = ""
            then ""
            else " presenter_image_status=" & Presenter_Image_Status)
         & (if Presenter_Image_Texture_Status = ""
            then ""
            else
              " presenter_image_texture_status=" &
                Presenter_Image_Texture_Status)
         & (if Device_Image_Status = ""
            then ""
            else " device_image_status=" & Device_Image_Status)
         & (if Device_Image_Texture_Status = ""
            then ""
            else
              " device_image_texture_status=" & Device_Image_Texture_Status)
         & (if Device_Image_Texture_Resource_Status = ""
            then ""
            else
              " device_image_texture_resource_status=" &
                Device_Image_Texture_Resource_Status)
         & (if Image_Texture_Pipeline_Status = ""
            then ""
            else
              " image_texture_pipeline_status=" &
                Image_Texture_Pipeline_Status)
         & (if Mux_Status = ""
            then ""
            else " mux_status=" & Mux_Status));
   end Status_Line;

   procedure Log_If_Changed (S : Snapshot) is
      Should_Log : constant Boolean :=
        not Last_Initialized
        or else Core_Changed (S)
        or else Queue_Changed (S)
        or else Renderer_Changed (S)
        or else Presenter_Changed (S);
   begin
      if not Should_Log then
         return;
      end if;

      Put (Status_Line (S));

      Remember (S);
   end Log_If_Changed;
end Terminal.App.Diagnostics;
