separate (Terminal.App.Renderer)
procedure Add_Background_Image (R : in out Renderer) is
   Object : constant Image_Object_Access := R.View_State.Background_Object;
   Command : RM.Image_Command;
begin
   if Object = null or else R.View_State.Background_Opacity <= 0.0 then
      return;
   end if;
   Command :=
     (X              => 0.0,
      Y              => 0.0,
      Width          => Float (R.Frame_State.Last_Frame_Width),
      Height         => Float (R.Frame_State.Last_Frame_Height),
      Protocol       => RM.Image_Kitty,
      Placeholder    => False,
      Raw_Format     => Terminal.App.Image_Store.Raw_Format (Object.all),
      Pixel_Width    => Terminal.App.Image_Store.Pixel_Width (Object.all),
      Pixel_Height   => Terminal.App.Image_Store.Pixel_Height (Object.all),
      Payload_Length => Terminal.App.Image_Store.Decoded_Length (Object.all),
      Staging_Byte_Length => Terminal.App.Image_Store.Decoded_Length (Object.all),
      Decoded_Byte_Length => Terminal.App.Image_Store.Decoded_Length (Object.all),
      Decoded_Row_Stride_Bytes =>
        Terminal.App.Image_Store.Decoded_Row_Stride_Bytes (Object.all),
      Decoded_Source => RM.Image_Decoded_Source_Buffer,
      Decode_Status  => RM.Image_Decode_Ok,
      Image_ID       => Interfaces.Unsigned_32
        (Terminal.App.Image_Store.ID (Object.all)),
      Content_Serial => Terminal.App.Image_Store.Content_Serial (Object.all),
      Z_Index        => Integer'First,
      Tint           =>
        (R => 1.0, G => 1.0, B => 1.0,
         A => R.View_State.Background_Opacity),
      others         => <>);
   Append_Borrowed_Frame_Command
     (R, Command, Object, Frame_Number => 1);
end Add_Background_Image;
