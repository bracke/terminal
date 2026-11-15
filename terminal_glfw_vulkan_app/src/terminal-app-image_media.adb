with Ada.Unchecked_Deallocation;
with Interfaces;
with System;
with Terminal.App.Cleanup_Diagnostics;

package body Terminal.App.Image_Media is
   package RM renames Terminal.App.Render_Model;

   use type Interfaces.Unsigned_64;
   use type Terminal.Common.Bytes.Byte;
   procedure Free_Frame_Delays is new Ada.Unchecked_Deallocation
     (Frame_Delay_Array, Frame_Delay_Array_Access);

   function Diagnostic_Identifier (Item : Decode_Diagnostic) return String is
   begin
      if Item.Identifier_Length = 0 then
         return "";
      end if;
      return Item.Identifier (1 .. Item.Identifier_Length);
   end Diagnostic_Identifier;

   procedure Set_Adapter_Diagnostic
     (Target     : in out Decode_Diagnostic;
      Identifier : String;
      Limit      : Decode_Limit_Kind := No_Limit;
      Expected   : Interfaces.Unsigned_64 := 0;
      Actual     : Interfaces.Unsigned_64 := 0)
   is
      Used : constant Natural :=
        Natural'Min (Identifier'Length, Max_Diagnostic_Identifier_Length);
   begin
      Target := (others => <>);
      Target.Present := True;
      Target.Identifier_Length := Used;
      if Used > 0 then
         Target.Identifier (1 .. Used) :=
           Identifier (Identifier'First .. Identifier'First + Used - 1);
      end if;
      Target.Limit := Limit;
      Target.Expected := Expected;
      Target.Actual := Actual;
   end Set_Adapter_Diagnostic;

   function Saturating_Add (Left, Right : Natural) return Natural is
     (if Left > Natural'Last - Right then Natural'Last else Left + Right);

   function Saturating_Multiply (Left, Right : Natural) return Natural is
     (if Left = 0 or else Right = 0 then 0
      elsif Left > Natural'Last / Right then Natural'Last
      else Left * Right);

   function Frame_Delay_Storage_Bytes (Count : Natural) return Natural is
      Component_Bytes : constant Natural :=
        (Frame_Delay_Array'Component_Size + System.Storage_Unit - 1)
        / System.Storage_Unit;
   begin
      return Saturating_Multiply (Count, Component_Bytes);
   end Frame_Delay_Storage_Bytes;

   function Available return Boolean is (True);

   function Is_GIF
     (Data : Terminal.Common.Bytes.Byte_Array;
      Length : Natural) return Boolean
   is
      Signature : String (1 .. 6);
   begin
      if Length < 6 or else Length > Data'Length then
         return False;
      end if;
      for I in Signature'Range loop
         Signature (I) := Character'Val (Data (Data'First + I - 1));
      end loop;
      return Signature in "GIF87a" | "GIF89a";
   end Is_GIF;

   function Is_Headered_PICT
     (Data : Terminal.Common.Bytes.Byte_Array;
      Length : Natural) return Boolean
   is
   begin
      --  Classic PICT files commonly carry a 512-byte all-zero file header.
      --  The image rectangle immediately following it must have increasing
      --  bottom/right coordinates. This also recognizes a truncated headered
      --  picture before the version opcode is available to Is_PICT.
      if Length < 522 or else Length > Data'Length then
         return False;
      end if;
      for Offset in 0 .. 511 loop
         if Data (Data'First + Offset) /= 0 then
            return False;
         end if;
      end loop;
      return
        (Natural (Data (Data'First + 516)) * 256
         + Natural (Data (Data'First + 517)))
        <
        (Natural (Data (Data'First + 520)) * 256
         + Natural (Data (Data'First + 521)))
        and then
        (Natural (Data (Data'First + 514)) * 256
         + Natural (Data (Data'First + 515)))
        <
        (Natural (Data (Data'First + 518)) * 256
         + Natural (Data (Data'First + 519)));
   end Is_Headered_PICT;

   function Is_PICT
     (Data : Terminal.Common.Bytes.Byte_Array;
      Length : Natural) return Boolean
   is
      function Has_Version_At (Offset : Natural) return Boolean is
      begin
         if Length < Offset + 2 then
            return False;
         end if;
         declare
            First : constant Positive := Data'First + Offset;
         begin
            return
              (Data (First) = 16#11# and then Data (First + 1) = 1)
              or else
                (Length >= Offset + 4
                 and then Data (First) = 0
                 and then Data (First + 1) = 16#11#
                 and then Data (First + 2) = 2
                 and then Data (First + 3) = 16#FF#);
         end;
      end Has_Version_At;
   begin
      if Length = 0 or else Length > Data'Length then
         return False;
      end if;
      --  The version opcode follows the two-byte size and eight-byte frame,
      --  either at the start of a raw picture or after the 512-byte file
      --  header. Checking it avoids running arbitrary optional media through
      --  the PICT parser merely to identify its format.
      return Has_Version_At (10) or else Has_Version_At (522);
   end Is_PICT;

   procedure Release (Result : in out Decoded_Image) is
   begin
      Terminal.App.Owned_Image_Data.Release (Result.Storage.Bytes);
      if Result.Delays_MS /= null then
         Free_Frame_Delays (Result.Delays_MS);
      end if;
      Result.Pixel_Width := 0;
      Result.Pixel_Height := 0;
      Result.Frame_Count := 0;
      Result.Loop_Count := 1;
      Result.Frame_Bytes := 0;
      Result.Total_Bytes := 0;
      Result.Adapter_Buffer_Bytes := 0;
      Result.Decoder_Configured_Bytes := 0;
      Result.Delays_MS := null;
      Result.Diagnostic := (others => <>);
      Result.Warning_Count := 0;
      Result.First_Warning := (others => <>);
   end Release;

   procedure Move_Bytes
     (Result : in out Decoded_Image;
      Target : in out Terminal.App.Owned_Image_Data.Owner)
   is
   begin
      if not Terminal.App.Owned_Image_Data.Is_Empty (Target) then
         raise Program_Error with "image-media move target is populated";
      end if;
      Terminal.App.Owned_Image_Data.Move (Result.Storage.Bytes, Target);
   end Move_Bytes;

   function Has_Bytes (Result : Decoded_Image) return Boolean is
     (not Terminal.App.Owned_Image_Data.Is_Empty (Result.Storage.Bytes));

   function Byte_Length (Result : Decoded_Image) return Natural is
     (Terminal.App.Owned_Image_Data.Length (Result.Storage.Bytes));

   function Byte_At
     (Result : Decoded_Image; Index : Positive)
      return Terminal.Common.Bytes.Byte
   is
   begin
      if Terminal.App.Owned_Image_Data.Is_Empty (Result.Storage.Bytes)
        or else Index > Terminal.App.Owned_Image_Data.Length
          (Result.Storage.Bytes)
      then
         raise Constraint_Error with "decoded image byte index out of bounds";
      end if;
      return Terminal.App.Owned_Image_Data.Element (Result.Storage.Bytes, Index);
   end Byte_At;

   procedure Copy_Frame
     (Result : Decoded_Image;
      Frame  : Positive;
      Target : out Terminal.Common.Bytes.Byte_Array)
   is
      First : Positive;
   begin
      if Terminal.App.Owned_Image_Data.Is_Empty (Result.Storage.Bytes)
        or else Frame > Result.Frame_Count
        or else Result.Frame_Bytes = 0
        or else Target'Length /= Result.Frame_Bytes
      then
         raise Constraint_Error with "decoded image frame copy is invalid";
      end if;
      First := 1 + (Frame - 1) * Result.Frame_Bytes;
      declare
         procedure Copy_Bytes
           (Bytes : Terminal.Common.Bytes.Byte_Array) is
         begin
            Target := Bytes (First .. First + Result.Frame_Bytes - 1);
         end Copy_Bytes;
      begin
         Terminal.App.Owned_Image_Data.Read
           (Result.Storage.Bytes, Copy_Bytes'Access);
      end;
   end Copy_Frame;

   function Pixel_Width (Result : Decoded_Image) return Natural is
     (Result.Pixel_Width);

   function Pixel_Height (Result : Decoded_Image) return Natural is
     (Result.Pixel_Height);

   function Frame_Count (Result : Decoded_Image) return Natural is
     (Result.Frame_Count);

   function Loop_Count (Result : Decoded_Image) return Natural is
     (Result.Loop_Count);

   function Frame_Bytes (Result : Decoded_Image) return Natural is
     (Result.Frame_Bytes);

   function Total_Bytes (Result : Decoded_Image) return Natural is
     (Result.Total_Bytes);

   function Adapter_Buffer_Bytes (Result : Decoded_Image) return Natural is
     (Result.Adapter_Buffer_Bytes);

   function Decoder_Configured_Bytes
     (Result : Decoded_Image) return Natural is
     (Result.Decoder_Configured_Bytes);

   function Delay_MS
     (Result : Decoded_Image;
      Frame  : Positive) return Natural is
   begin
      if Frame > Result.Frame_Count then
         raise Constraint_Error with "decoded image frame delay is invalid";
      end if;
      return
        (if Result.Delays_MS = null then 100 else Result.Delays_MS (Frame));
   end Delay_MS;

   function Diagnostic (Result : Decoded_Image) return Decode_Diagnostic is
     (Result.Diagnostic);

   function Warning_Count (Result : Decoded_Image) return Natural is
     (Result.Warning_Count);

   function First_Warning (Result : Decoded_Image) return Decode_Diagnostic is
     (Result.First_Warning);

   overriding procedure Finalize (Result : in out Decoded_Image) is
   begin
      Release (Result);
   exception
      when E : others =>
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Media_Decoder,
            E,
            "finalize decoded image");
   end Finalize;

   procedure Decode_GIF
     (Data                    : Terminal.Common.Bytes.Byte_Array;
      Length                  : Natural;
      Maximum_Decoded_Bytes   : Decode_Byte_Limit;
      Maximum_Pixel_Dimension : Positive;
      Maximum_Frames          : Positive;
      Result                  : in out Decoded_Image;
      Status                  : out Decode_Status)
   is separate;

   procedure Decode_PICT
     (Data                    : Terminal.Common.Bytes.Byte_Array;
      Length                  : Natural;
      Maximum_Decoded_Bytes   : Decode_Byte_Limit;
      Maximum_Pixel_Dimension : Positive;
      Result                  : in out Decoded_Image;
      Status                  : out Decode_Status)
   is separate;

   procedure Decode
     (Data                    : Terminal.Common.Bytes.Byte_Array;
      Length                  : Natural;
      Maximum_Decoded_Bytes   : Decode_Byte_Limit;
      Maximum_Pixel_Dimension : Positive;
      Result                  : in out Decoded_Image;
      Status                  : out Decode_Status;
      Maximum_Frames          : Positive := Max_Frames)
   is
   begin
      Release (Result);
      Status := Decode_Unavailable;
      if Length = 0 or else Length > Data'Length then
         Status := Decode_Invalid;
         Set_Adapter_Diagnostic
           (Result.Diagnostic,
            "media_input_length_invalid",
            Compressed_Byte_Limit,
            Interfaces.Unsigned_64 (Data'Length),
            Interfaces.Unsigned_64 (Length));
         return;
      elsif Is_GIF (Data, Length) then
         Decode_GIF
           (Data,
            Length,
            Maximum_Decoded_Bytes,
            Maximum_Pixel_Dimension,
            Positive'Min (Maximum_Frames, Max_Frames),
            Result,
            Status);
      elsif Is_PICT (Data, Length) or else Is_Headered_PICT (Data, Length) then
         Decode_PICT
           (Data,
            Length,
            Maximum_Decoded_Bytes,
            Maximum_Pixel_Dimension,
            Result,
            Status);
      end if;
   end Decode;
end Terminal.App.Image_Media;
