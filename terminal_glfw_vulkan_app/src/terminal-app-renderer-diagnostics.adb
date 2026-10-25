separate (Terminal.App.Renderer)
function Diagnostics (R : Renderer) return Renderer_Diagnostics is
   Image_Count : constant Natural := Frame_Image_Count (R);
   Has_Image : constant Boolean := Image_Count > 0;
   Last_Image : constant RM.Image_Command :=
     (if Has_Image
      then FIS.Element (R.Frame_Images, Positive (Image_Count))
      else (others => <>));
begin
   return
     (Initialized          => R.Initialized,
      Text_Loaded          => R.Text_Loaded,
      Last_Cell_Count      => R.Last_Cell_Count,
      Last_Dirty_Rows      => R.Last_Dirty_Rows,
      Last_Rectangle_Count => R.Rectangle_Count,
      Last_Glyph_Count     => R.Glyph_Count,
      Last_Image_Count     => Image_Count,
      Rectangle_Command_Capacity =>
        (if R.Rectangles = null then 0 else R.Rectangles'Length),
      Image_Command_Capacity =>
        Frame_Image_Capacity (R),
      Last_Image_Protocol  =>
        (if Has_Image then Last_Image.Protocol
         else Terminal.App.Render_Model.Image_Sixel),
      Last_Image_Width =>
        (if Has_Image then Natural (Last_Image.Width) else 0),
      Last_Image_Height =>
        (if Has_Image then Natural (Last_Image.Height) else 0),
      Last_Image_Raw_Format =>
        (if Has_Image then Last_Image.Raw_Format else 0),
      Last_Image_Pixel_Width =>
        (if Has_Image then Last_Image.Pixel_Width else 0),
      Last_Image_Pixel_Height =>
        (if Has_Image then Last_Image.Pixel_Height else 0),
      Last_Image_Payload_Length =>
        (if Has_Image then Last_Image.Payload_Length else 0),
      Last_Image_Staging_Byte_Length =>
        (if Has_Image then Last_Image.Staging_Byte_Length
         else 0),
      Last_Image_Payload_Preview_Complete =>
        Has_Image
        and then Last_Image.Payload_Preview_Complete,
      Last_Image_Encoded_Preview_Length =>
        (if Has_Image then Last_Image.Encoded_Preview_Length
         else 0),
      Last_Image_Decoded_Preview_Length =>
        (if Has_Image then Last_Image.Decoded_Preview_Length
         else 0),
      Last_Image_Decoded_Preview_Bytes =>
        (if Has_Image then Image_Preview (Last_Image)
         else (others => 0)),
      Last_Image_Preview_Decode_Complete =>
        Has_Image and then Last_Image.Preview_Decode_Complete,
      Last_Image_Decode_Status =>
        (if Has_Image then Last_Image.Decode_Status
         else RM.Image_Decode_Not_Attempted),
      Last_Media_Decode_Attempted => R.Last_Media.Attempted,
      Last_Media_Decode_Status => R.Last_Media.Status,
      Last_Media_Diagnostic => R.Last_Media.Error,
      Last_Media_Adapter_Buffer_Bytes =>
        R.Last_Media.Adapter_Buffer_Bytes,
      Last_Media_Decoder_Configured_Bytes =>
        R.Last_Media.Decoder_Configured_Bytes,
      Last_Media_Warning_Count => R.Last_Media.Warning_Count,
      Last_Media_First_Warning => R.Last_Media.First_Warning,
      Last_Image_Placeholder =>
        Has_Image and then Last_Image.Placeholder,
      Image_Object_Count => Stored_Image_Count (R),
      Image_Object_Bytes => Stored_Image_Bytes (R),
      Placement_Count => R.Kitty_Placement_Count,
      Kitty_Image_Object_Count => Stored_Image_Count (R),
      Kitty_Image_Object_Bytes => Stored_Image_Bytes (R),
      Kitty_Placement_Count => R.Kitty_Placement_Count,
      Kitty_Animation_Frame_Count => Stored_Animation_Frame_Count (R),
      Graphics_Event_Count => R.Graphics_Event_Count,
      Kitty_Command_Count => R.Kitty_Command_Count,
      Kitty_Success_Count => R.Kitty_Success_Count,
      Kitty_Error_Count => R.Kitty_Error_Count,
      Image_Install_Count => R.Image_Install_Count,
      Image_Installed_Bytes => R.Image_Installed_Bytes,
      Image_Eviction_Count => R.Image_Eviction_Count,
      Placement_Create_Count => R.Placement_Create_Count,
      Placement_Delete_Count => R.Placement_Delete_Count,
      Transport_Failure_Count => R.Transport_Failure_Count,
      Decode_Failure_Count => R.Decode_Failure_Count,
      Allocation_Failure_Count => R.Allocation_Failure_Count,
      Animation_Advance_Count => R.Animation_Advance_Count,
      Chunk_Cancel_Count => R.Chunk_Cancel_Count,
      Last_Text_Run_Count  => R.Text_Run_Count,
      Last_Shaped_Glyph_Count => R.Shaped_Glyph_Count,
      Last_Shaping_Fallback_Count => R.Shaping_Fallback_Count,
      Last_Text_Fallback_Run_Count => R.Text_Fallback_Run_Count,
      Last_Color_Glyph_Count => R.Color_Glyph_Count,
      Last_Color_Emoji_Fallback_Count => R.Color_Emoji_Fallback_Count,
      Last_Paragraph_Bidi_Fallback_Count =>
        R.Paragraph_Bidi_Fallback_Count,
      Last_Vertex_Count    => R.Vertex_Count,
      Missing_Glyph_Count  => R.Missing_Glyph_Count,
      Atlas_Dirty          => R.Atlas_Dirty,
      Last_Render_Status   => R.Last_Render_Status);
end Diagnostics;
