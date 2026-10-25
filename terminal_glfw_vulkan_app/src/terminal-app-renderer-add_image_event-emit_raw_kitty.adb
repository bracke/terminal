separate (Terminal.App.Renderer.Add_Image_Event)
function Emit_Raw_Kitty
  (Item       : Terminal.Core.Graphics_Event;
   Header     : Terminal.App.Graphics.Graphics_Header;
   Image_Text : String) return Boolean
is
      Raw_Format : constant Natural := Header.Raw_Format;
      Bytes_Per_Pixel : constant Natural :=
        (if Raw_Format = 8 then 1
         elsif Raw_Format = 16 then 2
         elsif Raw_Format = 24 then 3
         elsif Raw_Format = 32 then 4
         else 0);
      Row_Stride : constant Natural :=
        (if Bytes_Per_Pixel > 0
           and then Header.Pixel_Width <= Natural'Last / Bytes_Per_Pixel
         then Header.Pixel_Width * Bytes_Per_Pixel
         else 0);
      Expected_Length : constant Natural :=
        Image_Buffer_Extent
          (Raw_Format,
           Header.Pixel_Width,
           Header.Pixel_Height,
           Row_Stride);
   First_Data : constant Natural :=
     Terminal.App.Image_Ingestion.Payload_Start
       (Terminal.App.Image_Ingestion.Kitty, Image_Text);
   X : constant Float :=
     Float (Origin_X (R) + (Item.Col - 1) * R.CW);
   Y : constant Float :=
     Float (Origin_Y (R) + (Item.Row - 1) * R.CH);
   Encoded_Length : Natural := 0;
   Data : Terminal.App.Graphics.Graphics_Data_Preview;
   Image_Bytes : RM.Image_Data_Access := null;
   Image_View : RM.Image_Data_View := null;
   Preview_View : RM.Image_Data_View := null;
   Preview_Owner : RM.Image_Data_Access := null;
   Image_Bytes_Owned : Boolean := False;
   Indexed_Bytes : RM.Image_Data_Access := null;
   Indexed_Bytes_Owned : Boolean := False;
   Render_Format : Natural := Raw_Format;
   Render_Length : Natural := Expected_Length;
   Render_Stride : Natural := Row_Stride;
   Encoded_Source : RM.Image_Data_Access := null;
   Encoded_Source_Owned : Boolean := False;
   Borrowed_From_Object : Boolean := False;
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
   Store_Decoded : constant Boolean :=
     Header.Kitty_ID > 0
     or else Header.Kitty_Action = 'T'
     or else Header.Kitty_Compression = 'z'
     or else Raw_Format in 8 | 16;
   Row_Copy_Failed : Boolean := False;
   Preview_Length : Natural := 0;
   Preview_Bytes : Terminal.Common.Bytes.Byte_Array
     (1 .. RM.Max_Image_Decoded_Preview_Length) := (others => 0);
   procedure Capture_Raw_Row
     (Row_Y : Natural;
      Row : Terminal.Common.Bytes.Byte_Array;
      Continue : in out Boolean)
   is
   begin
      if Store_Decoded then
         Capture_Image_Row
           (Data,
            Image_Bytes,
            Image_Bytes_Owned,
            Row_Y,
            Row,
            R.Graphics_Limits.Per_Image_Bytes,
            R.Graphics_Limits.Pixel_Dimension,
            Continue);
      else
         Capture_Image_Preview_Row
           (Preview_Length, Preview_Bytes, Row_Y, Row, Continue);
      end if;
      if not Continue then
         Row_Copy_Failed := True;
      end if;
   end Capture_Raw_Row;

   procedure Release_Local is
   begin
      Rollback (Install);
      Terminal.App.Graphics.Release (Data);
      if Image_Bytes /= null and then Image_Bytes_Owned then
         Free_Image_Data (Image_Bytes);
      end if;
      if Indexed_Bytes /= null and then Indexed_Bytes_Owned then
         Free_Image_Data (Indexed_Bytes);
      end if;
      if Encoded_Source /= null and then Encoded_Source_Owned then
         Free_Image_Data (Encoded_Source);
      end if;
      if Preview_Owner /= null then
         Free_Image_Data (Preview_Owner);
      end if;
      Image_Bytes := null;
      Image_Bytes_Owned := False;
      Indexed_Bytes := null;
      Indexed_Bytes_Owned := False;
      Encoded_Source := null;
      Encoded_Source_Owned := False;
      Preview_Owner := null;
   end Release_Local;
