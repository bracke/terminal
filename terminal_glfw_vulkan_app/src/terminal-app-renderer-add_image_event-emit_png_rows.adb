separate (Terminal.App.Renderer.Add_Image_Event)
function Emit_PNG_Rows
  (Item       : Terminal.Core.Graphics_Event;
   Header     : Terminal.App.Graphics.Graphics_Header;
   Image_Text : String;
   Allow_Unknown_Compressed_Size : Boolean := False)
    return Image_Emit_Result
is
   From : Natural := 0;
   X : constant Float :=
     Float (Origin_X (R) + (Item.Col - 1) * R.CW);
   Y : constant Float :=
     Float (Origin_Y (R) + (Item.Row - 1) * R.CH);
   Encoded_Length : Natural := 0;
   PNG_Length : Natural := 0;
   Data : Terminal.App.Graphics.Graphics_Data_Preview :=
     (Header_Recognized => Header.Recognized,
      Has_Data          => Header.Has_Data,
      Raw_Format        => 0,
      Pixel_Width       => 0,
      Pixel_Height      => 0,
      others            => <>);
   Image_Bytes : RM.Image_Data_Access := null;
   Image_View : RM.Image_Data_View := null;
   Preview_View : RM.Image_Data_View := null;
   Preview_Owner : RM.Image_Data_Access := null;
   Image_Bytes_Owned : Boolean := False;
   Media : Terminal.App.Image_Media.Decoded_Image;
   Media_Used : Boolean := False;
   Encoded_Source : RM.Image_Data_Access := null;
   Encoded_Source_Owned : Boolean := False;
   Borrowed_From_Object : Boolean := False;
   Install : Install_Guard (Item.Stream_ID);
   Store_Decoded : constant Boolean :=
     Item.Protocol = Terminal.Core.ITerm2_Graphics
     or else
       (Item.Protocol = Terminal.Core.Kitty_Graphics
        and then
          (Header.Kitty_ID > 0
           or else Header.Kitty_Action = 'T'
           or else Header.Kitty_Compression = 'z'));
   Row_Copy_Failed : Boolean := False;
   Preview_Length : Natural := 0;
   Preview_Bytes : Terminal.Common.Bytes.Byte_Array
     (1 .. RM.Max_Image_Decoded_Preview_Length) := (others => 0);

   function PNG_Text (Index : Positive) return String is
   begin
      if Index = 1 and then From /= 0 then
         return Image_Text (From .. Image_Text'Last);
      else
         return "";
      end if;
   end PNG_Text;

   procedure Release_Local is
   begin
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
      if Preview_Owner /= null then
         Free_Image_Data (Preview_Owner);
         Preview_Owner := null;
      end if;
      Terminal.App.Image_Media.Release (Media);
      Terminal.App.Graphics.Release (Data);
      Rollback (Install);
   end Release_Local;

   procedure Capture_PNG_Row
     (Row_Y : Natural;
      Row   : Terminal.Common.Bytes.Byte_Array;
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
   end Capture_PNG_Row;
begin
   if not Header.Recognized
     or else not Header.Has_Data
     or else FIS.Is_Full (R.Frame_Images)
     or else Item.Payload_Length = 0
     or else Image_Text'Length /= Item.Payload_Length
   then
      return Emit_Rejected;
   elsif Item.Protocol = Terminal.Core.Kitty_Graphics then
      if Header.Kitty_Format /= 100
        or else Header.Kitty_Compression not in ASCII.NUL | 'z'
        or else
          (Header.Kitty_Compression = 'z'
           and then Header.Kitty_Data_Size = 0
           and then not Allow_Unknown_Compressed_Size)
      then
         return Emit_Not_Applicable;
      end if;
      From := Terminal.App.Image_Ingestion.Payload_Start
        (Terminal.App.Image_Ingestion.Kitty, Image_Text);
   elsif Item.Protocol = Terminal.Core.ITerm2_Graphics then
      From := Terminal.App.Image_Ingestion.Payload_Start
        (Terminal.App.Image_Ingestion.ITerm2, Image_Text);
   else
      return Emit_Not_Applicable;
   end if;

   if From = 0 then
      return Emit_Rejected;
   end if;

   Encoded_Length := Image_Text'Last - From + 1;
   if Encoded_Length = 0 then
      return Emit_Rejected;
   end if;

   if Item.Protocol = Terminal.Core.ITerm2_Graphics then
      --  Attempt PNG through the bounded row decoder first.  JPEG uses
      --  a header-bounded decoder so neither format allocates its full
      --  decoded image before the configured limits are checked.
      Terminal.App.Graphics.Decode_Base64_PNG_Chunk_Rows
        (1,
         PNG_Text'Access,
         Encoded_Length,
         PNG_Length,
         Capture_PNG_Row'Access,
         Data);
      if Data.Decode_Status =
        Terminal.App.Graphics.Decode_Unsupported_Format
      then
         Terminal.App.Graphics.Release (Data);
         Data := Terminal.App.Graphics.JPEG_Data_Preview_Text
           (Image_Text,
            R.Graphics_Limits.Per_Image_Bytes,
            R.Graphics_Limits.Pixel_Dimension);
         if Data.Bytes /= null then
            Image_Bytes := Data.Bytes;
            Data.Bytes := null;
            Image_Bytes_Owned := True;
            Copy_Image_Preview
              (Image_Bytes,
               Data.Decoded_Length,
               Preview_Length,
               Preview_Bytes);
         end if;
      end if;
      if Data.Decode_Status =
          Terminal.App.Graphics.Decode_Unsupported_Format
        and then Terminal.App.Image_Media.Available
      then
         declare
            Blob : RM.Image_Data_Access := null;
            Blob_Length : Natural := 0;
            Base64_Status : Terminal.App.Graphics.Data_Decode_Status;
            Media_Status : Terminal.App.Image_Media.Decode_Status;
         begin
            Terminal.App.Graphics.Decode_Base64_Data
              (Image_Text (From .. Image_Text'Last),
               R.Graphics_Limits.Per_Image_Bytes,
               Blob,
               Blob_Length,
               Base64_Status);
            if Base64_Status = Terminal.App.Graphics.Decode_Ok
              and then Blob /= null
            then
               Terminal.App.Image_Media.Decode
                 (Blob.all,
                  Blob_Length,
                  R.Graphics_Limits.Per_Image_Bytes,
                  R.Graphics_Limits.Pixel_Dimension,
                  Media,
                  Media_Status);
               Terminal.App.Image_Rendering.Capture
                 (R.Last_Media, Media, Media_Status);
               Free_Image_Data (Blob);
               Data.Decode_Status := Media_Status;
               if Media_Status = Terminal.App.Image_Media.Decode_Ok
                 and then Media.Bytes /= null
                 and then Media.Frame_Count > 0
                 and then
                   Terminal.App.Image_Rendering.
                     Animation_Capacity_Available
                       (Stored_Animation_Frame_Count (R),
                        Media.Frame_Count,
                        R.Graphics_Limits.Animation_Frames)
               then
                  Terminal.App.Graphics.Release (Data);
                  Data :=
                    (Header_Recognized => True,
                     Has_Data => True,
                     Encoded_Length => Encoded_Length,
                     Raw_Format => 32,
                     Pixel_Width => Media.Pixel_Width,
                     Pixel_Height => Media.Pixel_Height,
                     Decoded_Length => Media.Frame_Bytes,
                     Decoded_Row_Stride_Bytes => Media.Pixel_Width * 4,
                     Decode_Complete => True,
                     Decode_Status => Terminal.App.Graphics.Decode_Ok,
                     Bytes => null);
                  if Media.Frame_Count = 1 then
                     --  Static native media already has the exact buffer
                     --  layout the image store owns. Transfer it instead
                     --  of briefly retaining a second full RGBA copy.
                     Image_Bytes := Media.Bytes;
                     Media.Bytes := null;
                  else
                     Image_Bytes :=
                       new Terminal.Common.Bytes.Byte_Array
                         (1 .. Media.Frame_Bytes);
                     Image_Bytes.all :=
                       Media.Bytes
                         (Media.Bytes'First
                          .. Media.Bytes'First
                            + Media.Frame_Bytes - 1);
                  end if;
                  Image_Bytes_Owned := True;
                  Media_Used := True;
                  Copy_Image_Preview
                    (Image_Bytes,
                     Media.Frame_Bytes,
                     Preview_Length,
                     Preview_Bytes);
               elsif Media_Status =
                 Terminal.App.Image_Media.Decode_Ok
               then
                  if Media.Bytes = null
                    or else Media.Frame_Count = 0
                  then
                     Data.Decode_Status :=
                       Terminal.App.Graphics.Decode_Invalid_Data;
                     Terminal.App.Image_Rendering.Set_Status
                       (R.Last_Media,
                        Terminal.App.Image_Media.Decode_Invalid);
                  else
                     Data.Decode_Status :=
                       Terminal.App.Graphics.Decode_Too_Large;
                     Terminal.App.Image_Rendering.Set_Status
                       (R.Last_Media,
                        Terminal.App.Image_Media.Decode_Too_Large);
                  end if;
               end if;
            else
               Data.Decode_Status := Base64_Status;
               Data.Decode_Complete := False;
               if Blob /= null then
                  Free_Image_Data (Blob);
               end if;
            end if;
         end;
      end if;
   elsif Header.Kitty_Compression = 'z' then
      Terminal.App.Graphics.Decode_Base64_Zlib_PNG_Chunk_Rows
        (1,
         PNG_Text'Access,
         Header.Kitty_Data_Size,
         Encoded_Length,
         Capture_PNG_Row'Access,
         Data);
      PNG_Length := Header.Kitty_Data_Size;
   else
      Terminal.App.Graphics.Decode_Base64_PNG_Chunk_Rows
        (1,
         PNG_Text'Access,
         Encoded_Length,
         PNG_Length,
         Capture_PNG_Row'Access,
         Data);
   end if;

   if Item.Protocol = Terminal.Core.ITerm2_Graphics
     and then not R.Last_Media.Attempted
   then
      Terminal.App.Image_Rendering.Set_Status
        (R.Last_Media, Data.Decode_Status);
   end if;

   if Row_Copy_Failed
     or else not Data.Decode_Complete
     or else Data.Decoded_Length = 0
     or else Data.Decoded_Row_Stride_Bytes = 0
     or else
       (Item.Protocol = Terminal.Core.ITerm2_Graphics
        and then not Image_Buffer_Ready (Data, Image_Bytes))
     or else
       (Store_Decoded
        and then not Image_Buffer_Ready (Data, Image_Bytes))
   then
      if Data.Decode_Status =
        Terminal.App.Graphics.Decode_Allocation_Failed
      then
         R.Image_Store_Allocation_Failed := True;
      end if;
      Release_Local;
      return Emit_Rejected;
   end if;

   --  Validate every fallible or rejectable input property before the
   --  decoded image is installed.  Replacement of an explicit Kitty ID
   --  is destructive, so there must be no rejection path after it.
   if Item.Protocol = Terminal.Core.Kitty_Graphics
     and then Header.Kitty_Action = 'T'
     and then not Resolve_Placement_Geometry
       (R, Data.Pixel_Width, Data.Pixel_Height, Header).Valid
   then
      Release_Local;
      return Emit_Rejected;
   end if;

   if Item.Protocol = Terminal.Core.ITerm2_Graphics then
      Encoded_Source := Terminal.App.Image_Ingestion.Copy_Text
        (Image_Text (From .. Image_Text'Last),
         R.Image_Allocation_Control);
      Encoded_Source_Owned := Encoded_Source /= null;
      if Encoded_Source = null then
         R.Image_Store_Allocation_Failed := True;
         Terminal.App.Image_Rendering.Set_Status
           (R.Last_Media,
            Terminal.App.Image_Media.Decode_Allocation_Failed);
         Release_Local;
         return Emit_Rejected;
      end if;
      if PNG_Length = 0 and then Data.Decode_Complete then
         PNG_Length := Data.Decoded_Length;
      end if;
   end if;

   if Item.Protocol = Terminal.Core.Kitty_Graphics
     and then
       (Header.Kitty_ID > 0 or else Header.Kitty_Action = 'T')
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
            Protocol       => RM.Image_Kitty,
            Raw_Format     => Data.Raw_Format,
            Pixel_Width    => Data.Pixel_Width,
            Pixel_Height   => Data.Pixel_Height,
            Decoded_Length => Data.Decoded_Length,
            Decoded_Row_Stride_Bytes => Data.Decoded_Row_Stride_Bytes,
            Bytes          => Image_Bytes,
            Stored_Bytes   => Stored_Bytes);
         if Stored_Bytes /= null then
            Arm (Install, R.Last_Stored_Image_Order);
            Image_View := Stored_Bytes;
            Image_Bytes_Owned := False;
            Borrowed_From_Object := True;
         end if;
      end;
   elsif Item.Protocol = Terminal.Core.ITerm2_Graphics then
      declare
         Stored_Bytes : RM.Image_Data_View := null;
      begin
         Take_Image_Object
           (R              => R,
            Stream_ID      => Item.Stream_ID,
            ID             => 0,
            Image_Number   => 0,
            Usage_Hint     => 0,
            Protocol       => RM.Image_ITerm2,
            Raw_Format     => Data.Raw_Format,
            Pixel_Width    => Data.Pixel_Width,
            Pixel_Height   => Data.Pixel_Height,
            Decoded_Length => Data.Decoded_Length,
            Decoded_Row_Stride_Bytes =>
              Data.Decoded_Row_Stride_Bytes,
            Bytes          => Image_Bytes,
            Stored_Bytes   => Stored_Bytes,
            Additional_Bytes =>
              (if Media_Used
               then Media.Total_Bytes - Media.Frame_Bytes
               else 0));
         if Stored_Bytes = null then
            Release_Local;
            return Emit_Rejected;
         end if;
         Arm (Install, R.Last_Stored_Image_Order);
         Image_View := Stored_Bytes;
         Image_Bytes_Owned := False;
         Borrowed_From_Object := True;
         if Media_Used and then Media.Frame_Count > 1 then
            declare
               Object : constant Image_Object_Access :=
                 Find_Image_Object_By_Storage_Order
                   (R, Item.Stream_ID, R.Last_Stored_Image_Order);
               Adopted : Boolean := False;
            begin
               if Object = null then
                  Release_Local;
                  return Emit_Rejected;
               end if;
               Terminal.App.Image_Store.Set_Root_Gap
                 (Object, Integer (Media.Delays_MS (1)));
               Terminal.App.Image_Store.Set_Playback
                 (Object,
                  (if Media.Loop_Count = 0
                   then Animation_Loading
                   else Animation_Running));
               Terminal.App.Image_Store.Set_Loop_Count
                 (Object,
                  (if Media.Loop_Count = 0
                   then 1
                   else Positive'Max
                     (1,
                      Positive'Min
                        (Positive'Last, Media.Loop_Count))));
               Terminal.App.Image_Animation.Adopt_Decoded_Frames
                 (R.Image_Objects,
                  Object,
                  Media,
                  R.Image_Allocation_Control,
                  Adopted);
               if not Adopted then
                  Release_Local;
                  return Emit_Rejected;
               end if;
               Touch_Image_Object (R, Object);
            exception
               when Storage_Error =>
                  Release_Local;
                  return Emit_Rejected;
            end;
         end if;
      end;
   end if;

   if Item.Protocol = Terminal.Core.Kitty_Graphics
     and then
       (Header.Kitty_ID = 0
        and then Header.Kitty_Compression = ASCII.NUL
        and then not Borrowed_From_Object)
   then
      Encoded_Source := Terminal.App.Image_Ingestion.Copy_Text
        (Image_Text (From .. Image_Text'Last),
         R.Image_Allocation_Control);
      Encoded_Source_Owned := Encoded_Source /= null;
      if Encoded_Source = null then
         R.Image_Store_Allocation_Failed := True;
         Release_Local;
         return Emit_Rejected;
      end if;

      if PNG_Length = 0 and then Data.Decode_Complete then
         PNG_Length := Data.Decoded_Length;
      end if;
   end if;

   if Image_View = null then
      Image_View := RM.Read_Only (Image_Bytes);
   end if;
   declare
      Geometry : constant Placement_Geometry :=
        (if Item.Protocol = Terminal.Core.Kitty_Graphics
         then Resolve_Placement_Geometry
           (R, Data.Pixel_Width, Data.Pixel_Height, Header)
         else (others => <>));
      Available_Width : constant Natural :=
        (if Header.Kitty_Source_X < Data.Pixel_Width
         then Data.Pixel_Width - Header.Kitty_Source_X
         else 0);
      Available_Height : constant Natural :=
        (if Header.Kitty_Source_Y < Data.Pixel_Height
         then Data.Pixel_Height - Header.Kitty_Source_Y
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
        (if Item.Protocol = Terminal.Core.ITerm2_Graphics
         then RM.Image_Decoded_Source_Buffer
         elsif Item.Protocol = Terminal.Core.Kitty_Graphics
           and then
             (Header.Kitty_ID > 0
              or else Borrowed_From_Object
              or else Header.Kitty_Compression = 'z')
         then RM.Image_Decoded_Source_Buffer
         else RM.Image_Decoded_Source_PNG_Base64);
      ITerm2_Size : constant Terminal.App.Image_Ingestion.Pixel_Size :=
        Terminal.App.Image_Ingestion.ITerm2_Render_Size
          (Header,
           Positive (Data.Pixel_Width),
           Positive (Data.Pixel_Height),
           R.CW,
           R.CH,
           (if R.Last_Frame_Width > Content_Margin * 2
            then R.Last_Frame_Width - Content_Margin * 2
            else R.CW),
           (if R.Last_Frame_Height > Content_Margin * 2
            then R.Last_Frame_Height - Content_Margin * 2
            else R.CH));
      ITerm2_Draw_Width : constant Float := ITerm2_Size.Width;
      ITerm2_Draw_Height : constant Float := ITerm2_Size.Height;
   begin
      if Item.Protocol = Terminal.Core.Kitty_Graphics
        and then Header.Kitty_Action = 'T'
        and then not Geometry.Valid
      then
         Release_Local;
         return Emit_Rejected;
      end if;
      if Store_Decoded then
         Copy_Image_Preview
           (Image_View, Data.Decoded_Length, Preview_Length, Preview_Bytes);
      end if;
      Prepare_Image_Preview_Source
        (Image_View, Preview_Length, Preview_Bytes,
         Preview_View, Preview_Owner);

      if Item.Protocol = Terminal.Core.ITerm2_Graphics
        and then not Store_Auxiliary_Placement
          (R,
           Item,
           RM.Image_ITerm2,
           Positive (Float'Ceiling (ITerm2_Draw_Width)),
           Positive (Float'Ceiling (ITerm2_Draw_Height)))
      then
         Release_Local;
         return Emit_Rejected;
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
           + (if Geometry.Valid
              then Float
                (Header.Kitty_Cell_X + Geometry.Draw_Offset_X)
              else 0.0),
         Y              => Y
           + (if Geometry.Valid
              then Float
                (Header.Kitty_Cell_Y + Geometry.Draw_Offset_Y)
              else 0.0),
         Width          =>
           (if Geometry.Valid
            then Float (Geometry.Draw_Width)
            elsif Item.Protocol = Terminal.Core.ITerm2_Graphics
            then ITerm2_Draw_Width
            else Float (R.CW * Header.Placeholder_Cols)),
         Height         =>
           (if Geometry.Valid
            then Float (Geometry.Draw_Height)
            elsif Item.Protocol = Terminal.Core.ITerm2_Graphics
            then ITerm2_Draw_Height
            else Float (R.CH * Header.Placeholder_Rows)),
         Protocol       => Graphics_Protocol (Item.Protocol),
         Placeholder    => False,
         Raw_Format     => Data.Raw_Format,
         Pixel_Width    => Data.Pixel_Width,
         Pixel_Height   => Data.Pixel_Height,
         Payload_Length => Item.Payload_Length,
         Staging_Byte_Length => PNG_Length,
         Payload_Preview_Complete => True,
         Encoded_Preview_Length => Encoded_Length,
         Decoded_Byte_Length => Data.Decoded_Length,
         Decoded_Row_Stride_Bytes => Data.Decoded_Row_Stride_Bytes,
         Decoded_Source => Source_Kind,
         Decoded_Bytes => Image_View,
         Encoded_Source_Bytes => RM.Read_Only (Encoded_Source),
         Encoded_Source_Length => Encoded_Length,
         Decoded_Preview_Length => Preview_Length,
         Decoded_Preview_Bytes => Preview_View,
         Preview_Decode_Complete => True,
         Decode_Status => RM.Image_Decode_Ok,
         U0             =>
           (if Item.Protocol = Terminal.Core.Kitty_Graphics
            then Float (Header.Kitty_Source_X)
              / Float (Data.Pixel_Width)
            else 0.0),
         V0             =>
           (if Item.Protocol = Terminal.Core.Kitty_Graphics
            then Float (Header.Kitty_Source_Y)
              / Float (Data.Pixel_Height)
            else 0.0),
         U1             =>
           (if Item.Protocol = Terminal.Core.Kitty_Graphics
            then Float (Header.Kitty_Source_X + Source_Width)
              / Float (Data.Pixel_Width)
            else 1.0),
         V1             =>
           (if Item.Protocol = Terminal.Core.Kitty_Graphics
            then Float (Header.Kitty_Source_Y + Source_Height)
              / Float (Data.Pixel_Height)
            else 1.0),
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
   Commit (Install);

   Terminal.App.Image_Media.Release (Media);
   Terminal.App.Graphics.Release (Data);
   return Emit_Succeeded;
exception
   when Storage_Error =>
      R.Image_Store_Allocation_Failed := True;
      if Item.Protocol = Terminal.Core.ITerm2_Graphics then
         Terminal.App.Image_Rendering.Set_Status
           (R.Last_Media,
            Terminal.App.Image_Media.Decode_Allocation_Failed);
      end if;
      Release_Local;
      return Emit_Rejected;
   when others =>
      Release_Local;
      raise;
end Emit_PNG_Rows;
