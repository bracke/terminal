with Terminal.App.Graphics.Decoding;

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
     Float (Origin_X (R) + (Item.Col - 1) * R.Text_State.CW);
   Y : constant Float :=
     Float (Origin_Y (R) + (Item.Row - 1) * R.Text_State.CH);
   Encoded_Length : Natural := 0;
   PNG_Length : Natural := 0;
   Data : Terminal.App.Graphics.Graphics_Data_Preview :=
     Terminal.App.Graphics.Metadata_Preview
       (Header_Recognized => Header.Recognized,
        Has_Data          => Header.Has_Data,
        Raw_Format        => 0,
        Pixel_Width       => 0,
        Pixel_Height      => 0);
   Image_Owner : Terminal.App.Owned_Image_Data.Owner;
   Preview_View : RM.Image_Data_View := null;
   Preview_Owner : Terminal.App.Owned_Image_Data.Owner;
   Media : Terminal.App.Image_Media.Decoded_Image;
   Media_Used : Boolean := False;
   Encoded_Owner : Terminal.App.Owned_Image_Data.Owner;
   Borrowed_Object : Image_Object_Access := null;
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

   procedure Copy_First_Media_Frame
     (Target : in out Terminal.Common.Bytes.Byte_Array) is
   begin
      Media.Copy_Frame (1, Target);
   end Copy_First_Media_Frame;

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
      Terminal.App.Owned_Image_Data.Release (Image_Owner);
      Terminal.App.Owned_Image_Data.Release (Encoded_Owner);
      Terminal.App.Owned_Image_Data.Release (Preview_Owner);
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
   end Capture_PNG_Row;

   procedure Decode_ITerm2 is separate;
   function Append_Decoded_Command return Boolean is separate;