begin
   if not Header.Recognized
     or else not Header.Has_Data
     or else Bytes_Per_Pixel = 0
     or else Header.Pixel_Width = 0
     or else Header.Pixel_Height = 0
     or else Expected_Length = 0
     or else Expected_Length > RM.Max_Image_Decoded_Data_Length
     or else First_Data = 0
     or else FIS.Is_Full (R.Frame_Images)
     or else Item.Payload_Length = 0
     or else Image_Text'Length /= Item.Payload_Length
     or else Header.Kitty_Compression not in ASCII.NUL | 'z'
   then
      return False;
   end if;

   Encoded_Length := Image_Text'Last - First_Data + 1;
   if Header.Kitty_Compression = 'z' then
      declare
         function Single_Chunk (Index : Positive) return String is
           (if Index = 1
            then Image_Text (First_Data .. Image_Text'Last)
            else "");
      begin
         Terminal.App.Graphics.Decode_Base64_Zlib_Raw_Chunk_Rows
           (1,
            Single_Chunk'Access,
            Raw_Format,
            Header.Pixel_Width,
            Header.Pixel_Height,
            Capture_Raw_Row'Access,
            Data);
      end;
   else
      Terminal.App.Graphics.Decode_Base64_Raw_Rows
        (Image_Text (First_Data .. Image_Text'Last),
         Raw_Format,
         Header.Pixel_Width,
         Header.Pixel_Height,
         Capture_Raw_Row'Access,
         Data);
   end if;

   if Row_Copy_Failed
     or else Data.Decoded_Length /= Expected_Length
     or else (Store_Decoded
              and then not Image_Buffer_Ready (Data, Image_Bytes))
   then
      Release_Local;
      return False;
   end if;

   if Raw_Format in 8 | 16 then
      if Header.Pixel_Width > Natural'Last / Header.Pixel_Height
        or else Header.Pixel_Width * Header.Pixel_Height > Natural'Last / 4
        or else Header.Pixel_Width * Header.Pixel_Height * 4 >
          R.Graphics_Limits.Per_Image_Bytes
      then
         Release_Local;
         return False;
      end if;
      Indexed_Bytes := Image_Bytes;
      Indexed_Bytes_Owned := Image_Bytes_Owned;
      Image_Bytes :=
        new Terminal.Common.Bytes.Byte_Array
          (1 .. Header.Pixel_Width * Header.Pixel_Height * 4);
      Image_Bytes_Owned := True;
      if not Expand_Kitty_Indexed
        (R,
         Raw_Format,
         Header.Pixel_Width,
         Header.Pixel_Height,
         RM.Read_Only (Indexed_Bytes),
         Image_Bytes)
      then
         Release_Local;
         return False;
      end if;
      Render_Format := 32;
      Render_Length := Header.Pixel_Width * Header.Pixel_Height * 4;
      Render_Stride := Header.Pixel_Width * 4;
   end if;

   if Header.Kitty_Action = 'T'
     and then not Resolve_Placement_Geometry
       (R, Header.Pixel_Width, Header.Pixel_Height, Header).Valid
   then
      Release_Local;
      return False;
   end if;

   if Header.Kitty_ID > 0 or else Header.Kitty_Action = 'T' then
      declare
         Stored_Bytes : RM.Image_Data_View;
      begin
         Take_Image_Object
           (R              => R,
            Stream_ID      => Item.Stream_ID,
            ID             => Header.Kitty_ID,
            Image_Number   => Header.Kitty_Image_Number,
            Usage_Hint     => Header.Kitty_Usage_Hint,
            Protocol       => RM.Image_Kitty,
            Raw_Format     => Render_Format,
            Pixel_Width    => Header.Pixel_Width,
            Pixel_Height   => Header.Pixel_Height,
            Decoded_Length => Render_Length,
            Decoded_Row_Stride_Bytes =>
              Render_Stride,
            Bytes          => Image_Bytes,
            Stored_Bytes   => Stored_Bytes,
            Additional_Bytes =>
              (if Raw_Format in 8 | 16 then Data.Decoded_Length else 0));
         if Stored_Bytes /= null then
            Install.Storage_Order := R.Last_Stored_Image_Order;
            Image_View := Stored_Bytes;
            Image_Bytes_Owned := False;
            Borrowed_From_Object := True;
            if Raw_Format in 8 | 16 then
               declare
                  Object : constant Image_Object_Access :=
                    Find_Image_Object_By_Storage_Order
                      (R, Item.Stream_ID, R.Last_Stored_Image_Order);
               begin
                  if Object = null then
                     Release_Local;
                     return False;
                  end if;
                  Terminal.App.Image_Store.Adopt_Indexed_Data
                    (Container  => R.Image_Objects,
                     Object     => Object,
                     Format     => Raw_Format,
                     Row_Stride => Data.Decoded_Row_Stride_Bytes,
                     Data       => Indexed_Bytes);
                  Indexed_Bytes_Owned := False;
               end;
            end if;
         end if;
      end;
   end if;

   if Header.Kitty_ID = 0
     and then Header.Kitty_Compression = ASCII.NUL
     and then Raw_Format not in 8 | 16
     and then not Borrowed_From_Object
   then
      Encoded_Source :=
        Terminal.App.Image_Ingestion.Copy_Text
          (Image_Text (First_Data .. Image_Text'Last),
           R.Image_Allocation_Control);
      Encoded_Source_Owned := Encoded_Source /= null;
      if Encoded_Source = null then
         R.Image_Store_Allocation_Failed := True;
         Release_Local;
         return False;
      end if;
   end if;

   if Image_View = null then
      Image_View := RM.Read_Only (Image_Bytes);
   end if;
   Prepare_Image_Preview_Source
     (Image_View, Preview_Length, Preview_Bytes,
      Preview_View, Preview_Owner);
   declare
      Geometry : constant Placement_Geometry :=
        Resolve_Placement_Geometry
          (R, Header.Pixel_Width, Header.Pixel_Height, Header);
      Available_Width : constant Natural :=
        (if Header.Kitty_Source_X < Header.Pixel_Width
         then Header.Pixel_Width - Header.Kitty_Source_X
         else 0);
      Available_Height : constant Natural :=
        (if Header.Kitty_Source_Y < Header.Pixel_Height
         then Header.Pixel_Height - Header.Kitty_Source_Y
         else 0);
      Source_Width : constant Natural :=
        (if Header.Kitty_Source_Width = 0
         then Available_Width
         else Natural'Min
           (Header.Kitty_Source_Width, Available_Width));
      Source_Height : constant Natural :=
        (if Header.Kitty_Source_Height = 0
         then Available_Height
         else Natural'Min
           (Header.Kitty_Source_Height, Available_Height));
      Source_Kind : constant RM.Image_Decoded_Source_Kind :=
        (if Header.Kitty_ID = 0
           and then Header.Kitty_Compression = ASCII.NUL
           and then Raw_Format not in 8 | 16
           and then not Borrowed_From_Object
         then RM.Image_Decoded_Source_Raw_Base64
         else RM.Image_Decoded_Source_Buffer);
   begin
      if Header.Kitty_Action = 'T' and then not Geometry.Valid then
         Release_Local;
         return False;
      end if;
      if Store_Decoded then
         Copy_Image_Preview
           (Image_Bytes, Render_Length, Preview_Length, Preview_Bytes);
      end if;

      declare
         Decoded_Owner : RM.Image_Data_Access :=
           (if Image_Bytes_Owned and then not Borrowed_From_Object
            then Image_Bytes else null);
         Encoded_Owner : RM.Image_Data_Access :=
           (if Encoded_Source_Owned then Encoded_Source else null);
      begin
         Append_Image_Command
           (R,
           (X              => X
           + Float (Header.Kitty_Cell_X + Geometry.Draw_Offset_X),
         Y              => Y
           + Float (Header.Kitty_Cell_Y + Geometry.Draw_Offset_Y),
         Width          =>
           (if Geometry.Valid
            then Float (Geometry.Draw_Width)
            else Float (R.CW * Header.Placeholder_Cols)),
         Height         =>
           (if Geometry.Valid
            then Float (Geometry.Draw_Height)
            else Float (R.CH * Header.Placeholder_Rows)),
         Protocol       => RM.Image_Kitty,
         Placeholder    => False,
         Raw_Format     => Render_Format,
         Pixel_Width    => Header.Pixel_Width,
         Pixel_Height   => Header.Pixel_Height,
         Payload_Length => Item.Payload_Length,
         Staging_Byte_Length => 0,
         Payload_Preview_Complete => True,
         Encoded_Preview_Length => Encoded_Length,
         Decoded_Byte_Length => Render_Length,
         Decoded_Row_Stride_Bytes =>
           Render_Stride,
         Decoded_Source => Source_Kind,
         Decoded_Bytes => Image_View,
         Encoded_Source_Bytes => RM.Read_Only (Encoded_Source),
         Encoded_Source_Length => Encoded_Length,
         Decoded_Preview_Length => Preview_Length,
         Decoded_Preview_Bytes => Preview_View,
         Preview_Decode_Complete => True,
         Decode_Status =>
           Terminal.App.Graphics.Image_Decode_Status
             (Data.Decode_Status),
         U0             => Float (Header.Kitty_Source_X)
           / Float (Header.Pixel_Width),
         V0             => Float (Header.Kitty_Source_Y)
           / Float (Header.Pixel_Height),
         U1             => Float (Header.Kitty_Source_X + Source_Width)
           / Float (Header.Pixel_Width),
         V1             => Float (Header.Kitty_Source_Y + Source_Height)
           / Float (Header.Pixel_Height),
         Image_ID       => Interfaces.Unsigned_32 (Header.Kitty_ID),
         Content_Serial =>
           (if R.Last_Stored_Image_Content_Serial /= 0
            then R.Last_Stored_Image_Content_Serial
            else Interfaces.Unsigned_64 (Item.Sequence)),
         Z_Index        => Header.Kitty_Z_Index,
            Tint           => Graphics_Tint (Terminal.Core.Kitty_Graphics)),
            Decoded_Owner, Encoded_Owner, Preview_Owner);
         if Image_Bytes_Owned and then not Borrowed_From_Object then
            Image_Bytes := null;
         end if;
         if Encoded_Source_Owned then
            Encoded_Source := null;
         end if;
      end;
   end;
   Image_Bytes_Owned := False;
   Encoded_Source_Owned := False;
   Install.Storage_Order := 0;
   if Indexed_Bytes /= null and then Indexed_Bytes_Owned then
      Free_Image_Data (Indexed_Bytes);
      Indexed_Bytes := null;
      Indexed_Bytes_Owned := False;
   end if;
   return True;
exception
   when Storage_Error =>
      Release_Local;
      return False;
   when others =>
      Release_Local;
      raise;
end Emit_Raw_Kitty;
