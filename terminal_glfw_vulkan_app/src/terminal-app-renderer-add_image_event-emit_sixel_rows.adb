with Terminal.App.Graphics.Media_Decoders;

separate (Terminal.App.Renderer.Add_Image_Event)
function Emit_Sixel_Rows
  (Item       : Terminal.Core.Graphics_Event;
   Header     : Terminal.App.Graphics.Graphics_Header;
   Image_Text : String) return Boolean
is
   X : constant Float :=
     Float (Origin_X (R) + (Item.Col - 1) * R.Text_State.CW);
   Y : constant Float :=
     Float (Origin_Y (R) + (Item.Row - 1) * R.Text_State.CH);
   Data : Terminal.App.Graphics.Graphics_Data_Preview :=
     Terminal.App.Graphics.Metadata_Preview
       (Header_Recognized => Header.Recognized,
        Has_Data          => Header.Has_Data,
        Raw_Format        => Header.Raw_Format,
        Pixel_Width       => Header.Pixel_Width,
        Pixel_Height      => Header.Pixel_Height);
   Image_Owner : Terminal.App.Owned_Image_Data.Owner;
   Borrowed_Object : Image_Object_Access := null;
   Encoded_Owner : Terminal.App.Owned_Image_Data.Owner;
   Install : Install_Guard (Item.Stream_ID);
   Row_Copy_Failed : Boolean := False;
   Preview_Length : Natural := 0;
   Preview_Bytes : Terminal.Common.Bytes.Byte_Array
     (1 .. RM.Max_Image_Decoded_Preview_Length) := (others => 0);
   Private_Palette : Terminal.App.Graphics.Sixel_Palette_State :=
     Terminal.App.Graphics.Default_Sixel_Palette;
   Shared_Palette : Sixel_Palette_Entry_Access := null;

   function Sixel_Encoded_Length return Natural is
   begin
      for I in Image_Text'Range loop
         if Image_Text (I) = 'q' then
            return (if I < Image_Text'Last then Image_Text'Last - I else 0);
         end if;
      end loop;
      return Image_Text'Length;
   end Sixel_Encoded_Length;

   procedure Release_Local is
   begin
      Terminal.App.Owned_Image_Data.Release (Image_Owner);
      Terminal.App.Owned_Image_Data.Release (Encoded_Owner);
      Terminal.App.Graphics.Release (Data);
      Rollback (Install);
   end Release_Local;

   procedure Capture_Sixel_Row
     (Row_Y : Natural;
      Row   : Terminal.Common.Bytes.Byte_Array;
      Continue : in out Boolean)
   is
   begin
      Image_Buffers.Capture_Row
        (Data,
         Image_Owner,
         Row_Y,
         Row,
         R.Graphics_State.Policy.Limits.Per_Image_Bytes,
         R.Graphics_State.Policy.Limits.Pixel_Dimension,
         Continue);
      if Continue then
         Image_Buffers.Capture_Preview_Row
           (Preview_Length, Preview_Bytes, Row_Y, Row, Continue);
      end if;
      if not Continue then
         Row_Copy_Failed := True;
      end if;
   end Capture_Sixel_Row;
