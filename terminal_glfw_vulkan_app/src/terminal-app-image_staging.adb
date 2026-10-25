with Terminal.App.Graphics;
with Terminal.Common.Bytes;

package body Terminal.App.Image_Staging is
   package RM renames Terminal.App.Render_Model;
   use type RM.Image_Data_Access;
   use type RM.Image_Data_View;
   use type RM.Image_Decoded_Source_Kind;
   use type Terminal.App.Graphics.Data_Decode_Status;

   procedure Decode_Encoded_Rows
     (Source : RM.Image_Command;
      Write  : not null access procedure
        (Y        : Natural;
         Row      : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Status : out Decode_Status)
   is
      Data : Terminal.App.Graphics.Graphics_Data_Preview :=
        (Header_Recognized => True,
         Has_Data          => True,
         Raw_Format        => Source.Raw_Format,
         Pixel_Width       => Source.Pixel_Width,
         Pixel_Height      => Source.Pixel_Height,
         others            => <>);
      Decoded_Encoded_Length : Natural := 0;
      PNG_Length : Natural := 0;
      Rows_Seen : Natural := 0;
      Sink_Failed : Boolean := False;

      function Encoded_Text return String is
         Result : String (1 .. Source.Encoded_Source_Length);
      begin
         for I in Result'Range loop
            Result (I) := Character'Val (Source.Encoded_Source_Bytes (I));
         end loop;
         return Result;
      end Encoded_Text;

      procedure Capture_Row
        (Y        : Natural;
         Row      : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean) is
      begin
         Write (Y, Row, Continue);
         if Continue then
            Rows_Seen := Rows_Seen + 1;
         else
            Sink_Failed := True;
         end if;
      end Capture_Row;
   begin
      Status := Invalid_Source;
      if Source.Encoded_Source_Bytes = null
        or else Source.Encoded_Source_Length = 0
        or else Source.Encoded_Source_Length >
          Source.Encoded_Source_Bytes'Length
        or else Source.Pixel_Width = 0
        or else Source.Pixel_Height = 0
        or else Source.Raw_Format not in 24 | 32
        or else Source.Decoded_Source = RM.Image_Decoded_Source_Buffer
      then
         return;
      end if;

      declare
         Text : constant String := Encoded_Text;

         function Chunk_Text (Index : Positive) return String is
           (if Index = 1 then Text else "");
      begin
         case Source.Decoded_Source is
            when RM.Image_Decoded_Source_Raw_Base64 =>
               Terminal.App.Graphics.Decode_Base64_Raw_Rows
                 (Text,
                  Source.Raw_Format,
                  Source.Pixel_Width,
                  Source.Pixel_Height,
                  Capture_Row'Access,
                  Data);
            when RM.Image_Decoded_Source_PNG_Base64 =>
               Terminal.App.Graphics.Decode_Base64_PNG_Chunk_Rows
                 (1,
                  Chunk_Text'Access,
                  Decoded_Encoded_Length,
                  PNG_Length,
                  Capture_Row'Access,
                  Data);
            when RM.Image_Decoded_Source_Sixel_Text =>
               Terminal.App.Graphics.Decode_Sixel_Rows
                 (Text, Capture_Row'Access, Data);
            when others =>
               return;
         end case;
      end;

      if not Sink_Failed
        and then Rows_Seen = Source.Pixel_Height
        and then Data.Decode_Complete
        and then Data.Decode_Status = Terminal.App.Graphics.Decode_Ok
      then
         Status := Decode_Ok;
      end if;
      Terminal.App.Graphics.Release (Data);
   exception
      when Storage_Error =>
         Terminal.App.Graphics.Release (Data);
         Status := Allocation_Failed;
      when others =>
         Terminal.App.Graphics.Release (Data);
         raise;
   end Decode_Encoded_Rows;

   procedure Decode_Encoded_RGBA
     (Source        : RM.Image_Command;
      Maximum_Bytes : Positive;
      Write         : not null access procedure
        (Index    : Positive;
         Value    : Interfaces.Unsigned_8;
         Continue : in out Boolean);
      Status        : out Decode_Status)
   is
      Width : constant Natural := Source.Pixel_Width;
      Height : constant Natural := Source.Pixel_Height;
      Bytes_Per_Pixel : constant Natural :=
        (if Source.Raw_Format = 24 then 3
         elsif Source.Raw_Format = 32 then 4
         else 0);
      Source_Row_Bytes : constant Natural :=
        (if Bytes_Per_Pixel > 0
           and then Width <= Maximum_Bytes / Bytes_Per_Pixel
         then Width * Bytes_Per_Pixel
         else 0);
      Target_Row_Bytes : constant Natural :=
        (if Width <= Maximum_Bytes / 4 then Width * 4 else 0);
      Use_Row_Stride : constant Boolean :=
        Bytes_Per_Pixel = 4
        and then Target_Row_Bytes > 0
        and then Source.Decoded_Row_Stride_Bytes > Target_Row_Bytes
        and then Source.Decoded_Row_Stride_Bytes mod 4 = 0;
      Target_Stride : constant Natural :=
        (if Use_Row_Stride
         then Source.Decoded_Row_Stride_Bytes
         else Target_Row_Bytes);
      Failed : Boolean := False;
      Row_Status : Decode_Status;

      procedure Put
        (Index    : Positive;
         Value    : Interfaces.Unsigned_8;
         Continue : in out Boolean) is
      begin
         if Index > Maximum_Bytes then
            Failed := True;
            Continue := False;
         else
            Write (Index, Value, Continue);
            if not Continue then
               Failed := True;
            end if;
         end if;
      end Put;

      procedure Capture_Row
        (Y        : Natural;
         Row      : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean)
      is
         Target_Index : Natural := 0;
      begin
         if Source_Row_Bytes = 0
           or else Target_Row_Bytes = 0
           or else Target_Stride = 0
           or else Y >= Height
           or else Row'Length < Source_Row_Bytes
           or else Y > (Maximum_Bytes - 1) / Target_Stride
         then
            Failed := True;
            Continue := False;
            return;
         end if;

         Target_Index := Y * Target_Stride + 1;
         if Target_Index > Maximum_Bytes
           or else Target_Row_Bytes > Maximum_Bytes - Target_Index + 1
         then
            Failed := True;
            Continue := False;
            return;
         end if;

         if Bytes_Per_Pixel = 4 then
            for Offset in 0 .. Target_Row_Bytes - 1 loop
               Put
                 (Target_Index + Offset,
                  Interfaces.Unsigned_8 (Row (Row'First + Offset)),
                  Continue);
               exit when not Continue;
            end loop;
         else
            for Pixel in 0 .. Width - 1 loop
               declare
                  Source_Offset : constant Natural := Pixel * 3;
                  Target_Offset : constant Natural := Pixel * 4;
               begin
                  Put
                    (Target_Index + Target_Offset,
                     Interfaces.Unsigned_8 (Row (Row'First + Source_Offset)),
                     Continue);
                  exit when not Continue;
                  Put
                    (Target_Index + Target_Offset + 1,
                     Interfaces.Unsigned_8
                       (Row (Row'First + Source_Offset + 1)),
                     Continue);
                  exit when not Continue;
                  Put
                    (Target_Index + Target_Offset + 2,
                     Interfaces.Unsigned_8
                       (Row (Row'First + Source_Offset + 2)),
                     Continue);
                  exit when not Continue;
                  Put
                    (Target_Index + Target_Offset + 3, 16#FF#, Continue);
                  exit when not Continue;
               end;
            end loop;
         end if;

         if Continue
           and then Use_Row_Stride
           and then Source.Decoded_Row_Stride_Bytes > Target_Row_Bytes
           and then Y < Height - 1
         then
            for Offset in Target_Row_Bytes ..
              Source.Decoded_Row_Stride_Bytes - 1
            loop
               Put (Target_Index + Offset, 0, Continue);
               exit when not Continue;
            end loop;
         end if;
      end Capture_Row;
   begin
      Status := Invalid_Source;
      if Source.Encoded_Source_Bytes = null
        or else Source.Encoded_Source_Length = 0
        or else Source.Encoded_Source_Length >
          Source.Encoded_Source_Bytes'Length
        or else Bytes_Per_Pixel = 0
        or else Source_Row_Bytes = 0
        or else Target_Row_Bytes = 0
        or else Target_Stride = 0
        or else Source.Decoded_Source = RM.Image_Decoded_Source_Buffer
      then
         return;
      end if;

      Decode_Encoded_Rows (Source, Capture_Row'Access, Row_Status);
      if not Failed and then Row_Status = Decode_Ok
      then
         Status := Decode_Ok;
      elsif Row_Status = Allocation_Failed then
         Status := Allocation_Failed;
      end if;
   exception
      when Storage_Error =>
         Status := Allocation_Failed;
      when others =>
         raise;
   end Decode_Encoded_RGBA;
end Terminal.App.Image_Staging;
