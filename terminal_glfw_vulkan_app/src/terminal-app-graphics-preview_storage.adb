with Terminal.Common.Bytes;
with System;

package body Terminal.App.Graphics.Preview_Storage is
   use type System.Address;
   use type Terminal.App.Image_Decode.Status;
   procedure Ensure_Bytes (Data : in out Graphics_Data_Preview) is
   begin
      if Terminal.App.Owned_Image_Data.Is_Empty (Data.Storage.Bytes) then
         Terminal.App.Owned_Image_Data.Allocate
           (Data.Storage.Bytes, Max_Data_Preview_Length);
         Terminal.App.Owned_Image_Data.Fill (Data.Storage.Bytes, 0);
      end if;
      Data.Storage_State := Owned_Data_Storage;
   end Ensure_Bytes;

   procedure Capture_RGBA_Row
     (Data     : in out Graphics_Data_Preview;
      Y        : Natural;
      Row      : Terminal.Common.Bytes.Byte_Array;
      Continue : in out Boolean)
   is
      Needed : Natural := 0;
      Offset : Natural := 0;
   begin
      if Data.Pixel_Width = 0
        or else Data.Pixel_Height = 0
        or else Data.Pixel_Width > Max_Data_Preview_Length / 4
      then
         Continue := False;
         return;
      end if;
      Needed := Data.Pixel_Width * 4;
      if Data.Pixel_Height > Max_Data_Preview_Length / Needed
        or else Row'Length /= Needed
        or else Y >= Data.Pixel_Height
        or else Y /= Data.Captured_RGBA_Rows
        or else Y > (Natural'Last - 1) / Row'Length
      then
         Continue := False;
         return;
      end if;
      Needed := Needed * Data.Pixel_Height;
      Offset := Y * (Data.Pixel_Width * 4) + 1;
      Ensure_Bytes (Data, Needed);
      if Offset > Terminal.App.Owned_Image_Data.Length (Data.Storage.Bytes)
        or else Row'Length >
          Terminal.App.Owned_Image_Data.Length (Data.Storage.Bytes) - Offset + 1
      then
         Continue := False;
         return;
      end if;
      Terminal.App.Owned_Image_Data.Copy
        (Data.Storage.Bytes, Row, Offset);
      Data.Captured_RGBA_Rows := Data.Captured_RGBA_Rows + 1;
   end Capture_RGBA_Row;

   function RGBA_Rows_Complete
     (Data : Graphics_Data_Preview) return Boolean is
     (Data.Pixel_Height > 0
      and then Data.Captured_RGBA_Rows = Data.Pixel_Height);

   procedure Ensure_Bytes
     (Data     : in out Graphics_Data_Preview;
      Capacity : Natural)
   is
      Actual : constant Natural :=
        Natural'Min (Natural'Max (Capacity, 1), Max_Data_Preview_Length);
      Replacement : Terminal.App.Owned_Image_Data.Owner;
   begin
      if Terminal.App.Owned_Image_Data.Is_Empty (Data.Storage.Bytes) then
         Terminal.App.Owned_Image_Data.Allocate (Data.Storage.Bytes, Actual);
         Terminal.App.Owned_Image_Data.Fill (Data.Storage.Bytes, 0);
      elsif Terminal.App.Owned_Image_Data.Length (Data.Storage.Bytes) < Actual
      then
         Terminal.App.Owned_Image_Data.Allocate (Replacement, Actual);
         Terminal.App.Owned_Image_Data.Fill (Replacement, 0);
         declare
            procedure Copy_Previous
              (Bytes : Terminal.Common.Bytes.Byte_Array) is
            begin
               Terminal.App.Owned_Image_Data.Copy (Replacement, Bytes);
            end Copy_Previous;
         begin
            Terminal.App.Owned_Image_Data.Read
              (Data.Storage.Bytes, Copy_Previous'Access);
         end;
         Terminal.App.Owned_Image_Data.Release (Data.Storage.Bytes);
         Terminal.App.Owned_Image_Data.Move
           (Replacement, Data.Storage.Bytes);
         Data.Storage_State := Owned_Data_Storage;
      end if;
      Data.Storage_State := Owned_Data_Storage;
   end Ensure_Bytes;

   procedure Reset_Metadata (Data : in out Graphics_Data_Preview) is
   begin
      Data.Header_Recognized := False;
      Data.Has_Data := False;
      Data.Encoded_Length := 0;
      Data.Raw_Format := 0;
      Data.Pixel_Width := 0;
      Data.Pixel_Height := 0;
      Data.Decoded_Length := 0;
      Data.Decoded_Row_Stride_Bytes := 0;
      Data.Decode_Complete := False;
      Data.Decode_Status := Decode_Not_Attempted;
      Data.Captured_RGBA_Rows := 0;
      Data.Storage_State :=
        (if Terminal.App.Owned_Image_Data.Is_Empty (Data.Storage.Bytes)
         then No_Data_Storage
         else Owned_Data_Storage);
   end Reset_Metadata;

   procedure Reset_Decode_Metadata (Data : in out Graphics_Data_Preview) is
   begin
      Data.Raw_Format := 0;
      Data.Pixel_Width := 0;
      Data.Pixel_Height := 0;
      Data.Decoded_Length := 0;
      Data.Decoded_Row_Stride_Bytes := 0;
      Data.Decode_Complete := False;
      Data.Decode_Status := Decode_Not_Attempted;
      Data.Captured_RGBA_Rows := 0;
      Data.Storage_State :=
        (if Terminal.App.Owned_Image_Data.Is_Empty (Data.Storage.Bytes)
         then No_Data_Storage
         else Owned_Data_Storage);
   end Reset_Decode_Metadata;

   procedure Release (Data : in out Graphics_Data_Preview) is
   begin
      Terminal.App.Owned_Image_Data.Release (Data.Storage.Bytes);
      Reset_Metadata (Data);
   end Release;

   function Has_Bytes (Data : Graphics_Data_Preview) return Boolean is
     (Data.Decoded_Length > 0
      and then not Terminal.App.Owned_Image_Data.Is_Empty (Data.Storage.Bytes)
      and then Terminal.App.Owned_Image_Data.Length (Data.Storage.Bytes)
        >= Data.Decoded_Length);

   function Byte_At
     (Data : Graphics_Data_Preview;
      Offset : Positive) return Terminal.Common.Bytes.Byte is
   begin
      if not Has_Bytes (Data) or else Offset > Data.Decoded_Length then
         raise Constraint_Error with "graphics-preview offset outside data";
      end if;
      return Terminal.App.Owned_Image_Data.Element (Data.Storage.Bytes, Offset);
   end Byte_At;

   procedure Read_Bytes
     (Data    : Graphics_Data_Preview;
      Process : not null access procedure
        (Bytes : Terminal.Common.Bytes.Byte_Array)) is
   begin
      if not Has_Bytes (Data) then
         raise Program_Error with "graphics preview has no published bytes";
      end if;
      declare
         procedure Read_Published
           (Bytes : Terminal.Common.Bytes.Byte_Array) is
         begin
            Process
              (Bytes (Bytes'First .. Bytes'First + Data.Decoded_Length - 1));
         end Read_Published;
      begin
         Terminal.App.Owned_Image_Data.Read
           (Data.Storage.Bytes, Read_Published'Access);
      end;
   end Read_Bytes;

   procedure Extract_Bytes
     (Data  : in out Graphics_Data_Preview;
      Bytes : in out Terminal.App.Owned_Image_Data.Owner)
   is
   begin
      Terminal.App.Owned_Image_Data.Move (Data.Storage.Bytes, Bytes);
      Data.Storage_State := No_Data_Storage;
   end Extract_Bytes;

   function Header_Recognized
     (Data : Graphics_Data_Preview) return Boolean is
     (Data.Header_Recognized);

   function Has_Data (Data : Graphics_Data_Preview) return Boolean is
     (Data.Has_Data);

   function Encoded_Length (Data : Graphics_Data_Preview) return Natural is
     (Data.Encoded_Length);

   function Raw_Format (Data : Graphics_Data_Preview) return Natural is
     (Data.Raw_Format);

   function Pixel_Width (Data : Graphics_Data_Preview) return Natural is
     (Data.Pixel_Width);

   function Pixel_Height (Data : Graphics_Data_Preview) return Natural is
     (Data.Pixel_Height);

   function Decoded_Length
     (Data : Graphics_Data_Preview) return Data_Preview_Length_Range is
     (Data.Decoded_Length);

   function Decoded_Row_Stride_Bytes
     (Data : Graphics_Data_Preview) return Natural is
     (Data.Decoded_Row_Stride_Bytes);

   function Decode_Complete (Data : Graphics_Data_Preview) return Boolean is
     (Data.Decode_Complete);

   function Decode_Status
     (Data : Graphics_Data_Preview) return Data_Decode_Status is
     (Data.Decode_Status);

   function Metadata_Preview
     (Header_Recognized : Boolean;
      Has_Data          : Boolean;
      Raw_Format        : Natural;
      Pixel_Width       : Natural;
      Pixel_Height      : Natural) return Graphics_Data_Preview is
   begin
      return Result : Graphics_Data_Preview do
         Result.Header_Recognized := Header_Recognized;
         Result.Has_Data := Has_Data;
         Result.Raw_Format := Raw_Format;
         Result.Pixel_Width := Pixel_Width;
         Result.Pixel_Height := Pixel_Height;
      end return;
   end Metadata_Preview;

   procedure Set_Decode_Failure
     (Data   : in out Graphics_Data_Preview;
      Status : Data_Decode_Status) is
   begin
      if Status = Decode_Ok then
         raise Constraint_Error with
           "a successful decode cannot be recorded as a failure";
      end if;
      Data.Raw_Format := 0;
      Data.Pixel_Width := 0;
      Data.Pixel_Height := 0;
      Data.Decoded_Length := 0;
      Data.Decoded_Row_Stride_Bytes := 0;
      Data.Decode_Complete := False;
      Data.Decode_Status := Status;
      if Terminal.App.Owned_Image_Data.Is_Empty (Data.Storage.Bytes)
        and then Data.Storage_State = External_Data_Storage
      then
         Data.Storage_State := No_Data_Storage;
      end if;
   end Set_Decode_Failure;

   procedure Set_Decode_Metadata
     (Data                     : in out Graphics_Data_Preview;
      Has_Data                 : Boolean;
      Encoded_Length           : Natural;
      Raw_Format               : Natural;
      Pixel_Width              : Natural;
      Pixel_Height             : Natural;
      Decoded_Length           : Data_Preview_Length_Range;
      Decoded_Row_Stride_Bytes : Natural;
      Status                   : Data_Decode_Status;
      Complete                 : Boolean) is
   begin
      if Complete /= (Status = Decode_Ok) then
         raise Constraint_Error with
           "decode completion and status disagree";
      elsif Complete
        and then
          (not Has_Data
           or else Pixel_Width = 0
           or else Pixel_Height = 0
           or else Decoded_Length = 0
           or else Decoded_Row_Stride_Bytes = 0)
      then
         raise Constraint_Error with
           "a completed decode requires nonempty image metadata";
      end if;
      Reset_Metadata (Data);
      Data.Header_Recognized := True;
      Data.Has_Data := Has_Data;
      Data.Encoded_Length := Encoded_Length;
      Data.Raw_Format := Raw_Format;
      Data.Pixel_Width := Pixel_Width;
      Data.Pixel_Height := Pixel_Height;
      Data.Decoded_Length := Decoded_Length;
      Data.Decoded_Row_Stride_Bytes := Decoded_Row_Stride_Bytes;
      Data.Decode_Status := Status;
      Data.Decode_Complete := Complete;
      if Terminal.App.Owned_Image_Data.Is_Empty (Data.Storage.Bytes)
        and then Complete
      then
         Data.Storage_State := External_Data_Storage;
      end if;
   end Set_Decode_Metadata;

   procedure Set_Decoded_Metadata
     (Data                     : in out Graphics_Data_Preview;
      Encoded_Length           : Natural;
      Raw_Format               : Natural;
      Pixel_Width              : Positive;
      Pixel_Height             : Positive;
      Decoded_Length           : Data_Preview_Length_Range;
      Decoded_Row_Stride_Bytes : Positive) is
   begin
      Set_Decode_Metadata
        (Data,
         Has_Data                 => True,
         Encoded_Length           => Encoded_Length,
         Raw_Format               => Raw_Format,
         Pixel_Width              => Pixel_Width,
         Pixel_Height             => Pixel_Height,
         Decoded_Length           => Decoded_Length,
         Decoded_Row_Stride_Bytes => Decoded_Row_Stride_Bytes,
         Status                   => Decode_Ok,
         Complete                 => True);
   end Set_Decoded_Metadata;

   procedure Adopt_Bytes
     (Data  : in out Graphics_Data_Preview;
      Bytes : in out Terminal.App.Owned_Image_Data.Owner)
   is
   begin
      Terminal.App.Owned_Image_Data.Release (Data.Storage.Bytes);
      Terminal.App.Owned_Image_Data.Move (Bytes, Data.Storage.Bytes);
      Data.Storage_State :=
        (if Terminal.App.Owned_Image_Data.Is_Empty (Data.Storage.Bytes)
         then No_Data_Storage
         else Owned_Data_Storage);
   end Adopt_Bytes;

   procedure Take_Bytes
     (Data  : in out Graphics_Data_Preview;
      Bytes : in out Terminal.App.Owned_Image_Data.Owner)
   is
      Published : constant Boolean :=
        Data.Decode_Complete
        and then Data.Decode_Status = Decode_Ok
        and then Data.Decoded_Length > 0;
   begin
      if not Published then
         return;
      end if;
      Terminal.App.Owned_Image_Data.Move (Data.Storage.Bytes, Bytes);
      Data.Storage_State := Detached_Data_Storage;
   end Take_Bytes;

   procedure Move
     (Source : in out Graphics_Data_Preview;
      Target : in out Graphics_Data_Preview) is
   begin
      if Source'Address = Target'Address then
         return;
      end if;
      Release (Target);
      Target.Header_Recognized := Source.Header_Recognized;
      Target.Has_Data := Source.Has_Data;
      Target.Encoded_Length := Source.Encoded_Length;
      Target.Raw_Format := Source.Raw_Format;
      Target.Pixel_Width := Source.Pixel_Width;
      Target.Pixel_Height := Source.Pixel_Height;
      Target.Decoded_Length := Source.Decoded_Length;
      Target.Decoded_Row_Stride_Bytes := Source.Decoded_Row_Stride_Bytes;
      Target.Decode_Complete := Source.Decode_Complete;
      Target.Decode_Status := Source.Decode_Status;
      Target.Captured_RGBA_Rows := Source.Captured_RGBA_Rows;
      Target.Storage_State := Source.Storage_State;
      Terminal.App.Owned_Image_Data.Move
        (Source.Storage.Bytes, Target.Storage.Bytes);
      Reset_Metadata (Source);
   end Move;
end Terminal.App.Graphics.Preview_Storage;
