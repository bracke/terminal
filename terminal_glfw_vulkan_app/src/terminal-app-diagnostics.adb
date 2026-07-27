with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;

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
with Terminal.PTY.POSIX;

package body Terminal.App.Diagnostics is
   use type Terminal.Core.Ignored_Graphics_Protocol;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Common.Bytes.Byte_Array;
   use type Terminal.App.PTY_Write.Write_All_Status;
   use type Terminal.App.Render_Model.Image_Decode_Status;
   use type Terminal.App.Render_Model.Image_Protocol;
   use type Terminal.App.Renderer.Render_Status;
   use type Terminal.App.Vulkan_Presenter.Present_Status;
   use type Terminal.App.Vulkan_Submit.Texture_Source;

   function Natural_Label (Value : Natural) return String is
     (Ada.Strings.Fixed.Trim (Natural'Image (Value), Ada.Strings.Left));

   Last_Initialized : Boolean := False;
   Last_Core : Terminal.Core.Diagnostic_Snapshot;
   Last_Feed_Status : Terminal.Core.Feed_Status := Terminal.Core.Ok;
   Last_Write_Status : Terminal.App.PTY_Write.Write_All_Status :=
     Terminal.App.PTY_Write.Ok;
   Last_Grid_Status_Length : Grid_Status_Length_Range := 0;
   Last_Grid_Status :
     String (1 .. Terminal.App.Resize.Max_Status_Label_Length) :=
       (others => ' ');
   Last_Policy_Status_Length : Policy_Status_Length_Range := 0;
   Last_Policy_Status :
     String (1 .. Terminal.App.Render_Policy.Max_Status_Label_Length) :=
       (others => ' ');
   Last_Scrollback_Status_Length : Scrollback_Status_Length_Range := 0;
   Last_Scrollback_Status :
     String (1 .. Terminal.App.Scrollback_View.Max_Status_Label_Length) :=
       (others => ' ');
   Last_Selection_Status_Length : Selection_Status_Length_Range := 0;
   Last_Selection_Status :
     String (1 .. Terminal.App.Selection.Max_Status_Label_Length) :=
       (others => ' ');
   Last_Link_Status_Length : Link_Status_Length_Range := 0;
   Last_Link_Status :
     String (1 .. Terminal.App.Hyperlinks.Max_Status_Label_Length) :=
       (others => ' ');
   Last_Link_Activation_Status_Length : Link_Status_Length_Range := 0;
   Last_Link_Activation_Status :
     String (1 .. Terminal.App.Hyperlinks.Max_Status_Label_Length) :=
       (others => ' ');
   Last_Clipboard_Status_Length : Clipboard_Status_Length_Range := 0;
   Last_Clipboard_Status :
     String (1 .. Terminal.App.Clipboard_OSC52.Max_Status_Label_Length) :=
       (others => ' ');
   Last_Tab_Status_Length : Tab_Status_Length_Range := 0;
   Last_Tab_Status :
     String (1 .. Terminal.App.Tabs.Max_Status_Label_Length) :=
       (others => ' ');
   Last_Split_Status_Length : Split_Status_Length_Range := 0;
   Last_Split_Status :
     String (1 .. Terminal.App.Splits.Max_Status_Label_Length) :=
       (others => ' ');
   Last_Config_Status_Length : Config_Status_Length_Range := 0;
   Last_Config_Status :
     String (1 .. Terminal.App.Config.Max_Status_Label_Length) :=
       (others => ' ');
   Last_Profile_Status_Length : Profile_Status_Length_Range := 0;
   Last_Profile_Status :
     String (1 .. Terminal.App.Max_Status_Label_Length) :=
       (others => ' ');
   Last_Input_Status_Length : Input_Status_Length_Range := 0;
   Last_Input_Status :
     String (1 .. Terminal.App.Input_Map.Max_Input_Status_Label_Length) :=
       (others => ' ');
   Last_Mouse_Status_Length : Mouse_Status_Length_Range := 0;
   Last_Mouse_Status :
     String (1 .. Terminal.App.Input_Map.Max_Mouse_Status_Label_Length) :=
       (others => ' ');
   Last_Cursor_Status_Length : Cursor_Status_Length_Range := 0;
   Last_Cursor_Status :
     String (1 .. Terminal.App.Cursor_Blink.Max_Status_Label_Length) :=
       (others => ' ');
   Last_Text_Blink_Status_Length : Text_Blink_Status_Length_Range := 0;
   Last_Text_Blink_Status :
     String (1 .. Terminal.App.Text_Blink.Max_Status_Label_Length) :=
       (others => ' ');
   Last_Theme_Status_Length : Theme_Status_Length_Range := 0;
   Last_Theme_Status :
     String (1 .. Terminal.App.Theme.Max_Status_Label_Length) :=
       (others => ' ');
   Last_Font_Status_Length : Font_Status_Length_Range := 0;
   Last_Font_Status :
     String (1 .. Terminal.App.Fonts.Max_Status_Label_Length) :=
       (others => ' ');
   Last_PTY_Backend_Status_Length : PTY_Backend_Status_Length_Range := 0;
   Last_PTY_Backend_Status :
     String (1 .. Terminal.PTY.POSIX.Max_Status_Label_Length) :=
       (others => ' ');
   Last_ConPTY_Status_Length : PTY_Backend_Status_Length_Range := 0;
   Last_ConPTY_Status :
     String (1 .. Terminal.PTY.POSIX.Max_Status_Label_Length) :=
       (others => ' ');
   Last_Multiplexer_Status_Length : Multiplexer_Status_Length_Range := 0;
   Last_Multiplexer_Status :
     String (1 .. Terminal.App.Max_Status_Label_Length) :=
       (others => ' ');
   Last_Graphics_Header_Status_Length :
     Graphics_Header_Status_Length_Range := 0;
   Last_Graphics_Header_Status :
     String (1 .. Terminal.App.Graphics.Max_Status_Label_Length) :=
       (others => ' ');
   Last_Graphics_Data_Status_Length :
     Graphics_Data_Status_Length_Range := 0;
   Last_Graphics_Data_Status :
     String (1 .. Terminal.App.Graphics.Max_Status_Label_Length) :=
       (others => ' ');
   Last_PTY_Overflows : Natural := 0;
   Last_Input_Overflows : Natural := 0;
   Last_Missing_Glyphs : Natural := 0;
   Last_Shaped_Glyphs : Natural := 0;
   Last_Shaping_Fallbacks : Natural := 0;
   Last_Text_Fallbacks : Natural := 0;
   Last_Color_Emoji_Fallbacks : Natural := 0;
   Last_Paragraph_Bidi_Fallbacks : Natural := 0;
   Last_Image_Count : Natural := 0;
   Last_Image_Protocol : Terminal.App.Render_Model.Image_Protocol :=
     Terminal.App.Render_Model.Image_Sixel;
   Last_Image_Width : Natural := 0;
   Last_Image_Height : Natural := 0;
   Last_Image_Raw_Format : Natural := 0;
   Last_Image_Pixel_Width : Natural := 0;
   Last_Image_Pixel_Height : Natural := 0;
   Last_Image_Payload_Length : Natural := 0;
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
   Last_Image_Placeholder : Boolean := False;
   Last_Render_Status : Terminal.App.Renderer.Render_Status :=
     Terminal.App.Renderer.Not_Initialized;
   Last_Presenter_Status : Terminal.App.Vulkan_Presenter.Present_Status :=
     Terminal.App.Vulkan_Presenter.Not_Initialized;
   Last_Accepted_Frames : Natural := 0;
   Last_Rejected_Frames : Natural := 0;
   Last_Presenter_Image_Count : Natural := 0;
   Last_Presenter_Image_Vertex_Count : Natural := 0;
   Last_Presenter_Image_Texture_Vertex_Count : Natural := 0;
   Last_Presenter_Image_Protocol : Terminal.App.Render_Model.Image_Protocol :=
     Terminal.App.Render_Model.Image_Sixel;
   Last_Presenter_Image_Width : Natural := 0;
   Last_Presenter_Image_Height : Natural := 0;
   Last_Presenter_Image_Raw_Format : Natural := 0;
   Last_Presenter_Image_Pixel_Width : Natural := 0;
   Last_Presenter_Image_Pixel_Height : Natural := 0;
   Last_Presenter_Image_Payload_Length : Natural := 0;
   Last_Presenter_Image_Payload_Preview_Complete : Boolean := False;
   Last_Presenter_Image_Encoded_Preview_Length : Natural := 0;
   Last_Presenter_Image_Decoded_Preview_Length : Natural := 0;
   Last_Presenter_Image_Decoded_Preview_Bytes :
     Terminal.Common.Bytes.Byte_Array
       (1 .. Terminal.App.Render_Model.Max_Image_Decoded_Preview_Length) :=
         (others => 0);
   Last_Presenter_Image_Preview_Decode_Complete : Boolean := False;
   Last_Presenter_Image_Decode_Status :
     Terminal.App.Render_Model.Image_Decode_Status :=
       Terminal.App.Render_Model.Image_Decode_Not_Attempted;
   Last_Presenter_Image_Placeholder : Boolean := False;
   Last_Presenter_Image_Texture_Downgraded : Boolean := False;
   Last_Presenter_Image_Texture_Source :
     Terminal.App.Vulkan_Submit.Texture_Source :=
       Terminal.App.Vulkan_Submit.Texture_None;
   Last_Device_Image_Count : Natural := 0;
   Last_Device_Image_Vertex_Count : Natural := 0;
   Last_Device_Image_Texture_Vertex_Count : Natural := 0;
   Last_Device_Image_Protocol : Terminal.App.Render_Model.Image_Protocol :=
     Terminal.App.Render_Model.Image_Sixel;
   Last_Device_Image_Width : Natural := 0;
   Last_Device_Image_Height : Natural := 0;
   Last_Device_Image_Raw_Format : Natural := 0;
   Last_Device_Image_Pixel_Width : Natural := 0;
   Last_Device_Image_Pixel_Height : Natural := 0;
   Last_Device_Image_Payload_Length : Natural := 0;
   Last_Device_Image_Payload_Preview_Complete : Boolean := False;
   Last_Device_Image_Encoded_Preview_Length : Natural := 0;
   Last_Device_Image_Decoded_Preview_Length : Natural := 0;
   Last_Device_Image_Decoded_Preview_Bytes :
     Terminal.Common.Bytes.Byte_Array
       (1 .. Terminal.App.Render_Model.Max_Image_Decoded_Preview_Length) :=
         (others => 0);
   Last_Device_Image_Preview_Decode_Complete : Boolean := False;
   Last_Device_Image_Decode_Status :
     Terminal.App.Render_Model.Image_Decode_Status :=
       Terminal.App.Render_Model.Image_Decode_Not_Attempted;
   Last_Device_Image_Placeholder : Boolean := False;
   Last_Device_Image_Texture_Downgraded : Boolean := False;
   Last_Device_Image_Texture_Source :
     Terminal.App.Vulkan_Submit.Texture_Source :=
       Terminal.App.Vulkan_Submit.Texture_None;
   Last_Device_Image_Texture_Descriptor_Capacity : Natural := 0;
   Last_Device_Image_Texture_Descriptor_Bound_Count : Natural := 0;
   Last_Atlas_Upload_Count : Natural := 0;

   procedure Put (Message : String) is
   begin
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, "terminal: " & Message);
   end Put;

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
        (Text'Length, Terminal.PTY.POSIX.Max_Status_Label_Length));

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

   function Same_Text
     (Current_Length : Natural;
      Current        : String;
      Last_Length    : Natural;
      Last           : String) return Boolean
   is
   begin
      if Current_Length /= Last_Length then
         return False;
      end if;

      for I in 1 .. Current_Length loop
         if Current (I) /= Last (I) then
            return False;
         end if;
      end loop;

      return True;
   end Same_Text;

   function Same_Grid_Status (S : Snapshot) return Boolean is
   begin
      if S.Grid_Status_Length /= Last_Grid_Status_Length then
         return False;
      end if;

      for I in 1 .. S.Grid_Status_Length loop
         if S.Grid_Status (I) /= Last_Grid_Status (I) then
            return False;
         end if;
      end loop;

      return True;
   end Same_Grid_Status;

   function Same_Policy_Status (S : Snapshot) return Boolean is
   begin
      if S.Policy_Status_Length /= Last_Policy_Status_Length then
         return False;
      end if;

      for I in 1 .. S.Policy_Status_Length loop
         if S.Policy_Status (I) /= Last_Policy_Status (I) then
            return False;
         end if;
      end loop;

      return True;
   end Same_Policy_Status;

   function Same_Scrollback_Status (S : Snapshot) return Boolean is
   begin
      if S.Scrollback_Status_Length /= Last_Scrollback_Status_Length then
         return False;
      end if;

      for I in 1 .. S.Scrollback_Status_Length loop
         if S.Scrollback_Status (I) /= Last_Scrollback_Status (I) then
            return False;
         end if;
      end loop;

      return True;
   end Same_Scrollback_Status;

   function Same_Selection_Status (S : Snapshot) return Boolean is
   begin
      if S.Selection_Status_Length /= Last_Selection_Status_Length then
         return False;
      end if;

      for I in 1 .. S.Selection_Status_Length loop
         if S.Selection_Status (I) /= Last_Selection_Status (I) then
            return False;
         end if;
      end loop;

      return True;
   end Same_Selection_Status;

   function Same_Link_Status (S : Snapshot) return Boolean is
   begin
      if S.Link_Status_Length /= Last_Link_Status_Length then
         return False;
      end if;

      for I in 1 .. S.Link_Status_Length loop
         if S.Link_Status (I) /= Last_Link_Status (I) then
            return False;
         end if;
      end loop;

      return True;
   end Same_Link_Status;

   function Same_Link_Activation_Status (S : Snapshot) return Boolean is
   begin
      if S.Link_Activation_Status_Length /=
        Last_Link_Activation_Status_Length
      then
         return False;
      end if;

      for I in 1 .. S.Link_Activation_Status_Length loop
         if S.Link_Activation_Status (I) /=
           Last_Link_Activation_Status (I)
         then
            return False;
         end if;
      end loop;

      return True;
   end Same_Link_Activation_Status;

   function Same_Clipboard_Status (S : Snapshot) return Boolean is
   begin
      if S.Clipboard_Status_Length /= Last_Clipboard_Status_Length then
         return False;
      end if;

      for I in 1 .. S.Clipboard_Status_Length loop
         if S.Clipboard_Status (I) /= Last_Clipboard_Status (I) then
            return False;
         end if;
      end loop;

      return True;
   end Same_Clipboard_Status;

   function Same_Tab_Status (S : Snapshot) return Boolean is
     (Same_Text
        (S.Tab_Status_Length,
         S.Tab_Status,
         Last_Tab_Status_Length,
         Last_Tab_Status));

   function Same_Split_Status (S : Snapshot) return Boolean is
     (Same_Text
        (S.Split_Status_Length,
         S.Split_Status,
         Last_Split_Status_Length,
         Last_Split_Status));

   function Same_Config_Status (S : Snapshot) return Boolean is
     (Same_Text
        (S.Config_Status_Length,
         S.Config_Status,
         Last_Config_Status_Length,
         Last_Config_Status));

   function Same_Profile_Status (S : Snapshot) return Boolean is
     (Same_Text
        (S.Profile_Status_Length,
         S.Profile_Status,
         Last_Profile_Status_Length,
         Last_Profile_Status));

   function Same_Input_Status (S : Snapshot) return Boolean is
     (Same_Text
        (S.Input_Status_Length,
         S.Input_Status,
         Last_Input_Status_Length,
         Last_Input_Status));

   function Same_Mouse_Status (S : Snapshot) return Boolean is
     (Same_Text
        (S.Mouse_Status_Length,
         S.Mouse_Status,
         Last_Mouse_Status_Length,
         Last_Mouse_Status));

   function Same_Cursor_Status (S : Snapshot) return Boolean is
     (Same_Text
        (S.Cursor_Status_Length,
         S.Cursor_Status,
         Last_Cursor_Status_Length,
         Last_Cursor_Status));

   function Same_Text_Blink_Status (S : Snapshot) return Boolean is
     (Same_Text
        (S.Text_Blink_Status_Length,
         S.Text_Blink_Status,
         Last_Text_Blink_Status_Length,
         Last_Text_Blink_Status));

   function Same_Theme_Status (S : Snapshot) return Boolean is
     (Same_Text
        (S.Theme_Status_Length,
         S.Theme_Status,
         Last_Theme_Status_Length,
         Last_Theme_Status));

   function Same_Font_Status (S : Snapshot) return Boolean is
     (Same_Text
        (S.Font_Status_Length,
         S.Font_Status,
         Last_Font_Status_Length,
         Last_Font_Status));

   function Same_PTY_Backend_Status (S : Snapshot) return Boolean is
     (Same_Text
        (S.PTY_Backend_Status_Length,
         S.PTY_Backend_Status,
         Last_PTY_Backend_Status_Length,
         Last_PTY_Backend_Status));

   function Same_ConPTY_Status (S : Snapshot) return Boolean is
     (Same_Text
        (S.ConPTY_Status_Length,
         S.ConPTY_Status,
         Last_ConPTY_Status_Length,
         Last_ConPTY_Status));

   function Same_Multiplexer_Status (S : Snapshot) return Boolean is
     (Same_Text
        (S.Multiplexer_Status_Length,
         S.Multiplexer_Status,
         Last_Multiplexer_Status_Length,
         Last_Multiplexer_Status));

   function Same_Graphics_Header_Status (S : Snapshot) return Boolean is
     (Same_Text
        (S.Graphics_Header_Status_Length,
         S.Graphics_Header_Status,
         Last_Graphics_Header_Status_Length,
         Last_Graphics_Header_Status));

   function Same_Graphics_Data_Status (S : Snapshot) return Boolean is
     (Same_Text
        (S.Graphics_Data_Status_Length,
         S.Graphics_Data_Status,
         Last_Graphics_Data_Status_Length,
         Last_Graphics_Data_Status));

   function Collect
     (Core     : Terminal.Core.Terminal;
      PTY      : Terminal.App.Queues.PTY_Output_Queue;
      Input    : Terminal.App.Queues.Input_Event_Queue;
      Renderer : Terminal.App.Renderer.Renderer;
      Presenter : Terminal.App.Vulkan_Presenter.Presenter;
      Last_Feed_Status : Terminal.Core.Feed_Status := Terminal.Core.Ok;
      Last_Write_Status : Terminal.App.PTY_Write.Write_All_Status :=
        Terminal.App.PTY_Write.Ok;
      Grid_Status : String := "";
      Policy_Status : String := "";
      Scrollback_Status : String := "";
      Selection_Status : String := "";
      Link_Status : String := "";
      Link_Activation_Status : String := "";
      Clipboard_Status : String := "";
      Tab_Status : String := "";
      Split_Status : String := "";
      Config_Status : String := "";
      Profile_Status : String := "";
      Input_Status : String := "";
      Mouse_Status : String := "";
      Cursor_Status : String := "";
      Text_Blink_Status : String := "";
      Theme_Status : String := "";
      Font_Status : String := "";
      PTY_Backend_Status : String := "";
      ConPTY_Status : String := "";
      Multiplexer_Status : String := "";
      Graphics_Header_Status : String := "";
      Graphics_Data_Status : String := "")
      return Snapshot
   is
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
        String (1 .. Terminal.PTY.POSIX.Max_Status_Label_Length) :=
          (others => ' ');
      ConPTY_Length : constant PTY_Backend_Status_Length_Range :=
        Bounded_PTY_Backend_Length (ConPTY_Status);
      ConPTY_Text :
        String (1 .. Terminal.PTY.POSIX.Max_Status_Label_Length) :=
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
      return S.Last_Feed_Status /= Last_Feed_Status
        or else S.Last_Write_Status /= Last_Write_Status
        or else not Same_Grid_Status (S)
        or else not Same_Policy_Status (S)
        or else not Same_Scrollback_Status (S)
        or else not Same_Selection_Status (S)
        or else not Same_Link_Status (S)
        or else not Same_Link_Activation_Status (S)
        or else not Same_Clipboard_Status (S)
        or else not Same_Tab_Status (S)
        or else not Same_Split_Status (S)
        or else not Same_Config_Status (S)
        or else not Same_Profile_Status (S)
        or else not Same_Input_Status (S)
        or else not Same_Mouse_Status (S)
        or else not Same_Cursor_Status (S)
        or else not Same_Text_Blink_Status (S)
        or else not Same_Theme_Status (S)
        or else not Same_Font_Status (S)
        or else not Same_PTY_Backend_Status (S)
        or else not Same_ConPTY_Status (S)
        or else not Same_Multiplexer_Status (S)
        or else not Same_Graphics_Header_Status (S)
        or else not Same_Graphics_Data_Status (S)
        or else S.Core.Malformed_UTF8 /= Last_Core.Malformed_UTF8
        or else S.Core.Ignored_Escape /= Last_Core.Ignored_Escape
        or else S.Core.Parser_Overflow /= Last_Core.Parser_Overflow
        or else S.Core.Queue_Overflow /= Last_Core.Queue_Overflow
        or else S.Core.Unsupported_Sequence /= Last_Core.Unsupported_Sequence
        or else
          S.Core.Text_Cluster_Overflow /= Last_Core.Text_Cluster_Overflow
        or else
          S.Core.Graphics_Protocol_Ignored /=
            Last_Core.Graphics_Protocol_Ignored
        or else S.Core.Sixel_Ignored /= Last_Core.Sixel_Ignored
        or else
          S.Core.Kitty_Graphics_Ignored /= Last_Core.Kitty_Graphics_Ignored
        or else
          S.Core.ITerm2_Image_Ignored /= Last_Core.ITerm2_Image_Ignored
        or else
          S.Core.Multiplexer_Passthrough /= Last_Core.Multiplexer_Passthrough
        or else
          S.Core.Last_Graphics_Protocol /= Last_Core.Last_Graphics_Protocol
        or else
          S.Core.Last_Graphics_Payload_Length /=
            Last_Core.Last_Graphics_Payload_Length;
   end Core_Changed;

   function Queue_Changed (S : Snapshot) return Boolean is
   begin
      return S.PTY_Overflows /= Last_PTY_Overflows
        or else S.Input_Overflows /= Last_Input_Overflows;
   end Queue_Changed;

   function Renderer_Changed (S : Snapshot) return Boolean is
   begin
      return S.Renderer.Missing_Glyph_Count /= Last_Missing_Glyphs
        or else S.Renderer.Last_Image_Count /= Last_Image_Count
        or else S.Renderer.Last_Image_Protocol /= Last_Image_Protocol
        or else S.Renderer.Last_Image_Width /= Last_Image_Width
        or else S.Renderer.Last_Image_Height /= Last_Image_Height
        or else S.Renderer.Last_Image_Raw_Format /= Last_Image_Raw_Format
        or else S.Renderer.Last_Image_Pixel_Width /= Last_Image_Pixel_Width
        or else S.Renderer.Last_Image_Pixel_Height /= Last_Image_Pixel_Height
        or else
          S.Renderer.Last_Image_Payload_Length /=
            Last_Image_Payload_Length
        or else
          S.Renderer.Last_Image_Payload_Preview_Complete /=
            Last_Image_Payload_Preview_Complete
        or else
          S.Renderer.Last_Image_Encoded_Preview_Length /=
            Last_Image_Encoded_Preview_Length
        or else
          S.Renderer.Last_Image_Decoded_Preview_Length /=
            Last_Image_Decoded_Preview_Length
        or else
          S.Renderer.Last_Image_Decoded_Preview_Bytes /=
            Last_Image_Decoded_Preview_Bytes
        or else
          S.Renderer.Last_Image_Preview_Decode_Complete /=
            Last_Image_Preview_Decode_Complete
        or else
          S.Renderer.Last_Image_Decode_Status /= Last_Image_Decode_Status
        or else
          S.Renderer.Last_Image_Placeholder /= Last_Image_Placeholder
        or else S.Renderer.Last_Shaped_Glyph_Count /= Last_Shaped_Glyphs
        or else
          S.Renderer.Last_Shaping_Fallback_Count /=
            Last_Shaping_Fallbacks
        or else
          S.Renderer.Last_Text_Fallback_Run_Count /=
            Last_Text_Fallbacks
        or else
          S.Renderer.Last_Color_Emoji_Fallback_Count /=
            Last_Color_Emoji_Fallbacks
        or else
          S.Renderer.Last_Paragraph_Bidi_Fallback_Count /=
            Last_Paragraph_Bidi_Fallbacks
        or else S.Renderer.Last_Render_Status /= Last_Render_Status;
   end Renderer_Changed;

   function Presenter_Changed (S : Snapshot) return Boolean is
   begin
      return S.Presenter.Last_Status /= Last_Presenter_Status
        or else S.Presenter.Accepted_Frames /= Last_Accepted_Frames
        or else S.Presenter.Rejected_Frames /= Last_Rejected_Frames
        or else
          S.Presenter.Last_Image_Command_Count /= Last_Presenter_Image_Count
        or else
          S.Presenter.Last_Image_Vertex_Count /=
            Last_Presenter_Image_Vertex_Count
        or else
          S.Presenter.Last_Image_Texture_Vertex_Count /=
            Last_Presenter_Image_Texture_Vertex_Count
        or else
          S.Presenter.Last_Image_Protocol /= Last_Presenter_Image_Protocol
        or else
          S.Presenter.Last_Image_Width /= Last_Presenter_Image_Width
        or else
          S.Presenter.Last_Image_Height /= Last_Presenter_Image_Height
        or else
          S.Presenter.Last_Image_Raw_Format /=
            Last_Presenter_Image_Raw_Format
        or else
          S.Presenter.Last_Image_Pixel_Width /=
            Last_Presenter_Image_Pixel_Width
        or else
          S.Presenter.Last_Image_Pixel_Height /=
            Last_Presenter_Image_Pixel_Height
        or else
          S.Presenter.Last_Image_Payload_Length /=
            Last_Presenter_Image_Payload_Length
        or else
          S.Presenter.Last_Image_Payload_Preview_Complete /=
            Last_Presenter_Image_Payload_Preview_Complete
        or else
          S.Presenter.Last_Image_Encoded_Preview_Length /=
            Last_Presenter_Image_Encoded_Preview_Length
        or else
          S.Presenter.Last_Image_Decoded_Preview_Length /=
            Last_Presenter_Image_Decoded_Preview_Length
        or else
          S.Presenter.Last_Image_Decoded_Preview_Bytes /=
            Last_Presenter_Image_Decoded_Preview_Bytes
        or else
          S.Presenter.Last_Image_Preview_Decode_Complete /=
            Last_Presenter_Image_Preview_Decode_Complete
        or else
          S.Presenter.Last_Image_Decode_Status /=
            Last_Presenter_Image_Decode_Status
        or else
          S.Presenter.Last_Image_Placeholder /=
            Last_Presenter_Image_Placeholder
        or else
          S.Presenter.Last_Image_Texture_Downgraded /=
            Last_Presenter_Image_Texture_Downgraded
        or else
          S.Presenter.Last_Image_Texture_Source /=
            Last_Presenter_Image_Texture_Source
        or else
          S.Presenter.Logical_Device.Uploaded_Image_Command_Count /=
            Last_Device_Image_Count
        or else
          S.Presenter.Logical_Device.Uploaded_Image_Vertex_Count /=
            Last_Device_Image_Vertex_Count
        or else
          S.Presenter.Logical_Device.Uploaded_Image_Texture_Vertex_Count /=
            Last_Device_Image_Texture_Vertex_Count
        or else
          S.Presenter.Logical_Device.Uploaded_Image_Protocol /=
            Last_Device_Image_Protocol
        or else
          S.Presenter.Logical_Device.Uploaded_Image_Width /=
            Last_Device_Image_Width
        or else
          S.Presenter.Logical_Device.Uploaded_Image_Height /=
            Last_Device_Image_Height
        or else
          S.Presenter.Logical_Device.Uploaded_Image_Raw_Format /=
            Last_Device_Image_Raw_Format
        or else
          S.Presenter.Logical_Device.Uploaded_Image_Pixel_Width /=
            Last_Device_Image_Pixel_Width
        or else
          S.Presenter.Logical_Device.Uploaded_Image_Pixel_Height /=
            Last_Device_Image_Pixel_Height
        or else
          S.Presenter.Logical_Device.Uploaded_Image_Payload_Length /=
            Last_Device_Image_Payload_Length
        or else
          S.Presenter.Logical_Device.Uploaded_Image_Payload_Preview_Complete /=
            Last_Device_Image_Payload_Preview_Complete
        or else
          S.Presenter.Logical_Device.Uploaded_Image_Encoded_Preview_Length /=
            Last_Device_Image_Encoded_Preview_Length
        or else
          S.Presenter.Logical_Device.Uploaded_Image_Decoded_Preview_Length /=
            Last_Device_Image_Decoded_Preview_Length
        or else
          S.Presenter.Logical_Device.Uploaded_Image_Decoded_Preview_Bytes /=
            Last_Device_Image_Decoded_Preview_Bytes
        or else
          S.Presenter.Logical_Device.Uploaded_Image_Preview_Decode_Complete /=
            Last_Device_Image_Preview_Decode_Complete
        or else
          S.Presenter.Logical_Device.Uploaded_Image_Decode_Status /=
            Last_Device_Image_Decode_Status
        or else
          S.Presenter.Logical_Device.Uploaded_Image_Placeholder /=
            Last_Device_Image_Placeholder
        or else
          S.Presenter.Logical_Device.Uploaded_Image_Texture_Downgraded /=
            Last_Device_Image_Texture_Downgraded
        or else
          S.Presenter.Logical_Device.Uploaded_Image_Texture_Source /=
            Last_Device_Image_Texture_Source
        or else
          S.Presenter.Logical_Device.Image_Texture_Descriptor_Capacity /=
            Last_Device_Image_Texture_Descriptor_Capacity
        or else
          S.Presenter.Logical_Device.Image_Texture_Descriptor_Bound_Count /=
            Last_Device_Image_Texture_Descriptor_Bound_Count
        or else
          S.Presenter.Logical_Device.Atlas_Upload_Count /=
            Last_Atlas_Upload_Count;
   end Presenter_Changed;

   procedure Remember (S : Snapshot) is
   begin
      Last_Initialized := True;
      Last_Core := S.Core;
      Last_Feed_Status := S.Last_Feed_Status;
      Last_Write_Status := S.Last_Write_Status;
      Last_Grid_Status_Length := S.Grid_Status_Length;
      Last_Grid_Status := S.Grid_Status;
      Last_Policy_Status_Length := S.Policy_Status_Length;
      Last_Policy_Status := S.Policy_Status;
      Last_Scrollback_Status_Length := S.Scrollback_Status_Length;
      Last_Scrollback_Status := S.Scrollback_Status;
      Last_Selection_Status_Length := S.Selection_Status_Length;
      Last_Selection_Status := S.Selection_Status;
      Last_Link_Status_Length := S.Link_Status_Length;
      Last_Link_Status := S.Link_Status;
      Last_Link_Activation_Status_Length := S.Link_Activation_Status_Length;
      Last_Link_Activation_Status := S.Link_Activation_Status;
      Last_Clipboard_Status_Length := S.Clipboard_Status_Length;
      Last_Clipboard_Status := S.Clipboard_Status;
      Last_Tab_Status_Length := S.Tab_Status_Length;
      Last_Tab_Status := S.Tab_Status;
      Last_Split_Status_Length := S.Split_Status_Length;
      Last_Split_Status := S.Split_Status;
      Last_Config_Status_Length := S.Config_Status_Length;
      Last_Config_Status := S.Config_Status;
      Last_Profile_Status_Length := S.Profile_Status_Length;
      Last_Profile_Status := S.Profile_Status;
      Last_Input_Status_Length := S.Input_Status_Length;
      Last_Input_Status := S.Input_Status;
      Last_Mouse_Status_Length := S.Mouse_Status_Length;
      Last_Mouse_Status := S.Mouse_Status;
      Last_Cursor_Status_Length := S.Cursor_Status_Length;
      Last_Cursor_Status := S.Cursor_Status;
      Last_Text_Blink_Status_Length := S.Text_Blink_Status_Length;
      Last_Text_Blink_Status := S.Text_Blink_Status;
      Last_Theme_Status_Length := S.Theme_Status_Length;
      Last_Theme_Status := S.Theme_Status;
      Last_Font_Status_Length := S.Font_Status_Length;
      Last_Font_Status := S.Font_Status;
      Last_PTY_Backend_Status_Length := S.PTY_Backend_Status_Length;
      Last_PTY_Backend_Status := S.PTY_Backend_Status;
      Last_ConPTY_Status_Length := S.ConPTY_Status_Length;
      Last_ConPTY_Status := S.ConPTY_Status;
      Last_Multiplexer_Status_Length := S.Multiplexer_Status_Length;
      Last_Multiplexer_Status := S.Multiplexer_Status;
      Last_Graphics_Header_Status_Length := S.Graphics_Header_Status_Length;
      Last_Graphics_Header_Status := S.Graphics_Header_Status;
      Last_Graphics_Data_Status_Length := S.Graphics_Data_Status_Length;
      Last_Graphics_Data_Status := S.Graphics_Data_Status;
      Last_PTY_Overflows := S.PTY_Overflows;
      Last_Input_Overflows := S.Input_Overflows;
      Last_Missing_Glyphs := S.Renderer.Missing_Glyph_Count;
      Last_Shaped_Glyphs := S.Renderer.Last_Shaped_Glyph_Count;
      Last_Shaping_Fallbacks := S.Renderer.Last_Shaping_Fallback_Count;
      Last_Text_Fallbacks := S.Renderer.Last_Text_Fallback_Run_Count;
      Last_Color_Emoji_Fallbacks :=
        S.Renderer.Last_Color_Emoji_Fallback_Count;
      Last_Paragraph_Bidi_Fallbacks :=
        S.Renderer.Last_Paragraph_Bidi_Fallback_Count;
      Last_Image_Count := S.Renderer.Last_Image_Count;
      Last_Image_Protocol := S.Renderer.Last_Image_Protocol;
      Last_Image_Width := S.Renderer.Last_Image_Width;
      Last_Image_Height := S.Renderer.Last_Image_Height;
      Last_Image_Raw_Format := S.Renderer.Last_Image_Raw_Format;
      Last_Image_Pixel_Width := S.Renderer.Last_Image_Pixel_Width;
      Last_Image_Pixel_Height := S.Renderer.Last_Image_Pixel_Height;
      Last_Image_Payload_Length := S.Renderer.Last_Image_Payload_Length;
      Last_Image_Payload_Preview_Complete :=
        S.Renderer.Last_Image_Payload_Preview_Complete;
      Last_Image_Encoded_Preview_Length :=
        S.Renderer.Last_Image_Encoded_Preview_Length;
      Last_Image_Decoded_Preview_Length :=
        S.Renderer.Last_Image_Decoded_Preview_Length;
      Last_Image_Decoded_Preview_Bytes :=
        S.Renderer.Last_Image_Decoded_Preview_Bytes;
      Last_Image_Preview_Decode_Complete :=
        S.Renderer.Last_Image_Preview_Decode_Complete;
      Last_Image_Decode_Status := S.Renderer.Last_Image_Decode_Status;
      Last_Image_Placeholder := S.Renderer.Last_Image_Placeholder;
      Last_Render_Status := S.Renderer.Last_Render_Status;
      Last_Presenter_Status := S.Presenter.Last_Status;
      Last_Accepted_Frames := S.Presenter.Accepted_Frames;
      Last_Rejected_Frames := S.Presenter.Rejected_Frames;
      Last_Presenter_Image_Count := S.Presenter.Last_Image_Command_Count;
      Last_Presenter_Image_Vertex_Count := S.Presenter.Last_Image_Vertex_Count;
      Last_Presenter_Image_Texture_Vertex_Count :=
        S.Presenter.Last_Image_Texture_Vertex_Count;
      Last_Presenter_Image_Protocol := S.Presenter.Last_Image_Protocol;
      Last_Presenter_Image_Width := S.Presenter.Last_Image_Width;
      Last_Presenter_Image_Height := S.Presenter.Last_Image_Height;
      Last_Presenter_Image_Raw_Format := S.Presenter.Last_Image_Raw_Format;
      Last_Presenter_Image_Pixel_Width := S.Presenter.Last_Image_Pixel_Width;
      Last_Presenter_Image_Pixel_Height := S.Presenter.Last_Image_Pixel_Height;
      Last_Presenter_Image_Payload_Length :=
        S.Presenter.Last_Image_Payload_Length;
      Last_Presenter_Image_Payload_Preview_Complete :=
        S.Presenter.Last_Image_Payload_Preview_Complete;
      Last_Presenter_Image_Encoded_Preview_Length :=
        S.Presenter.Last_Image_Encoded_Preview_Length;
      Last_Presenter_Image_Decoded_Preview_Length :=
        S.Presenter.Last_Image_Decoded_Preview_Length;
      Last_Presenter_Image_Decoded_Preview_Bytes :=
        S.Presenter.Last_Image_Decoded_Preview_Bytes;
      Last_Presenter_Image_Preview_Decode_Complete :=
        S.Presenter.Last_Image_Preview_Decode_Complete;
      Last_Presenter_Image_Decode_Status :=
        S.Presenter.Last_Image_Decode_Status;
      Last_Presenter_Image_Placeholder := S.Presenter.Last_Image_Placeholder;
      Last_Presenter_Image_Texture_Downgraded :=
        S.Presenter.Last_Image_Texture_Downgraded;
      Last_Presenter_Image_Texture_Source :=
        S.Presenter.Last_Image_Texture_Source;
      Last_Device_Image_Count :=
        S.Presenter.Logical_Device.Uploaded_Image_Command_Count;
      Last_Device_Image_Vertex_Count :=
        S.Presenter.Logical_Device.Uploaded_Image_Vertex_Count;
      Last_Device_Image_Texture_Vertex_Count :=
        S.Presenter.Logical_Device.Uploaded_Image_Texture_Vertex_Count;
      Last_Device_Image_Protocol :=
        S.Presenter.Logical_Device.Uploaded_Image_Protocol;
      Last_Device_Image_Width :=
        S.Presenter.Logical_Device.Uploaded_Image_Width;
      Last_Device_Image_Height :=
        S.Presenter.Logical_Device.Uploaded_Image_Height;
      Last_Device_Image_Raw_Format :=
        S.Presenter.Logical_Device.Uploaded_Image_Raw_Format;
      Last_Device_Image_Pixel_Width :=
        S.Presenter.Logical_Device.Uploaded_Image_Pixel_Width;
      Last_Device_Image_Pixel_Height :=
        S.Presenter.Logical_Device.Uploaded_Image_Pixel_Height;
      Last_Device_Image_Payload_Length :=
        S.Presenter.Logical_Device.Uploaded_Image_Payload_Length;
      Last_Device_Image_Payload_Preview_Complete :=
        S.Presenter.Logical_Device.Uploaded_Image_Payload_Preview_Complete;
      Last_Device_Image_Encoded_Preview_Length :=
        S.Presenter.Logical_Device.Uploaded_Image_Encoded_Preview_Length;
      Last_Device_Image_Decoded_Preview_Length :=
        S.Presenter.Logical_Device.Uploaded_Image_Decoded_Preview_Length;
      Last_Device_Image_Decoded_Preview_Bytes :=
        S.Presenter.Logical_Device.Uploaded_Image_Decoded_Preview_Bytes;
      Last_Device_Image_Preview_Decode_Complete :=
        S.Presenter.Logical_Device.Uploaded_Image_Preview_Decode_Complete;
      Last_Device_Image_Decode_Status :=
        S.Presenter.Logical_Device.Uploaded_Image_Decode_Status;
      Last_Device_Image_Placeholder :=
        S.Presenter.Logical_Device.Uploaded_Image_Placeholder;
      Last_Device_Image_Texture_Downgraded :=
        S.Presenter.Logical_Device.Uploaded_Image_Texture_Downgraded;
      Last_Device_Image_Texture_Source :=
        S.Presenter.Logical_Device.Uploaded_Image_Texture_Source;
      Last_Device_Image_Texture_Descriptor_Capacity :=
        S.Presenter.Logical_Device.Image_Texture_Descriptor_Capacity;
      Last_Device_Image_Texture_Descriptor_Bound_Count :=
        S.Presenter.Logical_Device.Image_Texture_Descriptor_Bound_Count;
      Last_Atlas_Upload_Count :=
        S.Presenter.Logical_Device.Atlas_Upload_Count;
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
         & " missing_glyphs=" &
           Natural'Image (S.Renderer.Missing_Glyph_Count)
         & " shaped_glyphs=" &
           Natural'Image (S.Renderer.Last_Shaped_Glyph_Count)
         & " shaping_fallbacks=" &
           Natural'Image (S.Renderer.Last_Shaping_Fallback_Count)
         & " text_fallback_runs=" &
           Natural'Image (S.Renderer.Last_Text_Fallback_Run_Count)
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
