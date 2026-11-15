separate (Terminal.App.Renderer.Add_Image_Event)
procedure Emit_Image
  (Item       : Terminal.Core.Graphics_Event;
   Image_Text : String)
is
   X : constant Float :=
     Float (Origin_X (R) + (Item.Col - 1) * R.Text_State.CW);
   Y : constant Float :=
     Float (Origin_Y (R) + (Item.Row - 1) * R.Text_State.CH);
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
     Image_Buffers.Extent
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
   Image_Owner : Terminal.App.Owned_Image_Data.Owner;
   Preview_View : RM.Image_Data_View := null;
   Preview_Owner : Terminal.App.Owned_Image_Data.Owner;
   Borrowed_Object : Image_Object_Access := null;
   Geometry : Placement_Geometry;
   Display_Width : Natural := 0;
   Display_Height : Natural := 0;

   procedure Release_Local is
   begin
      Terminal.App.Owned_Image_Data.Release (Preview_Owner);
      Terminal.App.Owned_Image_Data.Release (Image_Owner);
      Terminal.App.Graphics.Release (Data);
   end Release_Local;
begin
   if FIS.Is_Full (R.Frame_State.Frame_Images) then
      R.Frame_State.Frame_Command_Overflowed := True;
      Terminal.App.Graphics.Release (Data);
      return;
   end if;
   if not Item.Pending
     or else Item.Protocol = Terminal.Core.No_Graphics
   then
      Terminal.App.Graphics.Release (Data);
      return;
   end if;

   if Data.Decoded_Length > R.Graphics_State.Policy.Limits.Per_Image_Bytes
     or else Data.Pixel_Width > R.Graphics_State.Policy.Limits.Pixel_Dimension
     or else Data.Pixel_Height > R.Graphics_State.Policy.Limits.Pixel_Dimension
   then
      Terminal.App.Graphics.Release (Data);
      R.Graphics_State.Transaction.Image_Store_Allocation_Failed := True;
      return;
   end if;

   Image_Buffers.Copy_Preview
     (Data, Data.Decoded_Length, Preview_Length, Preview_Bytes);

   if Data.Decoded_Length > 0
     and then Data.Decode_Complete
     and then Terminal.App.Graphics.Has_Bytes (Data)
   then
      Terminal.App.Graphics.Take_Bytes (Data, Image_Owner);
   end if;

   if Item.Protocol = Terminal.Core.Kitty_Graphics
     and then
       (Header.Kitty_ID > 0 or else Header.Kitty_Action = 'T')
     and then Raw_Texture_Ready
     and then not Terminal.App.Owned_Image_Data.Is_Empty (Image_Owner)
   then
      declare
         Stored_Object : Image_Object_Access;
      begin
         Take_Image_Object
           (R              => R,
            Stream_ID      => Item.Stream_ID,
            ID             => Header.Kitty_ID,
            Image_Number   => Header.Kitty_Image_Number,
            Usage_Hint     => Header.Kitty_Usage_Hint,
            Protocol       => Style.Graphics_Protocol (Item.Protocol),
            Raw_Format     => Raw_Format,
            Pixel_Width    => Pixel_Width,
            Pixel_Height   => Pixel_Height,
            Decoded_Length => Data.Decoded_Length,
            Decoded_Row_Stride_Bytes => Row_Stride_Bytes,
            Bytes          => Image_Owner,
            Stored_Object  => Stored_Object);
         if Stored_Object /= null then
            Borrowed_Object := Stored_Object;
         end if;
      end;
   end if;

   if Borrowed_Object = null then
      Image_Buffers.Prepare_Preview_Source
        (null, Preview_Length, Preview_Bytes,
         Preview_View, Preview_Owner);
   end if;

   if Item.Protocol = Terminal.Core.Kitty_Graphics then
      Geometry := Placements_State.Resolve_Placement_Geometry
        (R, Pixel_Width, Pixel_Height, Header);
   end if;
   if Geometry.Valid then
      Display_Width := Geometry.Draw_Width;
      Display_Height := Geometry.Draw_Height;
   elsif not Terminal.App.Size_Arithmetic.Try_Multiply
       (R.Text_State.CW, Header.Placeholder_Cols, Display_Width)
     or else not Terminal.App.Size_Arithmetic.Try_Multiply
       (R.Text_State.CH, Header.Placeholder_Rows, Display_Height)
   then
      Release_Local;
      return;
   end if;

   declare
      Encoded_Owner : Terminal.App.Owned_Image_Data.Owner;
      Command : constant RM.Image_Command :=
        (X              => X
           + (if Geometry.Valid
              then Float (Geometry.Draw_Offset_X)
              else 0.0),
         Y              => Y
           + (if Geometry.Valid
              then Float (Geometry.Draw_Offset_Y)
              else 0.0),
         Width          => Float (Display_Width),
         Height         => Float (Display_Height),
         Protocol       => Style.Graphics_Protocol (Item.Protocol),
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
         Decoded_Bytes => null,
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
         Content_Serial => Command_Content_Serial,
         Z_Index        =>
           (if Item.Protocol = Terminal.Core.Kitty_Graphics
            then Header.Kitty_Z_Index
            else 0),
         Tint           => Style.Graphics_Tint (Item.Protocol));
   begin
      if Borrowed_Object /= null then
         Append_Borrowed_Frame_Command
           (R, Command, Borrowed_Object,
            Animation_State.Display_Frame (Borrowed_Object));
      else
         Append_Image_Command
           (R, Command, Image_Owner, Encoded_Owner, Preview_Owner);
      end if;
   end;
   Terminal.App.Graphics.Release (Data);
exception
   when others =>
      Release_Local;
      raise;
end Emit_Image;
