separate (Terminal.App.Renderer.Add_Image_Event)
function Emit_Local_Kitty
  (Item       : Terminal.Core.Graphics_Event;
   Header     : Terminal.App.Graphics.Graphics_Header;
   Image_Text : String) return Boolean
is
   Data_First : constant Natural :=
     Terminal.App.Image_Ingestion.Payload_Start
       (Terminal.App.Image_Ingestion.Kitty, Image_Text);
   Loaded : Terminal.App.Graphics_Transport.Byte_Array_Access := null;
   Loaded_Length : Natural := 0;
   Load_Status : Terminal.App.Graphics_Transport.Load_Status;
begin
   if Header.Kitty_Transmission not in 'f' | 't' | 's'
     or else Data_First = 0
     or else not Header.Kitty_Data_Size_Valid
     or else not Header.Kitty_Data_Offset_Valid
     or else Header.Kitty_More_Specified
   then
      R.Image_Transport_Failed := True;
      return False;
   end if;

   Terminal.App.Graphics_Transport.Load
     (Medium           => Header.Kitty_Transmission,
      Encoded_Location => Image_Text (Data_First .. Image_Text'Last),
      Offset           => Header.Kitty_Data_Offset,
      Size             => Header.Kitty_Data_Size,
      Size_Specified   => Header.Kitty_Data_Size_Specified,
      Policy           => R.Graphics_Access,
      Maximum_Bytes    => R.Graphics_Limits.Per_Image_Bytes,
      Bytes            => Loaded,
      Length           => Loaded_Length,
      Status           => Load_Status);
   if Load_Status /= Terminal.App.Graphics_Transport.Load_Ok then
      R.Image_Transport_Failed := True;
      if Load_Status in
        Terminal.App.Graphics_Transport.Load_Too_Large
        | Terminal.App.Graphics_Transport.Load_Allocation_Failed
      then
         R.Image_Store_Allocation_Failed := True;
      end if;
      return False;
   end if;

   declare
      Encoded : constant String :=
        Terminal.App.Image_Ingestion.Encode_Base64
          (Loaded, Loaded_Length);
      Synthetic : constant String :=
        Image_Text (Image_Text'First .. Data_First - 1) & Encoded;
      Synthetic_Event : Terminal.Core.Graphics_Event := Item;
      Synthetic_Header : Terminal.App.Graphics.Graphics_Header := Header;
      Emitted : Boolean := False;
   begin
      Terminal.App.Graphics_Transport.Release (Loaded);
      Synthetic_Event.Payload_Length := Synthetic'Length;
      Synthetic_Header.Kitty_Transmission := 'd';
      Synthetic_Header.Kitty_Transmission_Specified := True;
      if Synthetic_Header.Kitty_Format = 100
        and then Synthetic_Header.Kitty_Compression = 'z'
      then
         --  S selected the compressed byte range in the local object;
         --  it does not describe the inflated PNG stream.
         Synthetic_Header.Kitty_Data_Size := 0;
         Synthetic_Header.Kitty_Data_Size_Specified := False;
      end if;
      if Synthetic_Header.Kitty_Action = 'f' then
         Apply_Animation_Frame
           (R,
            Synthetic_Event,
            Synthetic_Header,
            Synthetic,
            Allow_Unknown_Compressed_PNG_Size => True);
         Emitted := R.Last_Animation_Result = Terminal.Core.Kitty_OK;
      elsif Synthetic_Header.Kitty_Format in 8 | 16 | 24 | 32 then
         Emitted :=
           Emit_Raw_Kitty (Synthetic_Event, Synthetic_Header, Synthetic);
      elsif Synthetic_Header.Kitty_Format = 100 then
         Emitted :=
           Emit_PNG_Rows
             (Synthetic_Event,
              Synthetic_Header,
              Synthetic,
              Allow_Unknown_Compressed_Size => True) = Emit_Succeeded;
      end if;
      return Emitted;
   end;
exception
   when Storage_Error =>
      Terminal.App.Graphics_Transport.Release (Loaded);
      R.Image_Store_Allocation_Failed := True;
      return False;
   when others =>
      Terminal.App.Graphics_Transport.Release (Loaded);
      raise;
end Emit_Local_Kitty;
