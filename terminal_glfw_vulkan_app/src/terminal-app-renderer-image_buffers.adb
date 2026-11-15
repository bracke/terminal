with Terminal.App.Image_Upload_Layout;

package body Terminal.App.Renderer.Image_Buffers is
   use type RM.Image_Data_View;

   function Extent
     (Raw_Format   : Natural;
      Pixel_Width  : Natural;
      Pixel_Height : Natural;
      Row_Stride   : Natural) return Natural
   is
      Bytes_Per_Pixel : constant Natural :=
        (if Raw_Format = 8 then 1
         elsif Raw_Format = 16 then 2
         elsif Raw_Format = 24 then 3
         elsif Raw_Format = 32 then 4
         else 0);
   begin
      return Terminal.App.Image_Upload_Layout.Required_Source_Bytes
        (Width                  => Pixel_Width,
         Height                 => Pixel_Height,
         Source_Bytes_Per_Pixel => Bytes_Per_Pixel,
         Row_Stride_Bytes       => Row_Stride,
         Maximum_Bytes          => RM.Max_Image_Decoded_Data_Length);
   end Extent;

   function Ready
     (Data        : Terminal.App.Graphics.Graphics_Data_Preview;
      Image_Bytes : Terminal.App.Owned_Image_Data.Owner) return Boolean
   is
      Required : constant Natural :=
        Extent
          (Data.Raw_Format,
           Data.Pixel_Width,
           Data.Pixel_Height,
           Data.Decoded_Row_Stride_Bytes);
   begin
      return Data.Decode_Complete
        and then not Terminal.App.Owned_Image_Data.Is_Empty (Image_Bytes)
        and then Data.Raw_Format /= 0
        and then Data.Pixel_Width > 0
        and then Data.Pixel_Height > 0
        and then Data.Decoded_Row_Stride_Bytes > 0
        and then Required > 0
        and then Terminal.App.Owned_Image_Data.Length (Image_Bytes) >= Required
        and then Data.Decoded_Length = Required;
   end Ready;

   procedure Copy_Preview
     (Source         : Terminal.App.Owned_Image_Data.Owner;
      Decoded_Length : Natural;
      Preview_Length : out Natural;
      Preview_Bytes  : out Terminal.Common.Bytes.Byte_Array)
   is
      procedure Copy (Bytes : Terminal.Common.Bytes.Byte_Array) is
      begin
         Preview_Length :=
           Natural'Min
             (Natural'Min (Decoded_Length, Bytes'Length),
              RM.Max_Image_Decoded_Preview_Length);
         Preview_Bytes := (others => 0);
         if Preview_Length > 0 then
            Preview_Bytes
              (Preview_Bytes'First
               .. Preview_Bytes'First + Preview_Length - 1) :=
              Bytes (Bytes'First .. Bytes'First + Preview_Length - 1);
         end if;
      end Copy;
   begin
      if Terminal.App.Owned_Image_Data.Is_Empty (Source) then
         Preview_Length := 0;
         Preview_Bytes := (others => 0);
      else
         Terminal.App.Owned_Image_Data.Read (Source, Copy'Access);
      end if;
   end Copy_Preview;

   procedure Copy_Preview
     (Source         : Terminal.App.Graphics.Graphics_Data_Preview;
      Decoded_Length : Natural;
      Preview_Length : out Natural;
      Preview_Bytes  : out Terminal.Common.Bytes.Byte_Array)
   is
      procedure Copy (Bytes : Terminal.Common.Bytes.Byte_Array) is
      begin
         Preview_Length :=
           Natural'Min
             (Natural'Min (Decoded_Length, Bytes'Length),
              RM.Max_Image_Decoded_Preview_Length);
         Preview_Bytes := (others => 0);
         if Preview_Length > 0 then
            Preview_Bytes
              (Preview_Bytes'First
               .. Preview_Bytes'First + Preview_Length - 1) :=
              Bytes (Bytes'First .. Bytes'First + Preview_Length - 1);
         end if;
      end Copy;
   begin
      if not Terminal.App.Graphics.Has_Bytes (Source) then
         Preview_Length := 0;
         Preview_Bytes := (others => 0);
      else
         Terminal.App.Graphics.Read_Bytes (Source, Copy'Access);
      end if;
   end Copy_Preview;

   procedure Copy_Preview
     (Source         : RM.Image_Data_View;
      Decoded_Length : Natural;
      Preview_Length : out Natural;
      Preview_Bytes  : out Terminal.Common.Bytes.Byte_Array)
   is
   begin
      Preview_Length :=
        Natural'Min (Decoded_Length, RM.Max_Image_Decoded_Preview_Length);
      Preview_Bytes := (others => 0);
      if Source = null then
         return;
      end if;
      for I in 1 .. Preview_Length loop
         exit when I > Source'Last;
         Preview_Bytes (I) := Source (I);
      end loop;
   end Copy_Preview;

   procedure Copy_Preview
     (Source         : Terminal.Common.Bytes.Byte_Array;
      Decoded_Length : Natural;
      Preview_Length : out Natural;
      Preview_Bytes  : out Terminal.Common.Bytes.Byte_Array)
   is
   begin
      Preview_Length :=
        Natural'Min
          (Natural'Min (Decoded_Length, Source'Length),
           RM.Max_Image_Decoded_Preview_Length);
      Preview_Bytes := (others => 0);
      if Preview_Length > 0 then
         Preview_Bytes
           (Preview_Bytes'First .. Preview_Bytes'First + Preview_Length - 1) :=
             Source (Source'First .. Source'First + Preview_Length - 1);
      end if;
   end Copy_Preview;

   procedure Prepare_Preview_Source
     (Decoded        : RM.Image_Data_View;
      Preview_Length : Natural;
      Preview_Bytes  : Terminal.Common.Bytes.Byte_Array;
      Result         : out RM.Image_Data_View;
      Owner          : in out Terminal.App.Owned_Image_Data.Owner)
   is
   begin
      Terminal.App.Owned_Image_Data.Release (Owner);
      if Decoded /= null then
         Result := Decoded;
      elsif Preview_Length = 0 then
         Result := null;
      else
         Terminal.App.Owned_Image_Data.Allocate (Owner, Preview_Length);
         Terminal.App.Owned_Image_Data.Copy
           (Owner,
            Preview_Bytes
              (Preview_Bytes'First ..
                 Preview_Bytes'First + Preview_Length - 1));
         Result := null;
      end if;
   end Prepare_Preview_Source;

   procedure Capture_Preview_Row
     (Preview_Length : in out Natural;
      Preview_Bytes  : in out Terminal.Common.Bytes.Byte_Array;
      Row_Y          : Natural;
      Row            : Terminal.Common.Bytes.Byte_Array;
      Continue       : in out Boolean)
   is
      pragma Unreferenced (Row_Y);
   begin
      for I in Row'Range loop
         exit when Preview_Length >= Preview_Bytes'Length;
         Preview_Length := Preview_Length + 1;
         Preview_Bytes (Preview_Length) := Row (I);
      end loop;
      Continue := True;
   end Capture_Preview_Row;

   procedure Capture_Row
     (Data          : Terminal.App.Graphics.Graphics_Data_Preview;
      Image_Owner   : in out Terminal.App.Owned_Image_Data.Owner;
      Row_Y         : Natural;
      Row           : Terminal.Common.Bytes.Byte_Array;
      Max_Bytes     : Positive;
      Max_Dimension : Positive;
      Continue      : in out Boolean)
   is
      Required : constant Natural :=
        Extent
          (Data.Raw_Format,
           Data.Pixel_Width,
           Data.Pixel_Height,
           Data.Decoded_Row_Stride_Bytes);
      Offset : Natural := 0;
   begin
      if Required = 0
        or else Required > Max_Bytes
        or else Data.Pixel_Width > Max_Dimension
        or else Data.Pixel_Height > Max_Dimension
        or else Row'Length /= Data.Decoded_Row_Stride_Bytes
        or else Row_Y >= Data.Pixel_Height
        or else Row_Y >
          (Natural'Last - 1) / Data.Decoded_Row_Stride_Bytes
      then
         Continue := False;
         return;
      end if;
      Offset := Row_Y * Data.Decoded_Row_Stride_Bytes + 1;
      if Offset > Required
        or else Row'Length > Required - Offset + 1
      then
         Continue := False;
         return;
      end if;
      if Terminal.App.Owned_Image_Data.Is_Empty (Image_Owner) then
         Terminal.App.Owned_Image_Data.Allocate (Image_Owner, Required);
         Terminal.App.Owned_Image_Data.Fill (Image_Owner, 0);
      elsif Terminal.App.Owned_Image_Data.Length (Image_Owner) < Required then
         Continue := False;
         return;
      end if;
      Terminal.App.Owned_Image_Data.Copy (Image_Owner, Row, Offset);
   exception
      when Storage_Error =>
         Continue := False;
   end Capture_Row;
end Terminal.App.Renderer.Image_Buffers;
