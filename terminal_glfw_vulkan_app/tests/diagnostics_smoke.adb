with Ada.Strings.Fixed;
with AUnit.Assertions;

with Terminal.Common.Bytes;
with Terminal.App;
with Terminal.App.Clipboard_OSC52;
with Terminal.App.Config;
with Terminal.App.Cursor_Blink;
with Terminal.App.Diagnostics;
with Terminal.App.Fonts;
with Terminal.App.Graphics;
with Terminal.App.Hyperlinks;
with Terminal.App.Input_Map;
with Terminal.App.PTY_Write;
with Terminal.App.Render_Model;
with Terminal.App.Render_Policy;
with Terminal.App.Renderer;
with Terminal.App.Resize;
with Terminal.App.Selection;
with Terminal.App.Splits;
with Terminal.App.Tabs;
with Terminal.App.Text_Blink;
with Terminal.App.Theme;
with Terminal.App.Vulkan_Submit;
with Terminal.Core;
with Terminal.PTY.Backend;

procedure Diagnostics_Smoke is
   use AUnit.Assertions;

   function Contains (Text : String; Pattern : String) return Boolean is
     (Ada.Strings.Fixed.Index (Text, Pattern) /= 0);

   S : Terminal.App.Diagnostics.Snapshot := (others => <>);
   Modes : Terminal.Core.Mode_Snapshot;
   Sel : Terminal.App.Selection.Selection_State;
   Tabs : Terminal.App.Tabs.Tab_State;
   Splits : Terminal.App.Splits.Split_State;
   Config : Terminal.App.Config.Config;
   Snapshot : Terminal.Core.Render_Snapshot;

   procedure Set_Status
     (Kind : Terminal.App.Diagnostics.Runtime_Status_Kind;
      Text : String) is
   begin
      Terminal.App.Diagnostics.Set (S.Statuses, Kind, Text);
   end Set_Status;
