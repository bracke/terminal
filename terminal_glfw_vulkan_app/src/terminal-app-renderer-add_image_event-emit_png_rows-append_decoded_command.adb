separate (Terminal.App.Renderer.Add_Image_Event.Emit_PNG_Rows)
function Append_Decoded_Command return Boolean is
   Geometry : constant Placement_Geometry :=
     (if Item.Protocol = Terminal.Core.Kitty_Graphics
      then Placements_State.Resolve_Placement_Geometry
        (R, Data.Pixel_Width, Data.Pixel_Height, Header)
      else (others => <>));
   Available_Width : constant Natural :=
     (if Item.Protocol = Terminal.Core.Kitty_Graphics
       and then Header.Kitty_Source_X < Data.Pixel_Width
      then Data.Pixel_Width - Header.Kitty_Source_X
      else Data.Pixel_Width);
   Available_Height : constant Natural :=
     (if Item.Protocol = Terminal.Core.Kitty_Graphics
       and then Header.Kitty_Source_Y < Data.Pixel_Height
      then Data.Pixel_Height - Header.Kitty_Source_Y
      else Data.Pixel_Height);
   Source_Width : constant Natural :=
     (if Item.Protocol /= Terminal.Core.Kitty_Graphics
       or else Header.Kitty_Source_Width = 0
      then Available_Width
      else Natural'Min (Header.Kitty_Source_Width, Available_Width));
   Source_Height : constant Natural :=
     (if Item.Protocol /= Terminal.Core.Kitty_Graphics
       or else Header.Kitty_Source_Height = 0
      then Available_Height
      else Natural'Min (Header.Kitty_Source_Height, Available_Height));
   Source_Kind : constant RM.Image_Decoded_Source_Kind :=
     (if Item.Protocol = Terminal.Core.ITerm2_Graphics
      then RM.Image_Decoded_Source_Buffer
      elsif Item.Protocol = Terminal.Core.Kitty_Graphics
        and then
          (Header.Kitty_ID > 0
           or else Borrowed_Object /= null
           or else Header.Kitty_Compression = 'z')
      then RM.Image_Decoded_Source_Buffer
      else RM.Image_Decoded_Source_PNG_Base64);
   ITerm2_Size : constant Terminal.App.Image_Ingestion.Pixel_Size :=
     Terminal.App.Image_Ingestion.ITerm2_Render_Size
       (Header,
        Positive (Data.Pixel_Width),
        Positive (Data.Pixel_Height),
        R.Text_State.CW,
        R.Text_State.CH,
        (if R.Frame_State.Last_Frame_Width > R.View_State.Content_Padding * 2
         then R.Frame_State.Last_Frame_Width - R.View_State.Content_Padding * 2
         else R.Text_State.CW),
        (if R.Frame_State.Last_Frame_Height > R.View_State.Content_Padding * 2
         then R.Frame_State.Last_Frame_Height - R.View_State.Content_Padding * 2
         else R.Text_State.CH));
   ITerm2_Draw_Width  : constant Float := ITerm2_Size.Width;
   ITerm2_Draw_Height : constant Float := ITerm2_Size.Height;

   procedure Copy_Display_Preview
     (Bytes : Terminal.Common.Bytes.Byte_Array) is
   begin
      Image_Buffers.Copy_Preview
        (Bytes, Data.Decoded_Length, Preview_Length, Preview_Bytes);
   end Copy_Display_Preview;

   procedure Append_Prepared (Command : RM.Image_Command) is
   begin
      if Borrowed_Object /= null then
         Append_Borrowed_Frame_Command
           (R, Command, Borrowed_Object,
            Animation_State.Display_Frame (Borrowed_Object));
      else
         Append_Image_Command
           (R, Command, Image_Owner, Encoded_Owner, Preview_Owner);
      end if;
   end Append_Prepared;
begin
   if Item.Protocol = Terminal.Core.Kitty_Graphics
     and then Header.Kitty_Action = 'T'
     and then not Geometry.Valid
   then
      return False;
   end if;
   if Store_Decoded then
      if Borrowed_Object /= null then
         declare
            Borrow : Terminal.App.Image_Store.Data_Borrow;
         begin
            Animation_State.Visit_Display_Bytes
              (Borrowed_Object, Borrow, Copy_Display_Preview'Access);
         end;
      else
         Image_Buffers.Copy_Preview
           (Image_Owner, Data.Decoded_Length, Preview_Length, Preview_Bytes);
      end if;
   end if;
   if Borrowed_Object = null then
      Image_Buffers.Prepare_Preview_Source
        (null, Preview_Length, Preview_Bytes, Preview_View, Preview_Owner);
   end if;
   if Item.Protocol = Terminal.Core.ITerm2_Graphics
     and then not Store_Auxiliary_Placement
       (R,
        Item,
        RM.Image_ITerm2,
        Positive (Float'Ceiling (ITerm2_Draw_Width)),
        Positive (Float'Ceiling (ITerm2_Draw_Height)))
   then
      return False;
   end if;
   Append_Prepared
     ((X => X
         + (if Geometry.Valid
            then Float (Header.Kitty_Cell_X + Geometry.Draw_Offset_X)
            else 0.0),
       Y => Y
         + (if Geometry.Valid
            then Float (Header.Kitty_Cell_Y + Geometry.Draw_Offset_Y)
            else 0.0),
       Width =>
         (if Geometry.Valid
          then Float (Geometry.Draw_Width)
          elsif Item.Protocol = Terminal.Core.ITerm2_Graphics
          then ITerm2_Draw_Width
          else Float (R.Text_State.CW * Header.Placeholder_Cols)),
       Height =>
         (if Geometry.Valid
          then Float (Geometry.Draw_Height)
          elsif Item.Protocol = Terminal.Core.ITerm2_Graphics
          then ITerm2_Draw_Height
          else Float (R.Text_State.CH * Header.Placeholder_Rows)),
       Protocol => Style.Graphics_Protocol (Item.Protocol),
       Placeholder => False,
       Raw_Format => Data.Raw_Format,
       Pixel_Width => Data.Pixel_Width,
       Pixel_Height => Data.Pixel_Height,
       Payload_Length => Item.Payload_Length,
       Staging_Byte_Length => PNG_Length,
       Payload_Preview_Complete => True,
       Encoded_Preview_Length => Encoded_Length,
       Decoded_Byte_Length => Data.Decoded_Length,
       Decoded_Row_Stride_Bytes => Data.Decoded_Row_Stride_Bytes,
       Decoded_Source => Source_Kind,
       Decoded_Bytes => null,
       Encoded_Source_Bytes => null,
       Encoded_Source_Length => 0,
       Decoded_Preview_Length => Preview_Length,
       Decoded_Preview_Bytes => Preview_View,
       Preview_Decode_Complete => True,
       Decode_Status => RM.Image_Decode_Ok,
       U0 =>
         (if Item.Protocol = Terminal.Core.Kitty_Graphics
          then Float (Header.Kitty_Source_X) / Float (Data.Pixel_Width)
          else 0.0),
       V0 =>
         (if Item.Protocol = Terminal.Core.Kitty_Graphics
          then Float (Header.Kitty_Source_Y) / Float (Data.Pixel_Height)
          else 0.0),
       U1 =>
         (if Item.Protocol = Terminal.Core.Kitty_Graphics
          then Float (Header.Kitty_Source_X + Source_Width)
            / Float (Data.Pixel_Width)
          else 1.0),
       V1 =>
         (if Item.Protocol = Terminal.Core.Kitty_Graphics
          then Float (Header.Kitty_Source_Y + Source_Height)
            / Float (Data.Pixel_Height)
          else 1.0),
       Image_ID =>
         (if Item.Protocol = Terminal.Core.Kitty_Graphics
          then Interfaces.Unsigned_32 (Header.Kitty_ID)
          else 0),
       Content_Serial => Command_Content_Serial,
       Z_Index =>
         (if Item.Protocol = Terminal.Core.Kitty_Graphics
          then Header.Kitty_Z_Index
          else 0),
       Tint => Style.Graphics_Tint (Item.Protocol)));
   return True;
end Append_Decoded_Command;
