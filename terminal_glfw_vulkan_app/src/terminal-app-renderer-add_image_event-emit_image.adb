separate (Terminal.App.Renderer.Add_Image_Event)
procedure Emit_Image
  (Item       : Terminal.Core.Graphics_Event;
   Image_Text : String)
is
   X : constant Float :=
     Float (Origin_X (R) + (Item.Col - 1) * R.CW);
   Y : constant Float :=
     Float (Origin_Y (R) + (Item.Row - 1) * R.CH);
   Data : Terminal.App.Graphics.Graphics_Data_Preview :=
     Terminal.App.Graphics.Data_Preview_Text (Item.Protocol, Image_Text);
   Header : constant Terminal.App.Graphics.Graphics_Header :=
     Terminal.App.Graphics.Header_Text (Item.Protocol, Image_Text);
   Raw_Format : constant Natural :=
     (if Data.Raw_Format > 0 then Data.Raw_Format else Header.Raw_Format);
   Pixel_Width : constant Natural :=
     (if Data.Pixel_Width > 0 then Data.Pixel_Width else Header.Pixel_Width);
   Pixel_Height : constant Natural :=
     (if Data.Pixel_Height > 0 then Data.Pixel_Height else Header.Pixel_Height);
   Payload_Complete : constant Boolean :=
     Item.Payload_Length > 0
     and then Image_Text'Length = Item.Payload_Length;
   Bytes_Per_Pixel : constant Natural :=
     (if Raw_Format = 24 then 3
      elsif Raw_Format = 32 then 4
      else 0);
   Row_Stride_Bytes : constant Natural :=
     (if Data.Decoded_Row_Stride_Bytes > 0
      then Data.Decoded_Row_Stride_Bytes
      elsif Bytes_Per_Pixel > 0
        and then Pixel_Width <= Natural'Last / Bytes_Per_Pixel
      then Pixel_Width * Bytes_Per_Pixel
      else 0);
   Expected_Decoded_Length : constant Natural :=
     Image_Buffer_Extent
       (Raw_Format, Pixel_Width, Pixel_Height, Row_Stride_Bytes);
   Raw_Texture_Ready : constant Boolean :=
     (Item.Protocol = Terminal.Core.Kitty_Graphics
      or else Item.Protocol = Terminal.Core.Sixel_Graphics
      or else Item.Protocol = Terminal.Core.ITerm2_Graphics)
     and then Pixel_Width > 0
     and then Pixel_Height > 0
     and then Bytes_Per_Pixel > 0
     and then Payload_Complete
     and then Data.Decode_Complete
     and then Expected_Decoded_Length > 0
     and then Data.Decoded_Length = Expected_Decoded_Length;
   Preview_Length : Natural := 0;
   Preview_Bytes : Terminal.Common.Bytes.Byte_Array
     (1 .. RM.Max_Image_Decoded_Preview_Length) := (others => 0);
   Image_Bytes : RM.Image_Data_Access := null;
   Image_View : RM.Image_Data_View := null;
   Preview_View : RM.Image_Data_View := null;
   Preview_Owner : RM.Image_Data_Access := null;
   Image_Bytes_Owned : Boolean := False;
   Borrowed_From_Object : Boolean := False;

   procedure Release_Local is
   begin
      if Preview_Owner /= null then
         Free_Image_Data (Preview_Owner);
      end if;
      if Image_Bytes /= null and then Image_Bytes_Owned then
         Free_Image_Data (Image_Bytes);
      end if;
      Preview_Owner := null;
      Image_Bytes := null;
      Image_Bytes_Owned := False;
      Terminal.App.Graphics.Release (Data);
   end Release_Local;