begin
   if not Header.Recognized
     or else not Header.Has_Data
     or else Header.Raw_Format /= 32
     or else Header.Pixel_Width = 0
     or else Header.Pixel_Height = 0
     or else FIS.Is_Full (R.Frame_State.Frame_Images)
     or else Item.Payload_Length = 0
     or else Image_Text'Length /= Item.Payload_Length
   then
      return False;
   end if;

   if Item.Sixel_Private_Colors then
      Terminal.App.Graphics.Media_Decoders.Decode_Sixel_Rows
        (Image_Text,
         Capture_Sixel_Row'Access,
         Private_Palette,
         Reset_Palette => False,
         Result => Data,
         Maximum_Decoded_Bytes => R.Graphics_State.Policy.Limits.Per_Image_Bytes,
         Maximum_Pixel_Dimension => R.Graphics_State.Policy.Limits.Pixel_Dimension);
   else
      Shared_Palette := Sixel_Palette_For (R, Item.Stream_ID);
      if Shared_Palette = null then
         return False;
      end if;
      Terminal.App.Graphics.Media_Decoders.Decode_Sixel_Rows
        (Image_Text,
         Capture_Sixel_Row'Access,
         Shared_Palette.Palette,
         Reset_Palette => False,
         Result => Data,
         Maximum_Decoded_Bytes => R.Graphics_State.Policy.Limits.Per_Image_Bytes,
         Maximum_Pixel_Dimension => R.Graphics_State.Policy.Limits.Pixel_Dimension);
   end if;
   if Row_Copy_Failed
     or else not Data.Decode_Complete
     or else Data.Decoded_Length = 0
     or else Data.Decoded_Row_Stride_Bytes = 0
     or else not Image_Buffers.Ready (Data, Image_Owner)
   then
      Release_Local;
      return False;
   end if;

   --  Keep the retained store unchanged when the diagnostic copy cannot
   --  be allocated.  No image object or placement exists before this
   --  final staging allocation succeeds.
   Terminal.App.Image_Ingestion.Copy_Text
     (Image_Text,
      R.Graphics_State.Resources.Allocation_Control,
      Encoded_Owner);
   if Terminal.App.Owned_Image_Data.Is_Empty (Encoded_Owner) then
      R.Graphics_State.Transaction.Image_Store_Allocation_Failed := True;
      Release_Local;
      return False;
   end if;

   declare
      Stored_Object : Image_Object_Access := null;
      Stored_Order : Interfaces.Unsigned_64;
   begin
      Take_Image_Object
        (R              => R,
         Stream_ID      => Item.Stream_ID,
         ID             => 0,
         Image_Number   => 0,
         Usage_Hint     => 0,
         Protocol       => RM.Image_Sixel,
         Raw_Format     => Data.Raw_Format,
         Pixel_Width    => Data.Pixel_Width,
         Pixel_Height   => Data.Pixel_Height,
         Decoded_Length => Data.Decoded_Length,
         Decoded_Row_Stride_Bytes => Data.Decoded_Row_Stride_Bytes,
         Bytes          => Image_Owner,
         Stored_Object  => Stored_Object);
      Stored_Order := R.Graphics_State.Transaction.Last_Stored_Image_Order;
      Arm (Install, Stored_Order);
      if Stored_Object = null
        or else not Store_Auxiliary_Placement
          (R,
           Item,
           RM.Image_Sixel,
           Positive (Data.Pixel_Width),
           Positive (Data.Pixel_Height))
      then
         if Stored_Order /= 0 then
            Image_Objects.Delete_By_Storage_Order
              (R, Item.Stream_ID, Stored_Order);
            Commit (Install);
         end if;
         Release_Local;
         return False;
      end if;
      Borrowed_Object := Stored_Object;
   end;

   Append_Borrowed_Frame_Command
        (R,
        (X              => X,
         Y              => Y,
         Width          =>
           Float (Data.Pixel_Width),
         Height         =>
           Float (Data.Pixel_Height),
         Protocol       => RM.Image_Sixel,
         Placeholder    => False,
         Raw_Format     => Data.Raw_Format,
         Pixel_Width    => Data.Pixel_Width,
         Pixel_Height   => Data.Pixel_Height,
         Payload_Length => Item.Payload_Length,
         Staging_Byte_Length => 0,
         Payload_Preview_Complete => True,
         Encoded_Preview_Length => Sixel_Encoded_Length,
         Decoded_Byte_Length => Data.Decoded_Length,
         Decoded_Row_Stride_Bytes => Data.Decoded_Row_Stride_Bytes,
         Decoded_Source => RM.Image_Decoded_Source_Buffer,
         Decoded_Bytes => null,
         Encoded_Source_Bytes => null,
         Encoded_Source_Length => 0,
         Decoded_Preview_Length => Preview_Length,
         Decoded_Preview_Bytes => null,
         Preview_Decode_Complete => True,
         Decode_Status => RM.Image_Decode_Ok,
         U0             => 0.0,
         V0             => 0.0,
         U1             => 1.0,
         V1             => 1.0,
         Image_ID       => 0,
         Content_Serial => R.Graphics_State.Transaction.Last_Stored_Image_Content_Serial,
         Z_Index        => 0,
         Tint           => Style.Graphics_Tint (Terminal.Core.Sixel_Graphics)),
         Borrowed_Object,
         Animation_State.Display_Frame (Borrowed_Object));
   Commit (Install);

   Terminal.App.Graphics.Release (Data);
   return True;
exception
   when Storage_Error =>
      Release_Local;
      return False;
   when others =>
      Release_Local;
      raise;
end Emit_Sixel_Rows;
