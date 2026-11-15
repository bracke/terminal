with Terminal.App.Frame_Image_Storage;
with Terminal.App.Image_Rendering;
with Terminal.App.Image_Store;
with Terminal.App.Render_Model;
with Terminal.App.Renderer.Frame_Commands;
with Terminal.App.Renderer.Placement_State;
with Terminal.Common.Bytes;
with Terminal.Common.Status;

package body Terminal.App.Renderer.Diagnostics_State is
   package RM renames Terminal.App.Render_Model;
   package FIS renames Terminal.App.Frame_Image_Storage;
   package Commands renames Terminal.App.Renderer.Frame_Commands;
   package Placements renames Terminal.App.Renderer.Placement_State;
   use type RM.Rectangle_Array_Access;

   procedure Clear_Last_Media (R : in out Renderer) is
   begin
      Terminal.App.Image_Rendering.Clear
        (R.Graphics_State.Telemetry.Last_Media);
   end Clear_Last_Media;

   function Image_Preview
     (Image : RM.Image_Command) return Terminal.Common.Bytes.Byte_Array
   is
      Result : Terminal.Common.Bytes.Byte_Array
        (1 .. RM.Max_Image_Decoded_Preview_Length) := (others => 0);
   begin
      for I in 1 .. Natural'Min
        (Image.Decoded_Preview_Length, RM.Max_Image_Decoded_Preview_Length)
      loop
         Result (I) := RM.Image_Decoded_Preview_Byte (Image, I);
      end loop;
      return Result;
   end Image_Preview;

   function Capture
     (R : Renderer; Include_Image_Preview : Boolean)
      return Renderer_Diagnostics
   is
      Image_Count : constant Natural := Commands.Count (R);
      Has_Image : constant Boolean := Image_Count > 0;
      Last_Image : constant RM.Image_Command :=
        (if Has_Image
         then FIS.Element (R.Frame_State.Frame_Images, Positive (Image_Count))
         else (others => <>));
      Stored_Count : constant Natural := Terminal.App.Image_Store.Object_Count
        (R.Graphics_State.Resources.Image_Objects);
      Stored_Bytes : constant Natural := Terminal.App.Image_Store.Byte_Count
        (R.Graphics_State.Resources.Image_Objects);
      Placement_Count : constant Natural := Placements.Stored_Placement_Count (R);
   begin
      return
        (Initialized => R.Lifecycle.Initialized,
         Text_Loaded => R.Text_State.Text_Loaded,
         Last_Cell_Count => R.Frame_State.Last_Cell_Count,
         Last_Dirty_Rows => R.Frame_State.Last_Dirty_Rows,
         Last_Cached_Rows => R.Frame_State.Last_Cached_Rows,
         Last_Rectangle_Count => R.Frame_State.Rectangle_Count,
         Last_Glyph_Count => R.Frame_State.Glyph_Count,
         Last_Image_Count => Image_Count,
         Rectangle_Command_Capacity =>
           (if R.Frame_State.Rectangles = null then 0
            else R.Frame_State.Rectangles'Length),
         Image_Command_Capacity => Commands.Capacity (R),
         Last_Image_Protocol =>
           (if Has_Image then Last_Image.Protocol else RM.Image_Sixel),
         Last_Image_Width => (if Has_Image then Natural (Last_Image.Width) else 0),
         Last_Image_Height => (if Has_Image then Natural (Last_Image.Height) else 0),
         Last_Image_Raw_Format => (if Has_Image then Last_Image.Raw_Format else 0),
         Last_Image_Pixel_Width => (if Has_Image then Last_Image.Pixel_Width else 0),
         Last_Image_Pixel_Height => (if Has_Image then Last_Image.Pixel_Height else 0),
         Last_Image_Payload_Length => (if Has_Image then Last_Image.Payload_Length else 0),
         Last_Image_Staging_Byte_Length =>
           (if Has_Image then Last_Image.Staging_Byte_Length else 0),
         Last_Image_Payload_Preview_Complete =>
           Has_Image and then Last_Image.Payload_Preview_Complete,
         Last_Image_Encoded_Preview_Length =>
           (if Has_Image then Last_Image.Encoded_Preview_Length else 0),
         Last_Image_Decoded_Preview_Length =>
           (if Has_Image and then Include_Image_Preview
            then Last_Image.Decoded_Preview_Length else 0),
         Last_Image_Decoded_Preview_Bytes =>
           (if Has_Image and then Include_Image_Preview
            then Image_Preview (Last_Image) else (others => 0)),
         Last_Image_Preview_Decode_Complete =>
           Has_Image and then Last_Image.Preview_Decode_Complete,
         Last_Image_Decode_Status =>
           (if Has_Image then Last_Image.Decode_Status
            else RM.Image_Decode_Not_Attempted),
         Last_Media_Decode_Attempted => R.Graphics_State.Telemetry.Last_Media.Attempted,
         Last_Media_Decode_Status => R.Graphics_State.Telemetry.Last_Media.Status,
         Last_Media_Diagnostic => R.Graphics_State.Telemetry.Last_Media.Error,
         Last_Media_Adapter_Buffer_Bytes => R.Graphics_State.Telemetry.Last_Media.Adapter_Buffer_Bytes,
         Last_Media_Decoder_Configured_Bytes => R.Graphics_State.Telemetry.Last_Media.Decoder_Configured_Bytes,
         Last_Media_Warning_Count => R.Graphics_State.Telemetry.Last_Media.Warning_Count,
         Last_Media_First_Warning => R.Graphics_State.Telemetry.Last_Media.First_Warning,
         Last_Image_Placeholder => Has_Image and then Last_Image.Placeholder,
         Image_Object_Count => Stored_Count,
         Image_Object_Bytes => Stored_Bytes,
         Placement_Count => Placement_Count,
         Kitty_Image_Object_Count => Stored_Count,
         Kitty_Image_Object_Bytes => Stored_Bytes,
         Kitty_Placement_Count => Placement_Count,
         Kitty_Animation_Frame_Count => Terminal.App.Image_Store.Animation_Frame_Count
           (R.Graphics_State.Resources.Image_Objects),
         Graphics_Event_Count => R.Graphics_State.Telemetry.Graphics_Event_Count,
         Kitty_Command_Count => R.Graphics_State.Telemetry.Kitty_Command_Count,
         Kitty_Success_Count => R.Graphics_State.Telemetry.Kitty_Success_Count,
         Kitty_Error_Count => R.Graphics_State.Telemetry.Kitty_Error_Count,
         Image_Install_Count => R.Graphics_State.Telemetry.Image_Install_Count,
         Image_Installed_Bytes => R.Graphics_State.Telemetry.Image_Installed_Bytes,
         Image_Eviction_Count => R.Graphics_State.Telemetry.Image_Eviction_Count,
         Placement_Create_Count => R.Graphics_State.Telemetry.Placement_Create_Count,
         Placement_Delete_Count => R.Graphics_State.Telemetry.Placement_Delete_Count,
         Transport_Failure_Count => R.Graphics_State.Telemetry.Transport_Failure_Count,
         Decode_Failure_Count => R.Graphics_State.Telemetry.Decode_Failure_Count,
         Allocation_Failure_Count => R.Graphics_State.Telemetry.Allocation_Failure_Count,
         Animation_Advance_Count => R.Graphics_State.Telemetry.Animation_Advance_Count,
         Chunk_Cancel_Count => R.Graphics_State.Telemetry.Chunk_Cancel_Count,
         Last_Text_Run_Count => R.Frame_State.Text_Run_Count,
         Last_Shaped_Glyph_Count => R.Text_State.Shaped_Glyph_Count,
         Last_Shaping_Fallback_Count => R.Text_State.Shaping_Fallback_Count,
         Last_Text_Fallback_Run_Count => R.Text_State.Text_Fallback_Run_Count,
         Last_Color_Glyph_Count => R.Text_State.Color_Glyph_Count,
         Last_Color_Emoji_Fallback_Count => R.Text_State.Color_Emoji_Fallback_Count,
         Last_Paragraph_Bidi_Fallback_Count => R.Text_State.Paragraph_Bidi_Fallback_Count,
         Last_Vertex_Count => R.Frame_State.Vertex_Count,
         Missing_Glyph_Count => R.Text_State.Missing_Glyph_Count,
         Atlas_Dirty => R.Text_State.Atlas_Dirty,
         Last_Render_Status => R.Lifecycle.Last_Render_Status);
   end Capture;

   function Equivalent (Left, Right : Renderer_Diagnostics) return Boolean is
      use type Renderer_Operational_Diagnostics;
   begin
      return Renderer_Operational_Diagnostics (Left) =
        Renderer_Operational_Diagnostics (Right);
   end Equivalent;

   function Color_Emoji_Label
     (Diagnostics : Renderer_Diagnostics) return String is
   begin
      if Diagnostics.Last_Color_Glyph_Count > 0
        and then Diagnostics.Last_Color_Emoji_Fallback_Count = 0
      then
         return "Color emoji glyphs rendered";
      elsif Diagnostics.Last_Color_Glyph_Count > 0 then
         return "Color emoji glyphs rendered with fallback";
      elsif Diagnostics.Last_Color_Emoji_Fallback_Count = 0 then
         return "";
      else
         return "Color emoji rendered with monochrome fallback";
      end if;
   end Color_Emoji_Label;

   function Paragraph_Bidi_Label
     (Diagnostics : Renderer_Diagnostics) return String is
     (if Diagnostics.Last_Paragraph_Bidi_Fallback_Count = 0
      then ""
      else "Paragraph BiDi reordering not applied");

   function Image_Label
     (Diagnostics : Renderer_Diagnostics) return String
   is
      function Trimmed (Value : Natural) return String
        renames Terminal.Common.Status.Trimmed_Natural;

      function Protocol_Name return String is
      begin
         case Diagnostics.Last_Image_Protocol is
            when RM.Image_Sixel => return "sixel";
            when RM.Image_Kitty => return "kitty";
            when RM.Image_ITerm2 => return "iTerm2";
         end case;
      end Protocol_Name;

      function Bounded (Text : String) return String is
        (if Text'Length <= Max_Status_Label_Length
         then Text
         else Text (Text'First .. Text'First + Max_Status_Label_Length - 1));
   begin
      if Diagnostics.Last_Image_Count = 0 then
         return "";
      end if;

      return Bounded
        ("image " & Protocol_Name
         & " size=" & Trimmed (Diagnostics.Last_Image_Width)
         & "x" & Trimmed (Diagnostics.Last_Image_Height)
         & (if Diagnostics.Last_Image_Pixel_Width > 0
            and then Diagnostics.Last_Image_Pixel_Height > 0
            then " pixels=" & Trimmed (Diagnostics.Last_Image_Pixel_Width)
              & "x" & Trimmed (Diagnostics.Last_Image_Pixel_Height)
              & " format=" & Trimmed (Diagnostics.Last_Image_Raw_Format)
            else "")
         & " payload=" & Trimmed (Diagnostics.Last_Image_Payload_Length)
         & RM.Image_Payload_Status_Suffix
             (Diagnostics.Last_Image_Payload_Preview_Complete)
         & " preview="
         & Trimmed (Diagnostics.Last_Image_Decoded_Preview_Length)
         & "/" & Trimmed (Diagnostics.Last_Image_Encoded_Preview_Length)
         & Terminal.Common.Status.Preview_Bytes_Label
             (Diagnostics.Last_Image_Decoded_Preview_Bytes,
              Diagnostics.Last_Image_Decoded_Preview_Length)
         & (if Diagnostics.Last_Image_Placeholder
            then " placeholder" else " textured")
         & (if Diagnostics.Last_Image_Preview_Decode_Complete
            then " decoded" else " partial")
         & RM.Image_Decode_Status_Suffix
             (Diagnostics.Last_Image_Decode_Status));
   end Image_Label;

   function Media_Label
     (Diagnostics : Renderer_Diagnostics) return String
   is
      Media : constant Terminal.App.Image_Rendering.Media_Diagnostics :=
        (Attempted => Diagnostics.Last_Media_Decode_Attempted,
         Status => Diagnostics.Last_Media_Decode_Status,
         Error => Diagnostics.Last_Media_Diagnostic,
         Adapter_Buffer_Bytes =>
           Diagnostics.Last_Media_Adapter_Buffer_Bytes,
         Decoder_Configured_Bytes =>
           Diagnostics.Last_Media_Decoder_Configured_Bytes,
         Warning_Count => Diagnostics.Last_Media_Warning_Count,
         First_Warning => Diagnostics.Last_Media_First_Warning);
   begin
      return Terminal.App.Image_Rendering.Status_Label (Media);
   end Media_Label;
end Terminal.App.Renderer.Diagnostics_State;