begin
   if not Item.Pending
     or else Item.Protocol = Terminal.Core.No_Graphics
     or else FIS.Is_Full (R.Frame_Images)
   then
      Terminal.App.Graphics.Release (Data);
      return;
   end if;

   if Data.Decoded_Length > R.Graphics_Limits.Per_Image_Bytes
     or else Data.Pixel_Width > R.Graphics_Limits.Pixel_Dimension
     or else Data.Pixel_Height > R.Graphics_Limits.Pixel_Dimension
   then
      Terminal.App.Graphics.Release (Data);
      R.Image_Store_Allocation_Failed := True;
      return;
   end if;

   Copy_Image_Preview
     (Data.Bytes, Data.Decoded_Length, Preview_Length, Preview_Bytes);

   if Data.Decoded_Length > 0
     and then Data.Decode_Complete
     and then Data.Bytes /= null
   then
      Image_Bytes := Data.Bytes;
      Data.Bytes := null;
      Image_Bytes_Owned := True;
   end if;

   if Item.Protocol = Terminal.Core.Kitty_Graphics
     and then
       (Header.Kitty_ID > 0 or else Header.Kitty_Action = 'T')
     and then Raw_Texture_Ready
     and then Image_Bytes /= null
   then
      declare
         Stored_Bytes : RM.Image_Data_View;
      begin
         Take_Image_Object
           (R              => R,
            Stream_ID      => Item.Stream_ID,
            ID             => Header.Kitty_ID,
            Image_Number   => Header.Kitty_Image_Number,
            Usage_Hint     => Header.Kitty_Usage_Hint,
            Protocol       => Graphics_Protocol (Item.Protocol),
            Raw_Format     => Raw_Format,
            Pixel_Width    => Pixel_Width,
            Pixel_Height   => Pixel_Height,
            Decoded_Length => Data.Decoded_Length,
            Decoded_Row_Stride_Bytes => Row_Stride_Bytes,
            Bytes          => Image_Bytes,
            Stored_Bytes   => Stored_Bytes);
         if Stored_Bytes /= null then
            Image_View := Stored_Bytes;
            Borrowed_From_Object := True;
         end if;
      end;
   end if;
   Image_Bytes_Owned := Image_Bytes /= null
     and then not Borrowed_From_Object;

   if Image_View = null then
      Image_View := RM.Read_Only (Image_Bytes);
   end if;
   Prepare_Image_Preview_Source
     (Image_View, Preview_Length, Preview_Bytes,
      Preview_View, Preview_Owner);

   declare
      Decoded_Owner : RM.Image_Data_Access :=
        (if Image_Bytes_Owned then Image_Bytes else null);
      Encoded_Owner : RM.Image_Data_Access := null;
   begin
      Append_Image_Command
        (R,
        (X              => X,
      Y              => Y,
      Width          =>
        Float (R.CW * Header.Placeholder_Cols),
      Height         =>
        Float (R.CH * Header.Placeholder_Rows),
      Protocol       => Graphics_Protocol (Item.Protocol),
      Placeholder    => not Raw_Texture_Ready,
      Raw_Format     => Raw_Format,
      Pixel_Width    => Pixel_Width,
      Pixel_Height   => Pixel_Height,
      Payload_Length => Item.Payload_Length,
      Staging_Byte_Length => 0,
      Payload_Preview_Complete => Payload_Complete,
      Encoded_Preview_Length => Data.Encoded_Length,
      Decoded_Byte_Length => Data.Decoded_Length,
      Decoded_Row_Stride_Bytes => Row_Stride_Bytes,
      Decoded_Source =>
        (if Raw_Texture_Ready
         then RM.Image_Decoded_Source_Buffer
         else RM.Image_Decoded_Source_None),
      Decoded_Bytes => Image_View,
      Encoded_Source_Bytes => null,
      Encoded_Source_Length => 0,
      Decoded_Preview_Length => Preview_Length,
      Decoded_Preview_Bytes => Preview_View,
      Preview_Decode_Complete => Data.Decode_Complete,
      Decode_Status =>
        Terminal.App.Graphics.Image_Decode_Status (Data.Decode_Status),
      U0             => 0.0,
      V0             => 0.0,
      U1             => 1.0,
      V1             => 1.0,
      Image_ID       =>
        (if Item.Protocol = Terminal.Core.Kitty_Graphics
         then Interfaces.Unsigned_32 (Header.Kitty_ID)
         else 0),
      Content_Serial =>
        (if R.Last_Stored_Image_Content_Serial /= 0
         then R.Last_Stored_Image_Content_Serial
         else Interfaces.Unsigned_64 (Item.Sequence)),
      Z_Index        =>
        (if Item.Protocol = Terminal.Core.Kitty_Graphics
         then Header.Kitty_Z_Index
         else 0),
         Tint           => Graphics_Tint (Item.Protocol)),
         Decoded_Owner, Encoded_Owner, Preview_Owner);
      if Image_Bytes_Owned then
         Image_Bytes := null;
      end if;
      Image_Bytes_Owned := False;
   end;
   Terminal.App.Graphics.Release (Data);
exception
   when others =>
      Release_Local;
      raise;
end Emit_Image;
