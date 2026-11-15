with Terminal.App.Graphics.Decoding;

package body Terminal.App.Renderer.Animation_Frame_Decoding is
   procedure Decode
     (Header                            : Terminal.App.Graphics.Graphics_Header;
      Text                              : String;
      Per_Image_Bytes                   : Positive;
      Pixel_Dimension                   : Positive;
      Allow_Unknown_Compressed_PNG_Size : Boolean;
      Output                            : in out Result)
   is
      Bytes : Terminal.App.Owned_Image_Data.Owner;

      function Data_Start return Natural is
      begin
         for I in Text'Range loop
            if Text (I) = ';' then
               return (if I < Text'Last then I + 1 else 0);
            end if;
         end loop;
         return 0;
      end Data_Start;

      function One_Chunk (Index : Positive) return String is
         First : constant Natural := Data_Start;
      begin
         if Index /= 1 or else First = 0 then
            return "";
         end if;
         return Text (First .. Text'Last);
      end One_Chunk;

      procedure Capture_Row
        (Y        : Natural;
         Row      : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean)
      is
         Required : Natural;
         Offset   : Natural;
      begin
         if Output.Data.Pixel_Height = 0
           or else Row'Length = 0
           or else Output.Data.Pixel_Height > Natural'Last / Row'Length
         then
            Continue := False;
            Output.Copy_Failed := True;
            return;
         end if;
         Required := Output.Data.Pixel_Height * Row'Length;
         if Required > Per_Image_Bytes
           or else Output.Data.Pixel_Width > Pixel_Dimension
           or else Output.Data.Pixel_Height > Pixel_Dimension
           or else Y >= Output.Data.Pixel_Height
         then
            Continue := False;
            Output.Copy_Failed := True;
            Output.Quota_Failed := True;
            return;
         end if;
         if Terminal.App.Owned_Image_Data.Is_Empty (Bytes) then
            Terminal.App.Owned_Image_Data.Allocate (Bytes, Required);
            Terminal.App.Owned_Image_Data.Fill (Bytes, 0);
         elsif Terminal.App.Owned_Image_Data.Length (Bytes) /= Required then
            Continue := False;
            Output.Copy_Failed := True;
            return;
         end if;
         Offset := Y * Row'Length + 1;
         declare
            procedure Copy_Row
              (Target : in out Terminal.Common.Bytes.Byte_Array) is
            begin
               Target (Offset .. Offset + Row'Length - 1) := Row;
            end Copy_Row;
         begin
            Terminal.App.Owned_Image_Data.Modify (Bytes, Copy_Row'Access);
         end;
         Continue := True;
      exception
         when Storage_Error =>
            Continue := False;
            Output.Copy_Failed := True;
            Output.Allocation_Failed := True;
      end Capture_Row;
   begin
      Terminal.App.Graphics.Release (Output.Data);
      declare
         Metadata : Terminal.App.Graphics.Graphics_Data_Preview :=
           Terminal.App.Graphics.Metadata_Preview
             (Header_Recognized => Header.Recognized,
              Has_Data          => Header.Has_Data,
              Raw_Format        => Header.Raw_Format,
              Pixel_Width       => Header.Pixel_Width,
              Pixel_Height      => Header.Pixel_Height);
      begin
         Terminal.App.Graphics.Move (Metadata, Output.Data);
      end;
      Output.Copy_Failed := False;
      Output.Quota_Failed := False;
      Output.Allocation_Failed := False;

      if Header.Kitty_Format in 8 | 16 | 24 | 32 then
         if Header.Kitty_Compression = 'z' then
            Terminal.App.Graphics.Decoding.Decode_Base64_Zlib_Raw_Chunk_Rows
              (1, One_Chunk'Access, Header.Kitty_Format,
               Header.Pixel_Width, Header.Pixel_Height,
               Capture_Row'Access, Output.Data);
         else
            Terminal.App.Graphics.Decoding.Decode_Base64_Raw_Chunk_Rows
              (1, One_Chunk'Access, Header.Kitty_Format,
               Header.Pixel_Width, Header.Pixel_Height,
               Capture_Row'Access, Output.Data);
         end if;
      elsif Header.Kitty_Format = 100 then
         if Header.Kitty_Compression = 'z'
           and then
             (Header.Kitty_Data_Size > 0
              or else Allow_Unknown_Compressed_PNG_Size)
         then
            declare
               Encoded_Length : Natural;
            begin
               Terminal.App.Graphics.Decoding.Decode_Base64_Zlib_PNG_Chunk_Rows
                 (1, One_Chunk'Access, Header.Kitty_Data_Size,
                  Encoded_Length, Capture_Row'Access, Output.Data);
            end;
         elsif Header.Kitty_Compression = ASCII.NUL then
            declare
               Encoded_Length : Natural;
               PNG_Length     : Natural;
            begin
               Terminal.App.Graphics.Decoding.Decode_Base64_PNG_Chunk_Rows
                 (1, One_Chunk'Access, Encoded_Length, PNG_Length,
                  Capture_Row'Access, Output.Data);
            end;
         end if;
      end if;
      if Terminal.App.Graphics.Has_Bytes (Output.Data) then
         Terminal.App.Graphics.Release (Output.Data);
      end if;
      Terminal.App.Graphics.Adopt_Bytes (Output.Data, Bytes);
   end Decode;
end Terminal.App.Renderer.Animation_Frame_Decoding;