begin
   Terminal.App.Tabs.Initialize (Tabs);
   Terminal.App.Splits.Initialize (Splits);
   declare
      Policy : constant String :=
        Terminal.App.Render_Policy.Status_Label (Modes, 0, False, False);
      Selection : constant String :=
        Terminal.App.Selection.Status_Label (Sel);
      Activation : constant String :=
        Terminal.App.Hyperlinks.Activation_Status_Label
          (Terminal.App.Hyperlinks.No_Link);
      Tab_Status : constant String := Terminal.App.Tabs.Status_Label (Tabs);
      Split_Status : constant String := Terminal.App.Splits.Status_Label (Splits);
      Config_Status : constant String := Terminal.App.Config.Status_Label (Config);
      Profile_Status : constant String :=
        Terminal.App.Profile_Status_Label (Terminal.App.Profile);
      Input_Status : constant String :=
        Terminal.App.Input_Map.Input_Status_Label (Modes);
      Mouse_Status : constant String :=
        Terminal.App.Input_Map.Mouse_Status_Label (Modes);
      Cursor_Status : constant String :=
        Terminal.App.Cursor_Blink.Status_Label (Snapshot.Cursor, 0);
      Text_Blink_Status : constant String :=
        Terminal.App.Text_Blink.Status_Label (Snapshot, 0);
      Theme_Status : constant String :=
        Terminal.App.Theme.Status_Label (Config.Color_Theme);
      Font_Status : constant String :=
        Terminal.App.Fonts.Status_Label ("/tmp/MainFont.ttf", 3);
      PTY_Capabilities : constant Terminal.PTY.Backend.Backend_Capabilities :=
        Terminal.PTY.Backend.Capabilities;
      PTY_Backend_Status : constant String :=
        Terminal.PTY.Backend.Backend_Status_Label (PTY_Capabilities);
      ConPTY_Status : constant String :=
        Terminal.PTY.Backend.ConPTY_Status_Label (PTY_Capabilities);
      Multiplexer_Status : constant String :=
        Terminal.App.Multiplexer_Status_Label (Terminal.App.Profile);
      Graphics_Event : Terminal.Core.Graphics_Event :=
        (Pending        => True,
         Protocol       => Terminal.Core.Kitty_Graphics,
         Cancelled      => False,
         Stream_ID      => 0,
         Sequence       => 0,
         Transaction_Generation => 0,
         Alternate_Screen => False,
         Screen_Generation => 0,
         Scroll_Sequence => 0,
         Sixel_Private_Colors => True,
         Row            => 1,
         Col            => 1,
         Payload_Length => 14,
         Preview_Length => 14,
         Preview        => (others => ASCII.NUL));
      Graphics_Header_Status : String
        (1 .. Terminal.App.Graphics.Max_Status_Label_Length) :=
          (others => ' ');
      Graphics_Header_Length : Natural := 0;
      Graphics_Data_Status : String
        (1 .. Terminal.App.Graphics.Max_Status_Label_Length) :=
          (others => ' ');
      Graphics_Data_Length : Natural := 0;
   begin
      Graphics_Event.Preview (1 .. Graphics_Event.Preview_Length) :=
        "Gf=32,a=T;AAAA";
      declare
         Label : constant String :=
           Terminal.App.Graphics.Header_Status_Label (Graphics_Event);
      begin
         Graphics_Header_Length := Label'Length;
         Graphics_Header_Status (1 .. Graphics_Header_Length) := Label;
      end;
      declare
         Label : constant String :=
           Terminal.App.Graphics.Data_Status_Label (Graphics_Event);
      begin
         Graphics_Data_Length := Label'Length;
         Graphics_Data_Status (1 .. Graphics_Data_Length) := Label;
      end;
      Set_Status (Terminal.App.Diagnostics.Policy_Status, Policy);
      Set_Status (Terminal.App.Diagnostics.Selection_Status, Selection);
      Set_Status (Terminal.App.Diagnostics.Link_Activation_Status, Activation);
      Set_Status (Terminal.App.Diagnostics.Tab_Status, Tab_Status);
      Set_Status (Terminal.App.Diagnostics.Split_Status, Split_Status);
      Set_Status (Terminal.App.Diagnostics.Config_Status, Config_Status);
      Set_Status (Terminal.App.Diagnostics.Profile_Status, Profile_Status);
      Set_Status (Terminal.App.Diagnostics.Input_Status, Input_Status);
      Set_Status (Terminal.App.Diagnostics.Mouse_Status, Mouse_Status);
      Set_Status (Terminal.App.Diagnostics.Cursor_Status, Cursor_Status);
      Set_Status (Terminal.App.Diagnostics.Text_Blink_Status, Text_Blink_Status);
      Set_Status (Terminal.App.Diagnostics.Theme_Status, Theme_Status);
      Set_Status (Terminal.App.Diagnostics.Font_Status, Font_Status);
      Set_Status
        (Terminal.App.Diagnostics.PTY_Backend_Status, PTY_Backend_Status);
      Set_Status (Terminal.App.Diagnostics.ConPTY_Status, ConPTY_Status);
      Set_Status
        (Terminal.App.Diagnostics.Multiplexer_Status, Multiplexer_Status);
      Set_Status
        (Terminal.App.Diagnostics.Graphics_Header_Status,
         Graphics_Header_Status (1 .. Graphics_Header_Length));
      Set_Status
        (Terminal.App.Diagnostics.Graphics_Data_Status,
         Graphics_Data_Status (1 .. Graphics_Data_Length));
      S.Renderer.Last_Image_Count := 1;
      S.Renderer.Last_Image_Protocol := Terminal.App.Render_Model.Image_Kitty;
      S.Renderer.Last_Image_Width := 30;
      S.Renderer.Last_Image_Height := 16;
      S.Renderer.Last_Image_Payload_Length := 14;
      S.Renderer.Last_Image_Payload_Preview_Complete := True;
      S.Renderer.Last_Image_Encoded_Preview_Length := 4;
      S.Renderer.Last_Image_Decoded_Preview_Length := 3;
      S.Renderer.Last_Image_Decoded_Preview_Bytes (1) :=
        Terminal.Common.Bytes.Byte (16#41#);
      S.Renderer.Last_Image_Decoded_Preview_Bytes (2) :=
        Terminal.Common.Bytes.Byte (16#42#);
      S.Renderer.Last_Image_Decoded_Preview_Bytes (3) :=
        Terminal.Common.Bytes.Byte (16#43#);
      S.Renderer.Last_Image_Preview_Decode_Complete := True;
      S.Renderer.Last_Image_Decode_Status :=
        Terminal.App.Render_Model.Image_Decode_Ok;
      S.Renderer.Last_Image_Placeholder := True;
      S.Renderer.Image_Object_Count := 2;
      S.Renderer.Image_Object_Bytes := 128;
      S.Renderer.Placement_Count := 3;
      S.Renderer.Kitty_Animation_Frame_Count := 4;
      S.Renderer.Graphics_Event_Count := 11;
      S.Renderer.Kitty_Command_Count := 10;
      S.Renderer.Kitty_Success_Count := 8;
      S.Renderer.Kitty_Error_Count := 2;
      S.Renderer.Image_Install_Count := 5;
      S.Renderer.Image_Installed_Bytes := 256;
      S.Renderer.Image_Eviction_Count := 1;
      S.Renderer.Placement_Create_Count := 7;
      S.Renderer.Placement_Delete_Count := 4;
      S.Renderer.Animation_Advance_Count := 9;
      S.Renderer.Transport_Failure_Count := 1;
      S.Renderer.Decode_Failure_Count := 2;
      S.Renderer.Allocation_Failure_Count := 3;
      S.Renderer.Chunk_Cancel_Count := 6;
      S.Presenter.Last_Image_Command_Count := 1;
      S.Presenter.Last_Image_Vertex_Count := 6;
      S.Presenter.Last_Image_Texture_Vertex_Count := 0;
      S.Presenter.Last_Image_Protocol := Terminal.App.Render_Model.Image_Kitty;
      S.Presenter.Last_Image_Width := 30;
      S.Presenter.Last_Image_Height := 16;
      S.Presenter.Last_Image_Payload_Length := 14;
      S.Presenter.Last_Image_Payload_Preview_Complete := True;
      S.Presenter.Last_Image_Encoded_Preview_Length := 4;
      S.Presenter.Last_Image_Decoded_Preview_Length := 3;
      S.Presenter.Last_Image_Decoded_Preview_Bytes (1) :=
        Terminal.Common.Bytes.Byte (16#41#);
      S.Presenter.Last_Image_Decoded_Preview_Bytes (2) :=
        Terminal.Common.Bytes.Byte (16#42#);
      S.Presenter.Last_Image_Decoded_Preview_Bytes (3) :=
        Terminal.Common.Bytes.Byte (16#43#);
      S.Presenter.Last_Image_Preview_Decode_Complete := True;
      S.Presenter.Last_Image_Decode_Status :=
        Terminal.App.Render_Model.Image_Decode_Ok;
      S.Presenter.Last_Image_Placeholder := True;
      S.Presenter.Last_Image_Texture_Source :=
        Terminal.App.Vulkan_Submit.Texture_None;
      S.Presenter.Logical_Device.Uploaded_Image_Command_Count := 1;
      S.Presenter.Logical_Device.Uploaded_Image_Vertex_Count := 6;
      S.Presenter.Logical_Device.Uploaded_Image_Texture_Vertex_Count := 0;
      S.Presenter.Logical_Device.Uploaded_Image_Protocol :=
        Terminal.App.Render_Model.Image_Kitty;
      S.Presenter.Logical_Device.Uploaded_Image_Width := 30;
      S.Presenter.Logical_Device.Uploaded_Image_Height := 16;
      S.Presenter.Logical_Device.Uploaded_Image_Payload_Length := 14;
      S.Presenter.Logical_Device.Uploaded_Image_Payload_Preview_Complete :=
        True;
      S.Presenter.Logical_Device.Uploaded_Image_Encoded_Preview_Length := 4;
      S.Presenter.Logical_Device.Uploaded_Image_Decoded_Preview_Length := 3;
      S.Presenter.Logical_Device.Uploaded_Image_Decoded_Preview_Bytes (1) :=
        Terminal.Common.Bytes.Byte (16#41#);
      S.Presenter.Logical_Device.Uploaded_Image_Decoded_Preview_Bytes (2) :=
        Terminal.Common.Bytes.Byte (16#42#);
      S.Presenter.Logical_Device.Uploaded_Image_Decoded_Preview_Bytes (3) :=
        Terminal.Common.Bytes.Byte (16#43#);
      S.Presenter.Logical_Device.Uploaded_Image_Preview_Decode_Complete := True;
      S.Presenter.Logical_Device.Uploaded_Image_Decode_Status :=
        Terminal.App.Render_Model.Image_Decode_Ok;
      S.Presenter.Logical_Device.Uploaded_Image_Placeholder := True;
      S.Presenter.Logical_Device.Uploaded_Image_Texture_Source :=
        Terminal.App.Vulkan_Submit.Texture_None;
      S.Presenter.Logical_Device.Image_Texture_Descriptor_Capacity := 0;
      S.Presenter.Logical_Device.Image_Texture_Descriptor_Bound_Count := 0;
      S.Presenter.Logical_Device.Image_Texture_Upload_Count := 12;
      S.Presenter.Logical_Device.Image_Texture_Cache_Hit_Count := 34;
   end;

   declare
      Line : constant String := Terminal.App.Diagnostics.Status_Line (S);
   begin
      Assert
        (Terminal.App.Diagnostics.Image_Texture_Pipeline_Status_Label
           ((others => <>)) = "",
         "image texture pipeline status should be silent with no image work");
      Assert
        (Terminal.App.Diagnostics.Image_Texture_Pipeline_Status_Label (S) =
           "image texture pipeline placeholder; renderer=placeholder presenter=unavailable device=inactive payload=complete texture_vertices=0 descriptors=0/0",
         "placeholder image texture pipeline should name every blocked stage");
      Assert
        (Contains (Line, "presenter_status=Present: Not Initialized"),
         "presenter status label should be used");
      Assert
        (Contains
           (Line,
            "image_texture_uploads= 12 image_texture_cache_hits= 34"),
         "GPU image cache counters should be included");
      Assert
        (Contains (Line, "pty_queue_status=pty queue 0/64"),
         "empty pty queue status should be included");
      Assert
        (Contains (Line, "input_queue_status=input queue 0/256"),
         "empty input queue status should be included");
      Assert
        (Contains (Line, "feed_status=Feed: Ok"),
         "default feed status should be included");
      Assert
        (Contains (Line, "write_status=PTY write complete"),
         "default write status should be included");
      Assert
        (Contains (Line, "render_policy=Live rendering active"),
         "default render policy should be included");
      Assert
        (Contains (Line, "selection_status=No local selection"),
         "default selection status should be included");
      Assert
        (Contains (Line, "link_activation=No link under pointer"),
         "default link activation status should be included");
      Assert
        (Contains (Line, "tab_status=Single live session"),
         "tab status should be included");
      Assert
        (Contains (Line, "split_status=Single live pane"),
         "split status should be included");
      Assert
        (Contains
           (Line,
            "config_status=Theme default-dark active; window 960x600; startup grid 24x80"),
         "config status should be included");
      Assert
        (Contains
           (Line,
            "profile_status=xterm-256color truecolor profile; Kitty placeholders; "
            & "OSC 52 selections app-local"),
         "profile status should be included");
      Assert
        (Contains
           (Line,
            "input_status=" &
              Terminal.App.Input_Map.Input_Status_Label (Modes)),
         "input mode status should be included");
      Assert
        (Contains
           (Line,
            "mouse_status=" &
              Terminal.App.Input_Map.Mouse_Status_Label (Modes)),
         "mouse routing status should be included");
      Assert
        (Contains
           (Line,
            "cursor_status=" &
              Terminal.App.Cursor_Blink.Status_Label (Snapshot.Cursor, 0)),
         "cursor status should be included");
      Assert
        (Contains
           (Line,
            "text_blink_status=" &
              Terminal.App.Text_Blink.Status_Label (Snapshot, 0)),
         "text blink status should be included");
      Assert
        (Contains
           (Line,
            "theme_status=" &
              Terminal.App.Theme.Status_Label (Config.Color_Theme)),
         "theme status should be included");
      Assert
        (Contains
           (Line,
            "font_status=Fonts ready; fallbacks=3; primary=MainFont.ttf"),
         "font status should be included");
      Assert
        (Contains
           (Line,
            "pty_backend_status=" &
              Terminal.PTY.Backend.Backend_Status_Label
                (Terminal.PTY.Backend.Capabilities)),
         "PTY backend status should be included");
      Assert
        (Contains
           (Line,
            "conpty_status=" &
              Terminal.PTY.Backend.ConPTY_Status_Label
                (Terminal.PTY.Backend.Capabilities)),
         "ConPTY status should be included");
      Assert
        (Contains
           (Line,
            "multiplexer_status=" &
              Terminal.App.Multiplexer_Status_Label (Terminal.App.Profile)),
         "multiplexer capability status should be included");
      Assert
        (Contains
           (Line,
            "graphics_header_status=kitty header ready; format=32; data previewed"),
         "graphics header status should be included");
      Assert
        (Contains
           (Line,
            "graphics_data_status=kitty data preview decoded=3/4 bytes=000000 decoded"),
         "graphics data status should be included");
      Assert
        (Contains
           (Line,
            "renderer_image_status="
            & Terminal.App.Renderer.Image_Status_Label (S.Renderer)),
         "renderer image status should be included");
      Assert
        (Contains
           (Line,
            "presenter_image_status=presented image kitty size=30x16 vertices=6 payload=14 payload-complete preview=3/4 bytes=414243 texture=none placeholder decoded"),
         "presenter image status should be included");
      Assert
        (Contains
           (Line,
            "presenter_image_texture_status=presenter image texture unavailable; texture=none vertices=0"),
         "presenter image texture status should be included");
      Assert
        (Contains
           (Line,
            "device_image_status=uploaded image kitty size=30x16 vertices=6 payload=14 payload-complete preview=3/4 bytes=414243 texture=none placeholder decoded"),
         "device image status should be included");
      Assert
        (Contains
           (Line,
            "device_image_texture_status=device image texture unavailable; texture=none vertices=0"),
         "device image texture status should be included");
      Assert
        (Contains
           (Line,
            "device_image_texture_resource_status=device image texture resources inactive; texture=none descriptors=0/0"),
         "device image texture resource status should be included");
      Assert
        (Contains
           (Line,
            "image_texture_pipeline_status=image texture pipeline placeholder; renderer=placeholder presenter=unavailable device=inactive payload=complete texture_vertices=0 descriptors=0/0"),
         "image texture pipeline status should be included");
      Assert
        (Contains (Line, "core_status=Diagnostics: clean"),
         "clean core diagnostics label should be included");
      Assert
        (Contains
           (Line,
            "graphics_events= 11 kitty_commands= 10 kitty_ok= 8"
            & " kitty_errors= 2 image_objects= 2 image_bytes= 128"),
         "graphics command and live resource counters should be included");
      Assert
        (Contains
           (Line,
            "image_installs= 5 installed_bytes= 256 image_evictions= 1"
            & " placements= 3 placement_creates= 7 placement_deletes= 4"),
         "graphics ownership counters should be included");
      Assert
        (Contains
           (Line,
            "animation_frames= 4 animation_advances= 9"
            & " transport_failures= 1 decode_failures= 2"
            & " allocation_failures= 3 chunk_cancels= 6"),
         "graphics failure and animation counters should be included");
   end;

   declare
      Ready : Terminal.App.Diagnostics.Snapshot := (others => <>);
   begin
      Ready.Renderer.Last_Image_Count := 1;
      Ready.Renderer.Last_Image_Placeholder := False;
      Ready.Presenter.Last_Image_Command_Count := 1;
      Ready.Presenter.Last_Image_Texture_Vertex_Count := 6;
      Ready.Presenter.Last_Image_Texture_Source :=
        Terminal.App.Vulkan_Submit.Texture_Image;
      Ready.Presenter.Last_Image_Placeholder := False;
      Ready.Presenter.Logical_Device.Uploaded_Image_Command_Count := 1;
      Ready.Presenter.Logical_Device.Uploaded_Image_Payload_Preview_Complete :=
        True;
      Ready.Presenter.Logical_Device.Uploaded_Image_Texture_Vertex_Count := 6;
      Ready.Presenter.Logical_Device.Uploaded_Image_Texture_Source :=
        Terminal.App.Vulkan_Submit.Texture_Image;
      Ready.Presenter.Logical_Device.Uploaded_Image_Placeholder := False;
      Ready.Presenter.Logical_Device.Image_Texture_Descriptor_Capacity := 4;
      Ready.Presenter.Logical_Device.Image_Texture_Descriptor_Bound_Count := 2;

      Assert
        (Terminal.App.Diagnostics.Image_Texture_Pipeline_Status_Label (Ready) =
           "image texture pipeline ready; renderer=textured presenter=ready device=ready payload=complete texture_vertices=6 descriptors=2/4",
         "ready image texture pipeline should expose texture vertices and descriptors");
   end;

   S.PTY_Length := 12;
   S.PTY_Overflows := 1;
   S.Input_Length := 34;
   S.Input_Overflows := 2;
   S.Last_Feed_Status := Terminal.Core.Parser_Recovered;
   S.Last_Write_Status := Terminal.App.PTY_Write.Failed;
   Modes.Synchronized_Update := True;
   declare
      Grid : constant String :=
        Terminal.App.Resize.Grid_Status_Label
          (1024, 768, 10, 20, 6);
      Policy : constant String :=
        Terminal.App.Render_Policy.Status_Label (Modes, 0, False, False);
      Scrollback : constant String := "Scrollback 2/5";
      Link : Terminal.Core.Hyperlink;
      Link_Status : String (1 .. Terminal.App.Hyperlinks.Max_Status_Label_Length);
      Link_Length : Natural := 0;
      Activation : constant String :=
        Terminal.App.Hyperlinks.Activation_Status_Label
          (Terminal.App.Hyperlinks.Ok);
      Clipboard : constant String :=
        Terminal.App.Clipboard_OSC52.Status_Label
          (Terminal.Core.Clipboard_Primary);
   begin
      Link.Active := True;
      Link.URI_Length := 20;
      Link.URI (1 .. Link.URI_Length) := "https://example.test";
      declare
         Label : constant String := Terminal.App.Hyperlinks.Status_Label (Link);
      begin
         Link_Length := Label'Length;
         Link_Status (1 .. Link_Length) := Label;
      end;
      Set_Status (Terminal.App.Diagnostics.Grid_Status, Grid);
      Set_Status (Terminal.App.Diagnostics.Policy_Status, Policy);
      Set_Status (Terminal.App.Diagnostics.Scrollback_Status, Scrollback);
      Set_Status
        (Terminal.App.Diagnostics.Link_Status,
         Link_Status (1 .. Link_Length));
      Set_Status (Terminal.App.Diagnostics.Link_Activation_Status, Activation);
      Set_Status (Terminal.App.Diagnostics.Clipboard_Status, Clipboard);
   end;
   S.Core.Malformed_UTF8 := 1;
   S.Core.Ignored_Escape := 2;
   S.Core.Graphics_Protocol_Ignored := 1;
   S.Core.Sixel_Ignored := 1;
   S.Core.Last_Graphics_Protocol := Terminal.Core.Sixel_Graphics;
   S.Core.Last_Graphics_Payload_Length := 42;
   S.Core.Multiplexer_Passthrough := 1;

   declare
      Line : constant String := Terminal.App.Diagnostics.Status_Line (S);
   begin
      Assert
        (Contains
           (Line,
            "core_status=Diagnostics: issues=5 utf8=1 esc=2 parse=0"),
         "aggregate core diagnostics label should be included");
      Assert
        (Contains (Line, "feed_status=Feed: Parser Recovered"),
         "parser-recovered feed status should be included");
      Assert
        (Contains (Line, "write_status=PTY write failed"),
         "failed write status should be included");
      Assert
        (Contains (Line, "grid_status=Grid 37x101 from 1024x768 px"),
         "grid status should be included");
      Assert
        (Contains
           (Line,
            "render_policy=Synchronized update defers live rendering"),
         "deferred render policy should be included");
      Assert
        (Contains (Line, "scrollback_status=Scrollback 2/5"),
         "scrollback status should be included");
      Assert
        (Contains (Line, "link_status=Open https://example.test"),
         "hovered link status should be included");
      Assert
        (Contains (Line, "link_activation=Link opened"),
         "link activation status should be included");
      Assert
        (Contains
           (Line,
            "clipboard_status=Primary target uses app-local selection"),
         "clipboard target status should be included");
      Assert
        (Contains (Line, "pty_queue_status=pty queue 12/64; overflows=1"),
         "pty pressure label should include overflows");
      Assert
        (Contains (Line, "input_queue_status=input queue 34/256; overflows=2"),
         "input pressure label should include overflows");
      Assert
        (Contains
           (Line,
            "graphics_status=Ignored sixel graphics payload (42 bytes)"),
         "graphics ignored label should be included");
      Assert
        (Contains
           (Line,
            "mux_status=tmux passthrough handled 1 sequence"),
         "multiplexer diagnostic label should be included");
   end;
end Diagnostics_Smoke;
