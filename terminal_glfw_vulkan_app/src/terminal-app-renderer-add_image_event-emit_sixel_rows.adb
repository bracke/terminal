separate (Terminal.App.Renderer.Add_Image_Event)
function Emit_Sixel_Rows
  (Item       : Terminal.Core.Graphics_Event;
   Header     : Terminal.App.Graphics.Graphics_Header;
   Image_Text : String) return Boolean
is
   X : constant Float :=
     Float (Origin_X (R) + (Item.Col - 1) * R.CW);
   Y : constant Float :=
     Float (Origin_Y (R) + (Item.Row - 1) * R.CH);
   Data : Terminal.App.Graphics.Graphics_Data_Preview :=
     (Header_Recognized => Header.Recognized,
      Has_Data          => Header.Has_Data,
      Raw_Format        => Header.Raw_Format,
      Pixel_Width       => Header.Pixel_Width,
      Pixel_Height      => Header.Pixel_Height,
      others            => <>);
   Image_Bytes : RM.Image_Data_Access := null;
   Image_View : RM.Image_Data_View := null;
   Image_Bytes_Owned : Boolean := False;
   Encoded_Source : RM.Image_Data_Access := null;
   Encoded_Source_Owned : Boolean := False;
   type Install_Guard is new Ada.Finalization.Limited_Controlled with record
      Storage_Order : Interfaces.Unsigned_64 := 0;
   end record;
   overriding procedure Finalize (Guard : in out Install_Guard);
   procedure Rollback (Guard : in out Install_Guard) is
      Order : constant Interfaces.Unsigned_64 := Guard.Storage_Order;
   begin
      if Order /= 0 then
         Delete_Image_Object_By_Storage_Order (R, Item.Stream_ID, Order);
      end if;
      Guard.Storage_Order := 0;
   end Rollback;
   overriding procedure Finalize (Guard : in out Install_Guard) is
   begin
      Rollback (Guard);
   end Finalize;
   Install : Install_Guard;
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
      Rollback (Install);
      if Image_Bytes /= null and then Image_Bytes_Owned then
         Free_Image_Data (Image_Bytes);
         Image_Bytes := null;
         Image_Bytes_Owned := False;
      end if;
      if Encoded_Source /= null and then Encoded_Source_Owned then
         Free_Image_Data (Encoded_Source);
         Encoded_Source := null;
         Encoded_Source_Owned := False;
      end if;
      Terminal.App.Graphics.Release (Data);
   end Release_Local;

   procedure Capture_Sixel_Row
     (Row_Y : Natural;
      Row   : Terminal.Common.Bytes.Byte_Array;
      Continue : in out Boolean)
   is
   begin
      Capture_Image_Row
        (Data,
         Image_Bytes,
         Image_Bytes_Owned,
         Row_Y,
         Row,
         R.Graphics_Limits.Per_Image_Bytes,
         R.Graphics_Limits.Pixel_Dimension,
         Continue);
      if Continue then
         Capture_Image_Preview_Row
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
     or else FIS.Is_Full (R.Frame_Images)
     or else Item.Payload_Length = 0
     or else Image_Text'Length /= Item.Payload_Length
   then
      return False;
   end if;

   if Item.Sixel_Private_Colors then
      Terminal.App.Graphics.Decode_Sixel_Rows
        (Image_Text,
         Capture_Sixel_Row'Access,
         Private_Palette,
         Reset_Palette => False,
         Result => Data,
         Maximum_Decoded_Bytes => R.Graphics_Limits.Per_Image_Bytes,
         Maximum_Pixel_Dimension => R.Graphics_Limits.Pixel_Dimension);
   else
      Shared_Palette := Sixel_Palette_For (R, Item.Stream_ID);
      if Shared_Palette = null then
         return False;
      end if;
      Terminal.App.Graphics.Decode_Sixel_Rows
        (Image_Text,
         Capture_Sixel_Row'Access,
         Shared_Palette.Palette,
         Reset_Palette => False,
         Result => Data,
         Maximum_Decoded_Bytes => R.Graphics_Limits.Per_Image_Bytes,
         Maximum_Pixel_Dimension => R.Graphics_Limits.Pixel_Dimension);
   end if;
   if Row_Copy_Failed
     or else not Data.Decode_Complete
     or else Data.Decoded_Length = 0
     or else Data.Decoded_Row_Stride_Bytes = 0
     or else not Image_Buffer_Ready (Data, Image_Bytes)
   then
      Release_Local;
      return False;
   end if;

   --  Keep the retained store unchanged when the diagnostic copy cannot
   --  be allocated.  No image object or placement exists before this
   --  final staging allocation succeeds.
   Encoded_Source := Terminal.App.Image_Ingestion.Copy_Text
     (Image_Text, R.Image_Allocation_Control);
   Encoded_Source_Owned := Encoded_Source /= null;
   if Encoded_Source = null then
      R.Image_Store_Allocation_Failed := True;
      Release_Local;
      return False;
   end if;

   declare
      Stored_Bytes : RM.Image_Data_View := null;
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
         Bytes          => Image_Bytes,
         Stored_Bytes   => Stored_Bytes);
      Stored_Order := R.Last_Stored_Image_Order;
      Install.Storage_Order := Stored_Order;
      if Stored_Bytes = null
        or else not Store_Auxiliary_Placement
          (R,
           Item,
           RM.Image_Sixel,
           Positive (Data.Pixel_Width),
           Positive (Data.Pixel_Height))
      then
         if Stored_Order /= 0 then
            Delete_Image_Object_By_Storage_Order
              (R, Item.Stream_ID, Stored_Order);
            Install.Storage_Order := 0;
         end if;
         Release_Local;
         return False;
      end if;
      Image_View := Stored_Bytes;
      Image_Bytes_Owned := False;
   end;

   declare
      Decoded_Owner : RM.Image_Data_Access :=
        (if Image_Bytes_Owned then Image_Bytes else null);
      Encoded_Owner : RM.Image_Data_Access :=
        (if Encoded_Source_Owned then Encoded_Source else null);
      Preview_Owner : RM.Image_Data_Access := null;
   begin
      Append_Image_Command
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
         Decoded_Bytes => Image_View,
         Encoded_Source_Bytes => RM.Read_Only (Encoded_Source),
         Encoded_Source_Length => Image_Text'Length,
         Decoded_Preview_Length => Preview_Length,
         Decoded_Preview_Bytes => Image_View,
         Preview_Decode_Complete => True,
         Decode_Status => RM.Image_Decode_Ok,
         U0             => 0.0,
         V0             => 0.0,
         U1             => 1.0,
         V1             => 1.0,
         Image_ID       => 0,
         Content_Serial => R.Last_Stored_Image_Content_Serial,
         Z_Index        => 0,
         Tint           => Graphics_Tint (Terminal.Core.Sixel_Graphics)),
         Decoded_Owner, Encoded_Owner, Preview_Owner);
      if Image_Bytes_Owned then
         Image_Bytes := null;
      end if;
      if Encoded_Source_Owned then
         Encoded_Source := null;
      end if;
   end;
   Image_Bytes_Owned := False;
   Encoded_Source_Owned := False;
   Install.Storage_Order := 0;

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
