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

   function Bounded_Length (Text : String) return Grid_Status_Length_Range is
     (Grid_Status_Length_Range'Min
        (Text'Length, Terminal.App.Resize.Max_Status_Label_Length));

   function Bounded_Policy_Length
     (Text : String) return Policy_Status_Length_Range is
     (Policy_Status_Length_Range'Min
        (Text'Length, Terminal.App.Render_Policy.Max_Status_Label_Length));

   function Bounded_Scrollback_Length
     (Text : String) return Scrollback_Status_Length_Range is
     (Scrollback_Status_Length_Range'Min
        (Text'Length, Terminal.App.Scrollback_View.Max_Status_Label_Length));

   function Bounded_Selection_Length
     (Text : String) return Selection_Status_Length_Range is
     (Selection_Status_Length_Range'Min
        (Text'Length, Terminal.App.Selection.Max_Status_Label_Length));

   function Bounded_Link_Length (Text : String) return Link_Status_Length_Range is
     (Link_Status_Length_Range'Min
        (Text'Length, Terminal.App.Hyperlinks.Max_Status_Label_Length));

   function Bounded_Clipboard_Length
     (Text : String) return Clipboard_Status_Length_Range is
     (Clipboard_Status_Length_Range'Min
        (Text'Length, Terminal.App.Clipboard_OSC52.Max_Status_Label_Length));

   function Bounded_Tab_Length (Text : String) return Tab_Status_Length_Range is
     (Tab_Status_Length_Range'Min
        (Text'Length, Terminal.App.Tabs.Max_Status_Label_Length));

   function Bounded_Split_Length
     (Text : String) return Split_Status_Length_Range is
     (Split_Status_Length_Range'Min
        (Text'Length, Terminal.App.Splits.Max_Status_Label_Length));

   function Bounded_Config_Length
     (Text : String) return Config_Status_Length_Range is
     (Config_Status_Length_Range'Min
        (Text'Length, Terminal.App.Config.Max_Status_Label_Length));

   function Bounded_Profile_Length
     (Text : String) return Profile_Status_Length_Range is
     (Profile_Status_Length_Range'Min
        (Text'Length, Terminal.App.Max_Status_Label_Length));

   function Bounded_Input_Length
     (Text : String) return Input_Status_Length_Range is
     (Input_Status_Length_Range'Min
        (Text'Length, Terminal.App.Input_Map.Max_Input_Status_Label_Length));

   function Bounded_Mouse_Length
     (Text : String) return Mouse_Status_Length_Range is
     (Mouse_Status_Length_Range'Min
        (Text'Length, Terminal.App.Input_Map.Max_Mouse_Status_Label_Length));

   function Bounded_Cursor_Length
     (Text : String) return Cursor_Status_Length_Range is
     (Cursor_Status_Length_Range'Min
        (Text'Length, Terminal.App.Cursor_Blink.Max_Status_Label_Length));

   function Bounded_Text_Blink_Length
     (Text : String) return Text_Blink_Status_Length_Range is
     (Text_Blink_Status_Length_Range'Min
        (Text'Length, Terminal.App.Text_Blink.Max_Status_Label_Length));

   function Bounded_Theme_Length
     (Text : String) return Theme_Status_Length_Range is
     (Theme_Status_Length_Range'Min
        (Text'Length, Terminal.App.Theme.Max_Status_Label_Length));

   function Bounded_Font_Length
     (Text : String) return Font_Status_Length_Range is
     (Font_Status_Length_Range'Min
        (Text'Length, Terminal.App.Fonts.Max_Status_Label_Length));

   function Bounded_PTY_Backend_Length
     (Text : String) return PTY_Backend_Status_Length_Range is
     (PTY_Backend_Status_Length_Range'Min
        (Text'Length, Terminal.PTY.Backend.Max_Status_Label_Length));

   function Bounded_Multiplexer_Length
     (Text : String) return Multiplexer_Status_Length_Range is
     (Multiplexer_Status_Length_Range'Min
        (Text'Length, Terminal.App.Max_Status_Label_Length));

   function Bounded_Graphics_Header_Length
     (Text : String) return Graphics_Header_Status_Length_Range is
     (Graphics_Header_Status_Length_Range'Min
        (Text'Length, Terminal.App.Graphics.Max_Status_Label_Length));

   function Bounded_Graphics_Data_Length
     (Text : String) return Graphics_Data_Status_Length_Range is
     (Graphics_Data_Status_Length_Range'Min
        (Text'Length, Terminal.App.Graphics.Max_Status_Label_Length));

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
      Grid_Status : constant String := Value (Statuses, Runtime_Status_Kind'Val (0));
      Policy_Status : constant String := Value (Statuses, Runtime_Status_Kind'Val (1));
      Scrollback_Status : constant String := Value (Statuses, Runtime_Status_Kind'Val (2));
      Selection_Status : constant String := Value (Statuses, Runtime_Status_Kind'Val (3));
      Link_Status : constant String := Value (Statuses, Runtime_Status_Kind'Val (4));
      Link_Activation_Status : constant String :=
        Value (Statuses, Runtime_Status_Kind'Val (5));
      Clipboard_Status : constant String := Value (Statuses, Runtime_Status_Kind'Val (6));
      Tab_Status : constant String := Value (Statuses, Runtime_Status_Kind'Val (7));
      Split_Status : constant String := Value (Statuses, Runtime_Status_Kind'Val (8));
      Config_Status : constant String := Value (Statuses, Runtime_Status_Kind'Val (9));
      Profile_Status : constant String := Value (Statuses, Runtime_Status_Kind'Val (10));
      Input_Status : constant String := Value (Statuses, Runtime_Status_Kind'Val (11));
      Mouse_Status : constant String := Value (Statuses, Runtime_Status_Kind'Val (12));
      Cursor_Status : constant String := Value (Statuses, Runtime_Status_Kind'Val (13));
      Text_Blink_Status : constant String := Value (Statuses, Runtime_Status_Kind'Val (14));
      Theme_Status : constant String := Value (Statuses, Runtime_Status_Kind'Val (15));
      Font_Status : constant String := Value (Statuses, Runtime_Status_Kind'Val (16));
      PTY_Backend_Status : constant String :=
        Value (Statuses, Runtime_Status_Kind'Val (17));
      ConPTY_Status : constant String := Value (Statuses, Runtime_Status_Kind'Val (18));
      Multiplexer_Status : constant String :=
        Value (Statuses, Runtime_Status_Kind'Val (19));
      Graphics_Header_Status : constant String :=
        Value (Statuses, Runtime_Status_Kind'Val (20));
      Graphics_Data_Status : constant String :=
        Value (Statuses, Runtime_Status_Kind'Val (21));
      Grid_Length : constant Grid_Status_Length_Range :=
        Bounded_Length (Grid_Status);
      Grid_Text : String (1 .. Terminal.App.Resize.Max_Status_Label_Length) :=
        (others => ' ');
      Policy_Length : constant Policy_Status_Length_Range :=
        Bounded_Policy_Length (Policy_Status);
      Policy_Text :
        String (1 .. Terminal.App.Render_Policy.Max_Status_Label_Length) :=
          (others => ' ');
      Scrollback_Length : constant Scrollback_Status_Length_Range :=
        Bounded_Scrollback_Length (Scrollback_Status);
      Scrollback_Text :
        String (1 .. Terminal.App.Scrollback_View.Max_Status_Label_Length) :=
          (others => ' ');
      Selection_Length : constant Selection_Status_Length_Range :=
        Bounded_Selection_Length (Selection_Status);
      Selection_Text :
        String (1 .. Terminal.App.Selection.Max_Status_Label_Length) :=
          (others => ' ');
      Link_Length : constant Link_Status_Length_Range :=
        Bounded_Link_Length (Link_Status);
      Link_Text : String (1 .. Terminal.App.Hyperlinks.Max_Status_Label_Length) :=
        (others => ' ');
      Link_Activation_Length : constant Link_Status_Length_Range :=
        Bounded_Link_Length (Link_Activation_Status);
      Link_Activation_Text :
        String (1 .. Terminal.App.Hyperlinks.Max_Status_Label_Length) :=
          (others => ' ');
      Clipboard_Length : constant Clipboard_Status_Length_Range :=
        Bounded_Clipboard_Length (Clipboard_Status);
      Clipboard_Text :
        String (1 .. Terminal.App.Clipboard_OSC52.Max_Status_Label_Length) :=
          (others => ' ');
      Tab_Length : constant Tab_Status_Length_Range :=
        Bounded_Tab_Length (Tab_Status);
      Tab_Text : String (1 .. Terminal.App.Tabs.Max_Status_Label_Length) :=
        (others => ' ');
      Split_Length : constant Split_Status_Length_Range :=
        Bounded_Split_Length (Split_Status);
      Split_Text : String (1 .. Terminal.App.Splits.Max_Status_Label_Length) :=
        (others => ' ');
      Config_Length : constant Config_Status_Length_Range :=
        Bounded_Config_Length (Config_Status);
      Config_Text : String (1 .. Terminal.App.Config.Max_Status_Label_Length) :=
        (others => ' ');
      Profile_Length : constant Profile_Status_Length_Range :=
        Bounded_Profile_Length (Profile_Status);
      Profile_Text : String (1 .. Terminal.App.Max_Status_Label_Length) :=
        (others => ' ');
      Input_Length : constant Input_Status_Length_Range :=
        Bounded_Input_Length (Input_Status);
      Input_Text :
        String (1 .. Terminal.App.Input_Map.Max_Input_Status_Label_Length) :=
          (others => ' ');
      Mouse_Length : constant Mouse_Status_Length_Range :=
        Bounded_Mouse_Length (Mouse_Status);
      Mouse_Text :
        String (1 .. Terminal.App.Input_Map.Max_Mouse_Status_Label_Length) :=
          (others => ' ');
      Cursor_Length : constant Cursor_Status_Length_Range :=
        Bounded_Cursor_Length (Cursor_Status);
      Cursor_Text :
        String (1 .. Terminal.App.Cursor_Blink.Max_Status_Label_Length) :=
          (others => ' ');
      Text_Blink_Length : constant Text_Blink_Status_Length_Range :=
        Bounded_Text_Blink_Length (Text_Blink_Status);
      Text_Blink_Text :
        String (1 .. Terminal.App.Text_Blink.Max_Status_Label_Length) :=
          (others => ' ');
      Theme_Length : constant Theme_Status_Length_Range :=
        Bounded_Theme_Length (Theme_Status);
      Theme_Text :
        String (1 .. Terminal.App.Theme.Max_Status_Label_Length) :=
          (others => ' ');
      Font_Length : constant Font_Status_Length_Range :=
        Bounded_Font_Length (Font_Status);
      Font_Text :
        String (1 .. Terminal.App.Fonts.Max_Status_Label_Length) :=
          (others => ' ');
      PTY_Backend_Length : constant PTY_Backend_Status_Length_Range :=
        Bounded_PTY_Backend_Length (PTY_Backend_Status);
      PTY_Backend_Text :
        String (1 .. Terminal.PTY.Backend.Max_Status_Label_Length) :=
          (others => ' ');
      ConPTY_Length : constant PTY_Backend_Status_Length_Range :=
        Bounded_PTY_Backend_Length (ConPTY_Status);
      ConPTY_Text :
        String (1 .. Terminal.PTY.Backend.Max_Status_Label_Length) :=
          (others => ' ');
      Multiplexer_Length : constant Multiplexer_Status_Length_Range :=
        Bounded_Multiplexer_Length (Multiplexer_Status);
      Multiplexer_Text :
        String (1 .. Terminal.App.Max_Status_Label_Length) :=
          (others => ' ');
      Graphics_Header_Length : constant Graphics_Header_Status_Length_Range :=
        Bounded_Graphics_Header_Length (Graphics_Header_Status);
      Graphics_Header_Text :
        String (1 .. Terminal.App.Graphics.Max_Status_Label_Length) :=
          (others => ' ');
      Graphics_Data_Length : constant Graphics_Data_Status_Length_Range :=
        Bounded_Graphics_Data_Length (Graphics_Data_Status);
      Graphics_Data_Text :
        String (1 .. Terminal.App.Graphics.Max_Status_Label_Length) :=
          (others => ' ');
   begin
      for I in 1 .. Grid_Length loop
         Grid_Text (I) := Grid_Status (Grid_Status'First + I - 1);
      end loop;
      for I in 1 .. Policy_Length loop
         Policy_Text (I) := Policy_Status (Policy_Status'First + I - 1);
      end loop;
      for I in 1 .. Scrollback_Length loop
         Scrollback_Text (I) :=
           Scrollback_Status (Scrollback_Status'First + I - 1);
      end loop;
      for I in 1 .. Selection_Length loop
         Selection_Text (I) := Selection_Status (Selection_Status'First + I - 1);
      end loop;
      for I in 1 .. Link_Length loop
         Link_Text (I) := Link_Status (Link_Status'First + I - 1);
      end loop;
      for I in 1 .. Link_Activation_Length loop
         Link_Activation_Text (I) :=
           Link_Activation_Status (Link_Activation_Status'First + I - 1);
      end loop;
      for I in 1 .. Clipboard_Length loop
         Clipboard_Text (I) :=
           Clipboard_Status (Clipboard_Status'First + I - 1);
      end loop;
      for I in 1 .. Tab_Length loop
         Tab_Text (I) := Tab_Status (Tab_Status'First + I - 1);
      end loop;
      for I in 1 .. Split_Length loop
         Split_Text (I) := Split_Status (Split_Status'First + I - 1);
      end loop;
      for I in 1 .. Config_Length loop
         Config_Text (I) := Config_Status (Config_Status'First + I - 1);
      end loop;
      for I in 1 .. Profile_Length loop
         Profile_Text (I) := Profile_Status (Profile_Status'First + I - 1);
      end loop;
      for I in 1 .. Input_Length loop
         Input_Text (I) := Input_Status (Input_Status'First + I - 1);
      end loop;
      for I in 1 .. Mouse_Length loop
         Mouse_Text (I) := Mouse_Status (Mouse_Status'First + I - 1);
      end loop;
      for I in 1 .. Cursor_Length loop
         Cursor_Text (I) := Cursor_Status (Cursor_Status'First + I - 1);
      end loop;
      for I in 1 .. Text_Blink_Length loop
         Text_Blink_Text (I) :=
           Text_Blink_Status (Text_Blink_Status'First + I - 1);
      end loop;
      for I in 1 .. Theme_Length loop
         Theme_Text (I) := Theme_Status (Theme_Status'First + I - 1);
      end loop;
      for I in 1 .. Font_Length loop
         Font_Text (I) := Font_Status (Font_Status'First + I - 1);
      end loop;
      for I in 1 .. PTY_Backend_Length loop
         PTY_Backend_Text (I) :=
           PTY_Backend_Status (PTY_Backend_Status'First + I - 1);
      end loop;
      for I in 1 .. ConPTY_Length loop
         ConPTY_Text (I) := ConPTY_Status (ConPTY_Status'First + I - 1);
      end loop;
      for I in 1 .. Multiplexer_Length loop
         Multiplexer_Text (I) :=
           Multiplexer_Status (Multiplexer_Status'First + I - 1);
      end loop;
      for I in 1 .. Graphics_Header_Length loop
         Graphics_Header_Text (I) :=
           Graphics_Header_Status (Graphics_Header_Status'First + I - 1);
      end loop;
      for I in 1 .. Graphics_Data_Length loop
         Graphics_Data_Text (I) :=
           Graphics_Data_Status (Graphics_Data_Status'First + I - 1);
      end loop;

      return
        (Core            => Terminal.Core.Diagnostics (Core),
         Last_Feed_Status => Last_Feed_Status,
         Last_Write_Status => Last_Write_Status,
         Grid_Status_Length => Grid_Length,
         Grid_Status => Grid_Text,
         Policy_Status_Length => Policy_Length,
         Policy_Status => Policy_Text,
         Scrollback_Status_Length => Scrollback_Length,
         Scrollback_Status => Scrollback_Text,
         Selection_Status_Length => Selection_Length,
         Selection_Status => Selection_Text,
         Link_Status_Length => Link_Length,
         Link_Status => Link_Text,
         Link_Activation_Status_Length => Link_Activation_Length,
         Link_Activation_Status => Link_Activation_Text,
         Clipboard_Status_Length => Clipboard_Length,
         Clipboard_Status => Clipboard_Text,
         Tab_Status_Length => Tab_Length,
         Tab_Status => Tab_Text,
         Split_Status_Length => Split_Length,
         Split_Status => Split_Text,
         Config_Status_Length => Config_Length,
         Config_Status => Config_Text,
         Profile_Status_Length => Profile_Length,
         Profile_Status => Profile_Text,
         Input_Status_Length => Input_Length,
         Input_Status => Input_Text,
         Mouse_Status_Length => Mouse_Length,
         Mouse_Status => Mouse_Text,
         Cursor_Status_Length => Cursor_Length,
         Cursor_Status => Cursor_Text,
         Text_Blink_Status_Length => Text_Blink_Length,
         Text_Blink_Status => Text_Blink_Text,
         Theme_Status_Length => Theme_Length,
         Theme_Status => Theme_Text,
         Font_Status_Length => Font_Length,
         Font_Status => Font_Text,
         PTY_Backend_Status_Length => PTY_Backend_Length,
         PTY_Backend_Status => PTY_Backend_Text,
         ConPTY_Status_Length => ConPTY_Length,
         ConPTY_Status => ConPTY_Text,
         Multiplexer_Status_Length => Multiplexer_Length,
         Multiplexer_Status => Multiplexer_Text,
         Graphics_Header_Status_Length => Graphics_Header_Length,
         Graphics_Header_Status => Graphics_Header_Text,
         Graphics_Data_Status_Length => Graphics_Data_Length,
         Graphics_Data_Status => Graphics_Data_Text,
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
        or else S.Grid_Status_Length /= Last_Snapshot.Grid_Status_Length
        or else S.Grid_Status /= Last_Snapshot.Grid_Status
        or else S.Policy_Status_Length /= Last_Snapshot.Policy_Status_Length
        or else S.Policy_Status /= Last_Snapshot.Policy_Status
        or else
          S.Scrollback_Status_Length /= Last_Snapshot.Scrollback_Status_Length
        or else S.Scrollback_Status /= Last_Snapshot.Scrollback_Status
        or else
          S.Selection_Status_Length /= Last_Snapshot.Selection_Status_Length
        or else S.Selection_Status /= Last_Snapshot.Selection_Status
        or else S.Link_Status_Length /= Last_Snapshot.Link_Status_Length
        or else S.Link_Status /= Last_Snapshot.Link_Status
        or else
          S.Link_Activation_Status_Length /=
            Last_Snapshot.Link_Activation_Status_Length
        or else S.Link_Activation_Status /=
          Last_Snapshot.Link_Activation_Status
        or else
          S.Clipboard_Status_Length /= Last_Snapshot.Clipboard_Status_Length
        or else S.Clipboard_Status /= Last_Snapshot.Clipboard_Status
        or else S.Tab_Status_Length /= Last_Snapshot.Tab_Status_Length
        or else S.Tab_Status /= Last_Snapshot.Tab_Status
        or else S.Split_Status_Length /= Last_Snapshot.Split_Status_Length
        or else S.Split_Status /= Last_Snapshot.Split_Status
        or else S.Config_Status_Length /= Last_Snapshot.Config_Status_Length
        or else S.Config_Status /= Last_Snapshot.Config_Status
        or else S.Profile_Status_Length /= Last_Snapshot.Profile_Status_Length
        or else S.Profile_Status /= Last_Snapshot.Profile_Status
        or else S.Input_Status_Length /= Last_Snapshot.Input_Status_Length
        or else S.Input_Status /= Last_Snapshot.Input_Status
        or else S.Mouse_Status_Length /= Last_Snapshot.Mouse_Status_Length
        or else S.Mouse_Status /= Last_Snapshot.Mouse_Status
        or else S.Cursor_Status_Length /= Last_Snapshot.Cursor_Status_Length
        or else S.Cursor_Status /= Last_Snapshot.Cursor_Status
        or else
          S.Text_Blink_Status_Length /= Last_Snapshot.Text_Blink_Status_Length
        or else S.Text_Blink_Status /= Last_Snapshot.Text_Blink_Status
        or else S.Theme_Status_Length /= Last_Snapshot.Theme_Status_Length
        or else S.Theme_Status /= Last_Snapshot.Theme_Status
        or else S.Font_Status_Length /= Last_Snapshot.Font_Status_Length
        or else S.Font_Status /= Last_Snapshot.Font_Status
        or else
          S.PTY_Backend_Status_Length /=
            Last_Snapshot.PTY_Backend_Status_Length
        or else S.PTY_Backend_Status /= Last_Snapshot.PTY_Backend_Status
        or else S.ConPTY_Status_Length /= Last_Snapshot.ConPTY_Status_Length
        or else S.ConPTY_Status /= Last_Snapshot.ConPTY_Status
        or else
          S.Multiplexer_Status_Length /=
            Last_Snapshot.Multiplexer_Status_Length
        or else S.Multiplexer_Status /= Last_Snapshot.Multiplexer_Status
        or else
          S.Graphics_Header_Status_Length /=
            Last_Snapshot.Graphics_Header_Status_Length
        or else S.Graphics_Header_Status /=
          Last_Snapshot.Graphics_Header_Status
        or else
          S.Graphics_Data_Status_Length /=
            Last_Snapshot.Graphics_Data_Status_Length
        or else S.Graphics_Data_Status /= Last_Snapshot.Graphics_Data_Status
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
         & (if S.Grid_Status_Length = 0
            then ""
            else
              " grid_status=" &
                S.Grid_Status (1 .. S.Grid_Status_Length))
         & (if S.Policy_Status_Length = 0
            then ""
            else
              " render_policy=" &
                S.Policy_Status (1 .. S.Policy_Status_Length))
         & (if S.Scrollback_Status_Length = 0
            then ""
            else
              " scrollback_status=" &
                S.Scrollback_Status (1 .. S.Scrollback_Status_Length))
         & (if S.Selection_Status_Length = 0
            then ""
            else
              " selection_status=" &
                S.Selection_Status (1 .. S.Selection_Status_Length))
         & (if S.Link_Status_Length = 0
            then ""
            else
              " link_status=" &
                S.Link_Status (1 .. S.Link_Status_Length))
         & (if S.Link_Activation_Status_Length = 0
            then ""
            else
              " link_activation=" &
                S.Link_Activation_Status
                  (1 .. S.Link_Activation_Status_Length))
         & (if S.Clipboard_Status_Length = 0
            then ""
            else
              " clipboard_status=" &
                S.Clipboard_Status (1 .. S.Clipboard_Status_Length))
         & (if S.Tab_Status_Length = 0
            then ""
            else
              " tab_status=" &
                S.Tab_Status (1 .. S.Tab_Status_Length))
         & (if S.Split_Status_Length = 0
            then ""
            else
              " split_status=" &
                S.Split_Status (1 .. S.Split_Status_Length))
         & (if S.Config_Status_Length = 0
            then ""
            else
              " config_status=" &
                S.Config_Status (1 .. S.Config_Status_Length))
         & (if S.Profile_Status_Length = 0
            then ""
            else
              " profile_status=" &
                S.Profile_Status (1 .. S.Profile_Status_Length))
         & (if S.Input_Status_Length = 0
            then ""
            else
              " input_status=" &
                S.Input_Status (1 .. S.Input_Status_Length))
         & (if S.Mouse_Status_Length = 0
            then ""
            else
              " mouse_status=" &
                S.Mouse_Status (1 .. S.Mouse_Status_Length))
         & (if S.Cursor_Status_Length = 0
            then ""
            else
              " cursor_status=" &
                S.Cursor_Status (1 .. S.Cursor_Status_Length))
         & (if S.Text_Blink_Status_Length = 0
            then ""
            else
              " text_blink_status=" &
                S.Text_Blink_Status (1 .. S.Text_Blink_Status_Length))
         & (if S.Theme_Status_Length = 0
            then ""
            else
              " theme_status=" &
                S.Theme_Status (1 .. S.Theme_Status_Length))
         & (if S.Font_Status_Length = 0
            then ""
            else
              " font_status=" &
                S.Font_Status (1 .. S.Font_Status_Length))
         & (if S.PTY_Backend_Status_Length = 0
            then ""
            else
              " pty_backend_status=" &
                S.PTY_Backend_Status (1 .. S.PTY_Backend_Status_Length))
         & (if S.ConPTY_Status_Length = 0
            then ""
            else
              " conpty_status=" &
                S.ConPTY_Status (1 .. S.ConPTY_Status_Length))
         & (if S.Multiplexer_Status_Length = 0
            then ""
            else
              " multiplexer_status=" &
                S.Multiplexer_Status (1 .. S.Multiplexer_Status_Length))
         & (if S.Graphics_Header_Status_Length = 0
            then ""
            else
              " graphics_header_status=" &
                S.Graphics_Header_Status
                  (1 .. S.Graphics_Header_Status_Length))
         & (if S.Graphics_Data_Status_Length = 0
            then ""
            else
              " graphics_data_status=" &
                S.Graphics_Data_Status
                  (1 .. S.Graphics_Data_Status_Length))
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
