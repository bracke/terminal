separate (Terminal.App.Renderer.Add_Image_Event)
function Emit_Image_Object
  (Item   : Terminal.Core.Graphics_Event;
   Header : Terminal.App.Graphics.Graphics_Header) return Boolean
is
   Object : constant Image_Object_Access :=
     Image_Objects.Find (R, Item.Stream_ID, Header.Kitty_ID);
   Geometry : constant Placement_Geometry :=
     Placements_State.Resolve_Placement_Geometry (R, Object, Header);
   Preview_Length : Natural := 0;
   Preview_Bytes : Terminal.Common.Bytes.Byte_Array
     (1 .. RM.Max_Image_Decoded_Preview_Length) := (others => 0);
   Display_Borrow : Terminal.App.Image_Store.Data_Borrow;
   Appended : Boolean := False;
   Frame_Format : constant Natural := Animation_State.Display_Format (Object);
   Frame_Length : constant Natural := Animation_State.Display_Length (Object);
   Frame_Stride : constant Natural := Animation_State.Display_Stride (Object);
   procedure Append_Frame (Data : Terminal.Common.Bytes.Byte_Array) is
   begin
      Image_Buffers.Copy_Preview
        (Data, Frame_Length,
         Preview_Length,
         Preview_Bytes);
      Append_Borrowed_Frame_Command
        (R,
         (X => Float (Origin_X (R) + (Item.Col - 1) * R.Text_State.CW)
            + Float (Geometry.Draw_Offset_X),
          Y => Float (Origin_Y (R) + (Item.Row - 1) * R.Text_State.CH)
            + Float (Geometry.Draw_Offset_Y),
          Width => Float (Geometry.Draw_Width),
          Height => Float (Geometry.Draw_Height),
          Protocol => Object.Protocol,
          Placeholder => False,
          Raw_Format => Frame_Format,
          Pixel_Width => Object.Pixel_Width,
          Pixel_Height => Object.Pixel_Height,
          Payload_Length => Item.Payload_Length,
          Staging_Byte_Length => 0,
          Payload_Preview_Complete => True,
          Encoded_Preview_Length => 0,
          Decoded_Byte_Length => Frame_Length,
          Decoded_Row_Stride_Bytes => Frame_Stride,
          Decoded_Source => RM.Image_Decoded_Source_Buffer,
          Decoded_Bytes => null,
          Encoded_Source_Bytes => null,
          Encoded_Source_Length => 0,
          Decoded_Preview_Length => Preview_Length,
          Decoded_Preview_Bytes => null,
          Preview_Decode_Complete => True,
          Decode_Status => RM.Image_Decode_Ok,
          U0 => 0.0,
          V0 => 0.0,
          U1 => 1.0,
          V1 => 1.0,
          Image_ID => Interfaces.Unsigned_32 (Header.Kitty_ID),
          Content_Serial => Object.Content_Serial,
          Z_Index => Header.Kitty_Z_Index,
          Tint => Style.Graphics_Tint (Item.Protocol)),
         Object,
         Animation_State.Display_Frame (Object));
      Appended := True;
   end Append_Frame;
begin
   if Object = null
     or else not Geometry.Valid
     or else FIS.Is_Full (R.Frame_State.Frame_Images)
   then
      return False;
   end if;

   Animation_State.Visit_Display_Bytes
     (Object, Display_Borrow, Append_Frame'Access);
   return Appended;
end Emit_Image_Object;
