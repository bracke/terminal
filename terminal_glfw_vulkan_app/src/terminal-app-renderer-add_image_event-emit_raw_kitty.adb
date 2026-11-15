with Terminal.App.Graphics.Decoding;

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
        Image_Buffers.Extent
          (Raw_Format,
           Header.Pixel_Width,
           Header.Pixel_Height,
           Row_Stride);
   First_Data : constant Natural :=
     Terminal.App.Image_Ingestion.Payload_Start
       (Terminal.App.Image_Ingestion.Kitty, Image_Text);
   X : constant Float :=
     Float (Origin_X (R) + (Item.Col - 1) * R.Text_State.CW);
   Y : constant Float :=
     Float (Origin_Y (R) + (Item.Row - 1) * R.Text_State.CH);
   Encoded_Length : Natural := 0;
   Data : Terminal.App.Graphics.Graphics_Data_Preview;
   Image_Owner : Terminal.App.Owned_Image_Data.Owner;
   Preview_View : RM.Image_Data_View := null;
   Preview_Owner : Terminal.App.Owned_Image_Data.Owner;
   Indexed_Owner : Terminal.App.Owned_Image_Data.Owner;
   Render_Format : Natural := Raw_Format;
   Render_Length : Natural := Expected_Length;
   Render_Stride : Natural := Row_Stride;
   Encoded_Owner : Terminal.App.Owned_Image_Data.Owner;
   Borrowed_Object : Image_Object_Access := null;
   Install : Install_Guard (Item.Stream_ID);
   Store_Decoded : constant Boolean :=
     Header.Kitty_ID > 0
     or else Header.Kitty_Action = 'T'
     or else Header.Kitty_Compression = 'z'
     or else Raw_Format in 8 | 16;
   Row_Copy_Failed : Boolean := False;
   Preview_Length : Natural := 0;
   Preview_Bytes : Terminal.Common.Bytes.Byte_Array
     (1 .. RM.Max_Image_Decoded_Preview_Length) := (others => 0);
   Expansion_Succeeded : Boolean := False;

   procedure Expand_Indexed
     (Target : in out Terminal.Common.Bytes.Byte_Array) is
      procedure Expand_Source (Source : Terminal.Common.Bytes.Byte_Array) is
      begin
         Expansion_Succeeded := Style.Expand_Kitty_Indexed
           (R,
            Raw_Format,
            Header.Pixel_Width,
            Header.Pixel_Height,
            Source,
            Target);
      end Expand_Source;
   begin
      Terminal.App.Owned_Image_Data.Read
        (Indexed_Owner, Expand_Source'Access);
   end Expand_Indexed;

   procedure Capture_Raw_Row
     (Row_Y : Natural;
      Row : Terminal.Common.Bytes.Byte_Array;
      Continue : in out Boolean)
   is
   begin
      if Store_Decoded then
         Image_Buffers.Capture_Row
           (Data,
            Image_Owner,
            Row_Y,
            Row,
            R.Graphics_State.Policy.Limits.Per_Image_Bytes,
            R.Graphics_State.Policy.Limits.Pixel_Dimension,
            Continue);
      else
         Image_Buffers.Capture_Preview_Row
           (Preview_Length, Preview_Bytes, Row_Y, Row, Continue);
      end if;
      if not Continue then
         Row_Copy_Failed := True;
      end if;
   end Capture_Raw_Row;

   procedure Release_Local is
   begin
      Terminal.App.Graphics.Release (Data);
      Terminal.App.Owned_Image_Data.Release (Image_Owner);
      Terminal.App.Owned_Image_Data.Release (Indexed_Owner);
      Terminal.App.Owned_Image_Data.Release (Encoded_Owner);
      Terminal.App.Owned_Image_Data.Release (Preview_Owner);
      Rollback (Install);
   end Release_Local;

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

   procedure Copy_Display_Preview
     (Bytes : Terminal.Common.Bytes.Byte_Array) is
   begin
      Image_Buffers.Copy_Preview
        (Bytes, Render_Length, Preview_Length, Preview_Bytes);
   end Copy_Display_Preview;
begin
   if not Header.Recognized
     or else not Header.Has_Data
     or else Bytes_Per_Pixel = 0
     or else Header.Pixel_Width = 0
     or else Header.Pixel_Height = 0
     or else Expected_Length = 0
     or else Expected_Length > RM.Max_Image_Decoded_Data_Length
     or else First_Data = 0
     or else FIS.Is_Full (R.Frame_State.Frame_Images)
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
         Terminal.App.Graphics.Decoding.Decode_Base64_Zlib_Raw_Chunk_Rows
           (1,
            Single_Chunk'Access,
            Raw_Format,
            Header.Pixel_Width,
            Header.Pixel_Height,
            Capture_Raw_Row'Access,
            Data);
      end;
   else
      Terminal.App.Graphics.Decoding.Decode_Base64_Raw_Rows
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
              and then not Image_Buffers.Ready (Data, Image_Owner))
   then
      Release_Local;
      return False;
   end if;

   if Raw_Format in 8 | 16 then
      if Header.Pixel_Width > Natural'Last / Header.Pixel_Height
        or else Header.Pixel_Width * Header.Pixel_Height > Natural'Last / 4
        or else Header.Pixel_Width * Header.Pixel_Height * 4 >
          R.Graphics_State.Policy.Limits.Per_Image_Bytes
      then
         Release_Local;
         return False;
      end if;
      Terminal.App.Owned_Image_Data.Move (Image_Owner, Indexed_Owner);
      Terminal.App.Owned_Image_Data.Allocate
        (Image_Owner, Header.Pixel_Width * Header.Pixel_Height * 4);
      Terminal.App.Owned_Image_Data.Modify
        (Image_Owner, Expand_Indexed'Access);
      if not Expansion_Succeeded then
         Release_Local;
         return False;
      end if;
      Render_Format := 32;
      Render_Length := Header.Pixel_Width * Header.Pixel_Height * 4;
      Render_Stride := Header.Pixel_Width * 4;
   end if;

   if Header.Kitty_Action = 'T'
     and then not Placements_State.Resolve_Placement_Geometry
       (R, Header.Pixel_Width, Header.Pixel_Height, Header).Valid
   then
      Release_Local;
      return False;
   end if;

   if Header.Kitty_ID > 0 or else Header.Kitty_Action = 'T' then
      declare
         Stored_Object : Image_Object_Access;
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
            Bytes          => Image_Owner,
            Stored_Object  => Stored_Object,
            Additional_Bytes =>
              (if Raw_Format in 8 | 16 then Data.Decoded_Length else 0));
         if Stored_Object /= null then
            Arm (Install, R.Graphics_State.Transaction.Last_Stored_Image_Order);
            Borrowed_Object := Stored_Object;
            if Raw_Format in 8 | 16 then
               declare
                  Object : constant Image_Object_Access :=
                    Image_Objects.Find_By_Storage_Order
                      (R, Item.Stream_ID, R.Graphics_State.Transaction.Last_Stored_Image_Order);
               begin
                  if Object = null then
                     Release_Local;
                     return False;
                  end if;
                  Terminal.App.Image_Store.Adopt_Indexed_Data
                    (Container  => R.Graphics_State.Resources.Image_Objects,
                     Object     => Object,
                     Format     => Raw_Format,
                     Row_Stride => Data.Decoded_Row_Stride_Bytes,
                     Data       => Indexed_Owner);
               end;
            end if;
         end if;
      end;
   end if;

   if Header.Kitty_ID = 0
     and then Header.Kitty_Compression = ASCII.NUL
     and then Raw_Format not in 8 | 16
     and then Borrowed_Object = null
   then
      Terminal.App.Image_Ingestion.Copy_Compact_Base64
        (Image_Text (First_Data .. Image_Text'Last),
         R.Graphics_State.Resources.Allocation_Control,
         Encoded_Owner);
      if Terminal.App.Owned_Image_Data.Is_Empty (Encoded_Owner) then
         R.Graphics_State.Transaction.Image_Store_Allocation_Failed := True;
         Release_Local;
         return False;
      end if;
   end if;

   declare
      Geometry : constant Placement_Geometry :=
        Placements_State.Resolve_Placement_Geometry
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
           and then Borrowed_Object = null
         then RM.Image_Decoded_Source_Raw_Base64
         else RM.Image_Decoded_Source_Buffer);
   begin
      if Header.Kitty_Action = 'T' and then not Geometry.Valid then
         Release_Local;
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
              (Image_Owner, Render_Length, Preview_Length, Preview_Bytes);
         end if;
      end if;
      if Borrowed_Object = null then
         Image_Buffers.Prepare_Preview_Source
           (null, Preview_Length, Preview_Bytes,
            Preview_View, Preview_Owner);
      end if;

      Append_Prepared
        ((X              => X
           + Float (Header.Kitty_Cell_X + Geometry.Draw_Offset_X),
         Y              => Y
           + Float (Header.Kitty_Cell_Y + Geometry.Draw_Offset_Y),
         Width          =>
           (if Geometry.Valid
            then Float (Geometry.Draw_Width)
            else Float (R.Text_State.CW * Header.Placeholder_Cols)),
         Height         =>
           (if Geometry.Valid
            then Float (Geometry.Draw_Height)
            else Float (R.Text_State.CH * Header.Placeholder_Rows)),
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
         Decoded_Bytes => null,
         Encoded_Source_Bytes => null,
         Encoded_Source_Length => 0,
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
         Content_Serial => Command_Content_Serial,
         Z_Index        => Header.Kitty_Z_Index,
          Tint           => Style.Graphics_Tint (Terminal.Core.Kitty_Graphics)));
   end;
   Commit (Install);
   Terminal.App.Owned_Image_Data.Release (Image_Owner);
   Terminal.App.Owned_Image_Data.Release (Encoded_Owner);
   Terminal.App.Owned_Image_Data.Release (Preview_Owner);
   Terminal.App.Owned_Image_Data.Release (Indexed_Owner);
   return True;
exception
   when Storage_Error =>
      Release_Local;
      return False;
   when others =>
      Release_Local;
      raise;
end Emit_Raw_Kitty;
