with Ada.Unchecked_Deallocation;
with Terminal.Common.Bytes;
with Terminal.App.Graphics;
with Terminal.App.Graphics_Transport;
with Terminal.App.Image_Media;
with Terminal.App.Image_Store;
with Terminal.App.Render_Model;
with Terminal.Core;

package body Terminal.App.Image_Ingestion is
   use type Terminal.App.Graphics_Transport.Byte_Array_Access;
   use type Terminal.App.Graphics.ITerm2_Size_Unit;
   use type Terminal.App.Render_Model.Image_Data_Access;
   procedure Free_Image_Data is new Ada.Unchecked_Deallocation
     (Terminal.Common.Bytes.Byte_Array,
      Terminal.App.Render_Model.Image_Data_Access);
   function Payload_Start
     (Protocol : Payload_Protocol;
      Text     : String) return Natural
   is
      Separator : constant Character :=
        (if Protocol = Kitty then ';' else ':');
   begin
      for I in Text'Range loop
         if Text (I) = Separator then
            return (if I < Text'Last then I + 1 else 0);
         end if;
      end loop;
      return 0;
   end Payload_Start;

   function Copy_Text
     (Text    : String;
      Control : in out Terminal.App.Image_Store.Allocation_Control)
      return Terminal.App.Render_Model.Image_Data_Access
   is
      Result : Terminal.App.Render_Model.Image_Data_Access;
   begin
      if Text'Length = 0 then
         return null;
      end if;

      if not Terminal.App.Image_Store.Allocation_Allowed (Control) then
         return null;
      end if;

      Result := new Terminal.Common.Bytes.Byte_Array (1 .. Text'Length);
      for I in Text'Range loop
         Result (I - Text'First + 1) :=
           Terminal.Common.Bytes.Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   exception
      when Storage_Error =>
         return null;
   end Copy_Text;

   function Encode_Base64
     (Bytes  : Terminal.App.Graphics_Transport.Byte_Array_Access;
      Length : Natural) return String
   is
      Alphabet : constant String :=
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
   begin
      if Bytes = null or else Length = 0 or else Length > Bytes'Length then
         return "";
      end if;
      declare
         Block_Count : constant Natural :=
           Length / 3 + (if Length mod 3 = 0 then 0 else 1);
      begin
         if Block_Count > Natural'Last / 4 then
            return "";
         end if;
         declare
            Result : String (1 .. Block_Count * 4);
            Source : Natural := 1;
            Target : Natural := 1;
            A, B, C : Natural;
         begin
            while Source <= Length loop
               declare
                  Remaining : constant Positive := Length - Source + 1;
               begin
                  A := Natural (Bytes (Source));
                  B :=
                    (if Remaining >= 2
                     then Natural (Bytes (Source + 1))
                     else 0);
                  C :=
                    (if Remaining >= 3
                     then Natural (Bytes (Source + 2))
                     else 0);
                  Result (Target) := Alphabet (A / 4 + 1);
                  Result (Target + 1) :=
                    Alphabet ((A mod 4) * 16 + B / 16 + 1);
                  Result (Target + 2) :=
                    (if Remaining >= 2
                     then Alphabet ((B mod 16) * 4 + C / 64 + 1)
                     else '=');
                  Result (Target + 3) :=
                    (if Remaining >= 3
                     then Alphabet (C mod 64 + 1)
                     else '=');
                  exit when Remaining <= 3;
                  Source := Source + 3;
                  Target := Target + 4;
               end;
            end loop;
            return Result;
         end;
      end;
   end Encode_Base64;

   function ITerm2_Render_Size
     (Header           : Terminal.App.Graphics.Graphics_Header;
      Intrinsic_Width  : Positive;
      Intrinsic_Height : Positive;
      Cell_Width       : Positive;
      Cell_Height      : Positive;
      View_Width       : Natural;
      View_Height      : Natural) return Pixel_Size
   is
      function Requested
        (Specified : Boolean;
         Value     : Natural;
         Unit      : Terminal.App.Graphics.ITerm2_Size_Unit;
         Intrinsic : Positive;
         Cell_Size : Positive;
         View_Size : Natural) return Float is
      begin
         if not Specified
           or else Unit = Terminal.App.Graphics.ITerm2_Auto
         then
            return Float (Intrinsic);
         end if;
         case Unit is
            when Terminal.App.Graphics.ITerm2_Cells =>
               return Float (Value) * Float (Cell_Size);
            when Terminal.App.Graphics.ITerm2_Pixels =>
               return Float (Value);
            when Terminal.App.Graphics.ITerm2_Percent =>
               return Float (View_Size) * Float (Value) / 100.0;
            when Terminal.App.Graphics.ITerm2_Auto =>
               return Float (Intrinsic);
         end case;
      end Requested;

      Box_Width : constant Float := Requested
        (Header.ITerm2_Width_Specified,
         Header.ITerm2_Width_Value,
         Header.ITerm2_Width_Unit,
         Intrinsic_Width,
         Cell_Width,
         View_Width);
      Box_Height : constant Float := Requested
        (Header.ITerm2_Height_Specified,
         Header.ITerm2_Height_Value,
         Header.ITerm2_Height_Unit,
         Intrinsic_Height,
         Cell_Height,
         View_Height);
      Scale : constant Float :=
        (if not Header.ITerm2_Preserve_Aspect_Ratio
         then 1.0
         elsif Header.ITerm2_Width_Specified
           and then Header.ITerm2_Height_Specified
         then Float'Min
           (Box_Width / Float (Intrinsic_Width),
            Box_Height / Float (Intrinsic_Height))
         elsif Header.ITerm2_Width_Specified
         then Box_Width / Float (Intrinsic_Width)
         elsif Header.ITerm2_Height_Specified
         then Box_Height / Float (Intrinsic_Height)
         else 1.0);
   begin
      return
        (Width => Float'Max
           (1.0,
            (if Header.ITerm2_Preserve_Aspect_Ratio
             then Float (Intrinsic_Width) * Scale
             else Box_Width)),
         Height => Float'Max
           (1.0,
            (if Header.ITerm2_Preserve_Aspect_Ratio
             then Float (Intrinsic_Height) * Scale
             else Box_Height)));
   end ITerm2_Render_Size;

   function Validate_Kitty_Query
     (Header        : Terminal.App.Graphics.Graphics_Header;
      Text          : String;
      Policy        : Terminal.App.Graphics_Transport.Access_Policy;
      Maximum_Bytes : Positive)
      return Terminal.Core.Kitty_Graphics_Result_Code
   is
      use type Terminal.App.Graphics.Data_Decode_Status;
      use type Terminal.App.Graphics_Transport.Load_Status;

      Data : Terminal.App.Graphics.Graphics_Data_Preview :=
        (if Header.Kitty_Transmission in 'f' | 't' | 's'
         then
           (Header_Recognized => Header.Recognized,
            Has_Data => Header.Has_Data,
            others => <>)
         else Terminal.App.Graphics.Data_Preview_Text
           (Terminal.Core.Kitty_Graphics, Text));
      Row_Failed : Boolean := False;
      Decoded_Bytes : Natural := 0;

      function One_Chunk (Index : Positive) return String is
         First : constant Natural := Payload_Start (Kitty, Text);
      begin
         if Index /= 1 or else First = 0 then
            return "";
         end if;
         return Text (First .. Text'Last);
      end One_Chunk;

      procedure Discard_Row
        (Y        : Natural;
         Row      : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean)
      is
         pragma Unreferenced (Y);
      begin
         if Row'Length = 0
           or else Decoded_Bytes > Maximum_Bytes
           or else Row'Length > Maximum_Bytes - Decoded_Bytes
         then
            Row_Failed := True;
            Continue := False;
         else
            Decoded_Bytes := Decoded_Bytes + Row'Length;
            Continue := True;
         end if;
      end Discard_Row;

      function Decoded_Size_Exceeds_Limit return Boolean is
         Bytes_Per_Pixel : constant Natural :=
           (case Data.Raw_Format is
               when 8      => 1,
               when 16     => 2,
               when 24     => 3,
               when 32     => 4,
               when others => 0);
         Row_Bytes : Natural;
      begin
         if Bytes_Per_Pixel = 0
           or else Data.Pixel_Width = 0
           or else Data.Pixel_Height = 0
         then
            return False;
         elsif Data.Pixel_Width > Maximum_Bytes / Bytes_Per_Pixel then
            return True;
         end if;
         Row_Bytes := Data.Pixel_Width * Bytes_Per_Pixel;
         return Data.Pixel_Height > Maximum_Bytes / Row_Bytes;
      end Decoded_Size_Exceeds_Limit;

      function Finish_Result
        return Terminal.Core.Kitty_Graphics_Result_Code
      is
         Too_Large : constant Boolean :=
           Row_Failed
           or else Decoded_Size_Exceeds_Limit
           or else
             (Data.Decode_Complete
              and then Data.Decoded_Length > Maximum_Bytes);
         Resource_Failure : constant Boolean :=
           Data.Decode_Status in
             Terminal.App.Graphics.Decode_Allocation_Failed
             | Terminal.App.Graphics.Decode_Too_Large
             | Terminal.App.Graphics.Decode_Preview_Truncated;
         Valid : constant Boolean :=
           not Too_Large
           and then Data.Decode_Complete
           and then Data.Raw_Format in 8 | 16 | 24 | 32
           and then Data.Pixel_Width > 0
           and then Data.Pixel_Height > 0;
      begin
         Terminal.App.Graphics.Release (Data);
         return
           (if Too_Large or else Resource_Failure
            then Terminal.Core.Kitty_ENOMEM
            elsif Valid then Terminal.Core.Kitty_OK
            else Terminal.Core.Kitty_EINVAL);
      end Finish_Result;
   begin
      if Header.Kitty_Transmission in 'f' | 't' | 's' then
         declare
            First : constant Natural := Payload_Start (Kitty, Text);
            Loaded : Terminal.App.Graphics_Transport.Byte_Array_Access := null;
            Loaded_Length : Natural := 0;
            Load_Status : Terminal.App.Graphics_Transport.Load_Status;
         begin
            if First = 0
              or else not Header.Kitty_Data_Size_Valid
              or else not Header.Kitty_Data_Offset_Valid
              or else Header.Kitty_More_Specified
            then
               Terminal.App.Graphics.Release (Data);
               return Terminal.Core.Kitty_EINVAL;
            end if;
            Terminal.App.Graphics_Transport.Load
              (Medium           => Header.Kitty_Transmission,
               Encoded_Location => Text (First .. Text'Last),
               Offset           => Header.Kitty_Data_Offset,
               Size             => Header.Kitty_Data_Size,
               Size_Specified   => Header.Kitty_Data_Size_Specified,
               Policy           => Policy,
               Maximum_Bytes    => Maximum_Bytes,
               Bytes            => Loaded,
               Length           => Loaded_Length,
               Status           => Load_Status);
            if Load_Status /= Terminal.App.Graphics_Transport.Load_Ok then
               Terminal.App.Graphics.Release (Data);
               return
                 (if Load_Status in
                       Terminal.App.Graphics_Transport.Load_Too_Large
                       | Terminal.App.Graphics_Transport.Load_Allocation_Failed
                  then Terminal.Core.Kitty_ENOMEM
                  else Terminal.Core.Kitty_EBADF);
            end if;
            begin
               Terminal.App.Graphics.Release (Data);
               if Header.Kitty_Compression = 'z' then
                  declare
                     Inflated : Terminal.App.Render_Model.Image_Data_Access := null;
                     Inflated_Length : Natural := 0;
                     Inflate_Status : Terminal.App.Graphics.Data_Decode_Status;
                     Pixel_Size : constant Natural :=
                       (case Header.Kitty_Format is
                           when 8 => 1, when 16 => 2,
                           when 24 => 3, when 32 => 4,
                           when others => 0);
                     Expected : Natural := 0;
                     Limit : Natural := Maximum_Bytes;
                     Exact : Boolean := False;
                  begin
                     if Pixel_Size > 0 then
                        if Header.Pixel_Width = 0
                          or else Header.Pixel_Height = 0
                        then
                           Terminal.App.Graphics_Transport.Release (Loaded);
                           return Terminal.Core.Kitty_EINVAL;
                        elsif Header.Pixel_Width > Maximum_Bytes / Pixel_Size
                          or else Header.Pixel_Height >
                            Maximum_Bytes / (Header.Pixel_Width * Pixel_Size)
                        then
                           Terminal.App.Graphics_Transport.Release (Loaded);
                           return Terminal.Core.Kitty_ENOMEM;
                        end if;
                        Expected :=
                          Header.Pixel_Width * Header.Pixel_Height * Pixel_Size;
                        Limit := Expected;
                        Exact := True;
                     elsif Header.Kitty_Format = 100 then
                        --  For local media S bounds the selected source
                        --  range. It is not the inflated PNG byte count.
                        Limit := Maximum_Bytes;
                        Exact := False;
                     else
                        Terminal.App.Graphics_Transport.Release (Loaded);
                        return Terminal.Core.Kitty_EINVAL;
                     end if;
                     Terminal.App.Graphics.Decode_Zlib_Data
                       (Loaded.all, Loaded_Length, Limit, Exact,
                        Inflated, Inflated_Length, Inflate_Status);
                     Terminal.App.Graphics_Transport.Release (Loaded);
                     if Inflate_Status /= Terminal.App.Graphics.Decode_Ok
                       or else Inflated = null
                     then
                        return
                          (if Inflate_Status in
                                Terminal.App.Graphics.Decode_Allocation_Failed
                                | Terminal.App.Graphics.Decode_Too_Large
                                | Terminal.App.Graphics.Decode_Preview_Truncated
                           then Terminal.Core.Kitty_ENOMEM
                           else Terminal.Core.Kitty_EINVAL);
                     end if;
                     if Pixel_Size > 0 then
                        Data :=
                          (Header_Recognized => True,
                           Has_Data => True,
                           Raw_Format => Header.Kitty_Format,
                           Pixel_Width => Header.Pixel_Width,
                           Pixel_Height => Header.Pixel_Height,
                           Decoded_Length => Inflated_Length,
                           Decoded_Row_Stride_Bytes =>
                             Header.Pixel_Width * Pixel_Size,
                           Decode_Status => Terminal.App.Graphics.Decode_Ok,
                           Decode_Complete => True,
                           others => <>);
                     else
                        Terminal.App.Graphics.Decode_PNG_RGBA_Rows
                          (Inflated.all, Inflated_Length,
                           Discard_Row'Access, Data);
                     end if;
                     Free_Image_Data (Inflated);
                  exception
                     when others =>
                        Terminal.App.Graphics_Transport.Release (Loaded);
                        if Inflated /= null then
                           Free_Image_Data (Inflated);
                        end if;
                        raise;
                  end;
               elsif Header.Kitty_Format in 8 | 16 | 24 | 32 then
                  declare
                     Pixel_Size : constant Natural := Header.Kitty_Format / 8;
                     Expected : Natural;
                  begin
                     if Header.Pixel_Width = 0
                       or else Header.Pixel_Height = 0
                     then
                        Terminal.App.Graphics_Transport.Release (Loaded);
                        return Terminal.Core.Kitty_EINVAL;
                     elsif Header.Pixel_Width > Maximum_Bytes / Pixel_Size
                       or else Header.Pixel_Height >
                         Maximum_Bytes / (Header.Pixel_Width * Pixel_Size)
                     then
                        Terminal.App.Graphics_Transport.Release (Loaded);
                        return Terminal.Core.Kitty_ENOMEM;
                     end if;
                     Expected :=
                       Header.Pixel_Width * Header.Pixel_Height * Pixel_Size;
                     Data :=
                       (Header_Recognized => True,
                        Has_Data => Loaded_Length > 0,
                        Raw_Format => Header.Kitty_Format,
                        Pixel_Width => Header.Pixel_Width,
                        Pixel_Height => Header.Pixel_Height,
                        Decoded_Length => Loaded_Length,
                        Decoded_Row_Stride_Bytes => Header.Pixel_Width * Pixel_Size,
                        Decode_Status =>
                          (if Loaded_Length = Expected
                           then Terminal.App.Graphics.Decode_Ok
                           else Terminal.App.Graphics.Decode_Invalid_Byte),
                        Decode_Complete => Loaded_Length = Expected,
                        others => <>);
                     Terminal.App.Graphics_Transport.Release (Loaded);
                  end;
               elsif Header.Kitty_Format = 100 then
                  Terminal.App.Graphics.Decode_PNG_RGBA_Rows
                    (Loaded.all, Loaded_Length, Discard_Row'Access, Data);
                  Terminal.App.Graphics_Transport.Release (Loaded);
               elsif Header.Kitty_Format =
                 Terminal.App.Graphics.Kitty_JPEG_Format
               then
                  Terminal.App.Graphics.Decode_JPEG_RGBA_Data
                    (Loaded.all, Loaded_Length, Data,
                     Maximum_Decoded_Bytes => Maximum_Bytes);
                  Terminal.App.Graphics_Transport.Release (Loaded);
               elsif Header.Kitty_Format =
                 Terminal.App.Graphics.Kitty_GIF_Format
               then
                  declare
                     Media : Terminal.App.Image_Media.Decoded_Image;
                     Media_Status : Terminal.App.Image_Media.Decode_Status;
                  begin
                     Terminal.App.Image_Media.Decode
                       (Loaded.all, Loaded_Length, Maximum_Bytes,
                        Positive'Last, Media, Media_Status);
                     Terminal.App.Graphics_Transport.Release (Loaded);
                     if Media_Status = Terminal.App.Image_Media.Decode_Ok then
                        Data :=
                          (Header_Recognized => True, Has_Data => True,
                           Raw_Format => 32,
                           Pixel_Width => Media.Pixel_Width,
                           Pixel_Height => Media.Pixel_Height,
                           Decoded_Length => Media.Frame_Bytes,
                           Decoded_Row_Stride_Bytes => Media.Pixel_Width * 4,
                           Decode_Status => Terminal.App.Graphics.Decode_Ok,
                           Decode_Complete => True, others => <>);
                     else
                        Data.Decode_Status :=
                           (case Media_Status is
                              when Terminal.App.Image_Media.
                                     Decode_Allocation_Failed =>
                                 Terminal.App.Graphics.Decode_Allocation_Failed,
                              when Terminal.App.Image_Media.Decode_Too_Large =>
                                 Terminal.App.Graphics.Decode_Too_Large,
                              when others =>
                                 Terminal.App.Graphics.Decode_Invalid_Byte);
                     end if;
                     Terminal.App.Image_Media.Release (Media);
                  end;
               else
                  Terminal.App.Graphics_Transport.Release (Loaded);
                  return Terminal.Core.Kitty_EINVAL;
               end if;
               return Finish_Result;
            exception
               when others =>
                  Terminal.App.Graphics_Transport.Release (Loaded);
                  raise;
            end;
         end;
      end if;

      if not Header.Has_Data
        or else Header.Kitty_Format not in 8 | 16 | 24 | 32 | 100
             | Terminal.App.Graphics.Kitty_JPEG_Format
             | Terminal.App.Graphics.Kitty_GIF_Format
        or else Header.Kitty_Compression not in ASCII.NUL | 'z'
      then
         Terminal.App.Graphics.Release (Data);
         return Terminal.Core.Kitty_EINVAL;
      end if;
      if Header.Kitty_Compression = 'z' then
         if Header.Kitty_Format in 8 | 16 | 24 | 32 then
            Terminal.App.Graphics.Decode_Base64_Zlib_Raw_Chunk_Rows
              (1,
               One_Chunk'Access,
               Header.Kitty_Format,
               Header.Pixel_Width,
               Header.Pixel_Height,
               Discard_Row'Access,
               Data);
         elsif Header.Kitty_Format = 100
           and then Header.Kitty_Data_Size > 0
         then
            declare
               Encoded_Length : Natural := 0;
            begin
               Terminal.App.Graphics.Decode_Base64_Zlib_PNG_Chunk_Rows
                 (1,
                  One_Chunk'Access,
                  Header.Kitty_Data_Size,
                  Encoded_Length,
                  Discard_Row'Access,
                  Data);
            end;
         end if;
      end if;
      return Finish_Result;
   exception
      when Storage_Error =>
         Terminal.App.Graphics.Release (Data);
         return Terminal.Core.Kitty_ENOMEM;
      when Constraint_Error =>
         Terminal.App.Graphics.Release (Data);
         return Terminal.Core.Kitty_EINVAL;
      when others =>
         Terminal.App.Graphics.Release (Data);
         raise;
   end Validate_Kitty_Query;
end Terminal.App.Image_Ingestion;
