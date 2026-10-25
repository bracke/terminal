separate (Terminal.App.Graphics)
   procedure Decode_Base64_Raw_Rows
     (Text         : String;
      Raw_Format   : Natural;
      Pixel_Width  : Natural;
      Pixel_Height : Natural;
      Row_Sink     : not null access procedure
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result       : in out Graphics_Data_Preview)
   is
      function Single_Chunk (Index : Positive) return String is
      begin
         if Index = 1 then
            return Text;
         else
            return "";
         end if;
      end Single_Chunk;
   begin
      Decode_Base64_Raw_Chunk_Rows
        (1,
         Single_Chunk'Access,
         Raw_Format,
         Pixel_Width,
         Pixel_Height,
         Row_Sink,
         Result);
   end Decode_Base64_Raw_Rows;

