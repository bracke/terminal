separate (Terminal.App.Renderer.Add_Image_Event)
function Emit_Image_Object
  (Item   : Terminal.Core.Graphics_Event;
   Header : Terminal.App.Graphics.Graphics_Header) return Boolean
is
   Object : constant Image_Object_Access :=
     Find_Image_Object (R, Item.Stream_ID, Header.Kitty_ID);
   X : constant Float :=
     Float (Origin_X (R) + (Item.Col - 1) * R.CW);
   Y : constant Float :=
     Float (Origin_Y (R) + (Item.Row - 1) * R.CH);
   Preview_Length : Natural := 0;
   Preview_Bytes : Terminal.Common.Bytes.Byte_Array
     (1 .. RM.Max_Image_Decoded_Preview_Length) := (others => 0);
   Frame_Bytes : constant RM.Image_Data_View :=
     Display_Frame_Bytes (Object);
   Frame_Format : constant Natural := Display_Frame_Format (Object);
   Frame_Length : constant Natural := Display_Frame_Length (Object);
   Frame_Stride : constant Natural := Display_Frame_Stride (Object);
begin
   if Object = null
     or else Frame_Bytes = null
     or else FIS.Is_Full (R.Frame_Images)
   then
      return False;
   end if;

   Copy_Image_Preview
     (Frame_Bytes, Frame_Length, Preview_Length, Preview_Bytes);

   Append_Image_Command
     (R,
     (X              => X,
      Y              => Y,
      Width          =>
        Float (R.CW * Header.Placeholder_Cols),
      Height         =>
        Float (R.CH * Header.Placeholder_Rows),
      Protocol       => Object.Protocol,
      Placeholder    => False,
      Raw_Format     => Frame_Format,
      Pixel_Width    => Object.Pixel_Width,
      Pixel_Height   => Object.Pixel_Height,
      Payload_Length => Item.Payload_Length,
      Staging_Byte_Length => 0,
      Payload_Preview_Complete => True,
      Encoded_Preview_Length => 0,
      Decoded_Byte_Length => Frame_Length,
      Decoded_Row_Stride_Bytes => Frame_Stride,
      Decoded_Source => RM.Image_Decoded_Source_Buffer,
      Decoded_Bytes => Frame_Bytes,
      Encoded_Source_Bytes => null,
      Encoded_Source_Length => 0,
      Decoded_Preview_Length => Preview_Length,
      Decoded_Preview_Bytes => Frame_Bytes,
      Preview_Decode_Complete => True,
      Decode_Status => RM.Image_Decode_Ok,
      U0             => 0.0,
      V0             => 0.0,
      U1             => 1.0,
      V1             => 1.0,
      Image_ID       => Interfaces.Unsigned_32 (Header.Kitty_ID),
      Content_Serial => Object.Content_Serial,
      Z_Index        => Header.Kitty_Z_Index,
      Tint           => Graphics_Tint (Item.Protocol)));

   return True;
end Emit_Image_Object;