begin
   if not Header.Recognized
     or else not Header.Has_Data
     or else FIS.Is_Full (R.Frame_State.Frame_Images)
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
      Decode_ITerm2;
   elsif Header.Kitty_Compression = 'z' then
      Terminal.App.Graphics.Decoding.Decode_Base64_Zlib_PNG_Chunk_Rows
        (1,
         PNG_Text'Access,
         Header.Kitty_Data_Size,
         Encoded_Length,
         Capture_PNG_Row'Access,
         Data);
      PNG_Length := Header.Kitty_Data_Size;
   else
      Terminal.App.Graphics.Decoding.Decode_Base64_PNG_Chunk_Rows
        (1,
         PNG_Text'Access,
         Encoded_Length,
         PNG_Length,
         Capture_PNG_Row'Access,
         Data);
   end if;

   if Item.Protocol = Terminal.Core.ITerm2_Graphics
     and then not R.Graphics_State.Telemetry.Last_Media.Attempted
   then
      Terminal.App.Image_Rendering.Set_Status
        (R.Graphics_State.Telemetry.Last_Media, Data.Decode_Status);
   end if;

   if Row_Copy_Failed
     or else not Data.Decode_Complete
     or else Data.Decoded_Length = 0
     or else Data.Decoded_Row_Stride_Bytes = 0
     or else
       (Item.Protocol = Terminal.Core.ITerm2_Graphics
        and then not Image_Buffers.Ready (Data, Image_Owner))
     or else
       (Store_Decoded and then not Image_Buffers.Ready (Data, Image_Owner))
   then
      if Data.Decode_Status =
        Terminal.App.Graphics.Decode_Allocation_Failed
      then
         R.Graphics_State.Transaction.Image_Store_Allocation_Failed := True;
      end if;
      Release_Local;
      return Emit_Rejected;
   end if;

   --  Validate every fallible or rejectable input property before the
   --  decoded image is installed.  Replacement of an explicit Kitty ID
   --  is destructive, so there must be no rejection path after it.
   if Item.Protocol = Terminal.Core.Kitty_Graphics
     and then Header.Kitty_Action = 'T'
     and then not Placements_State.Resolve_Placement_Geometry
       (R, Data.Pixel_Width, Data.Pixel_Height, Header).Valid
   then
      Release_Local;
      return Emit_Rejected;
   end if;

   if Item.Protocol = Terminal.Core.ITerm2_Graphics then
      Terminal.App.Image_Ingestion.Copy_Text
        (Image_Text (From .. Image_Text'Last),
         R.Graphics_State.Resources.Allocation_Control,
         Encoded_Owner);
      if Terminal.App.Owned_Image_Data.Is_Empty (Encoded_Owner) then
         R.Graphics_State.Transaction.Image_Store_Allocation_Failed := True;
         Terminal.App.Image_Rendering.Set_Status
           (R.Graphics_State.Telemetry.Last_Media,
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
         Stored_Object : Image_Object_Access;
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
            Bytes          => Image_Owner,
            Stored_Object  => Stored_Object);
         if Stored_Object /= null then
            Arm (Install, R.Graphics_State.Transaction.Last_Stored_Image_Order);
            Borrowed_Object := Stored_Object;
         end if;
      end;
   elsif Item.Protocol = Terminal.Core.ITerm2_Graphics then
      declare
         Stored_Object : Image_Object_Access := null;
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
            Bytes          => Image_Owner,
            Stored_Object  => Stored_Object,
            Additional_Bytes =>
              (if Media_Used
               then Media.Total_Bytes - Media.Frame_Bytes
               else 0));
         if Stored_Object = null then
            Release_Local;
            return Emit_Rejected;
         end if;
         Arm (Install, R.Graphics_State.Transaction.Last_Stored_Image_Order);
         Borrowed_Object := Stored_Object;
         if Media_Used and then Media.Frame_Count > 1 then
            declare
               Object : constant Image_Object_Access :=
                 Image_Objects.Find_By_Storage_Order
                   (R, Item.Stream_ID, R.Graphics_State.Transaction.Last_Stored_Image_Order);
               Adopted : Boolean := False;
            begin
               if Object = null then
                  Release_Local;
                  return Emit_Rejected;
               end if;
               declare
                  State : Terminal.App.Image_Store.Playback_State.State :=
                    Terminal.App.Image_Store.Playback_State.Value (Object.all);
               begin
                  State.Root_Gap_MS := Integer (Media.Delay_MS (1));
                  State.Mode :=
                    (if Media.Loop_Count = 0
                     then Animation_Loading
                     else Animation_Running);
                  State.Loop_Count :=
                    (if Media.Loop_Count = 0
                     then 1
                     else Positive'Max
                       (1,
                        Positive'Min
                          (Positive'Last, Media.Loop_Count)));
                  State.Loops_Completed := 0;
                  State.Deadline_Set := False;
                  Terminal.App.Image_Store.Playback_State.Replace
                    (Object, State);
               end;
               Terminal.App.Image_Animation.Adopt_Decoded_Frames
                 (R.Graphics_State.Resources.Image_Objects,
                  Object,
                  Media,
                  R.Graphics_State.Resources.Allocation_Control,
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
        and then Borrowed_Object = null)
   then
      Terminal.App.Image_Ingestion.Copy_Text
        (Image_Text (From .. Image_Text'Last),
         R.Graphics_State.Resources.Allocation_Control,
         Encoded_Owner);
      if Terminal.App.Owned_Image_Data.Is_Empty (Encoded_Owner) then
         R.Graphics_State.Transaction.Image_Store_Allocation_Failed := True;
         Release_Local;
         return Emit_Rejected;
      end if;

      if PNG_Length = 0 and then Data.Decode_Complete then
         PNG_Length := Data.Decoded_Length;
      end if;
   end if;

   if not Append_Decoded_Command then
      Release_Local;
      return Emit_Rejected;
   end if;
   Commit (Install);

   Terminal.App.Owned_Image_Data.Release (Image_Owner);
   Terminal.App.Owned_Image_Data.Release (Encoded_Owner);
   Terminal.App.Owned_Image_Data.Release (Preview_Owner);
   Terminal.App.Image_Media.Release (Media);
   Terminal.App.Graphics.Release (Data);
   return Emit_Succeeded;
exception
   when Storage_Error =>
      R.Graphics_State.Transaction.Image_Store_Allocation_Failed := True;
      if Item.Protocol = Terminal.Core.ITerm2_Graphics then
         Terminal.App.Image_Rendering.Set_Status
           (R.Graphics_State.Telemetry.Last_Media,
            Terminal.App.Image_Media.Decode_Allocation_Failed);
      end if;
      Release_Local;
      return Emit_Rejected;
   when others =>
      Release_Local;
      raise;
end Emit_PNG_Rows;
