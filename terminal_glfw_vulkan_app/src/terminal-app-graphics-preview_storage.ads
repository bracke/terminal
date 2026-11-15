private package Terminal.App.Graphics.Preview_Storage is
   procedure Ensure_Bytes (Data : in out Graphics_Data_Preview);
   procedure Ensure_Bytes
     (Data : in out Graphics_Data_Preview; Capacity : Natural);
   procedure Capture_RGBA_Row
     (Data     : in out Graphics_Data_Preview;
      Y        : Natural;
      Row      : Terminal.Common.Bytes.Byte_Array;
      Continue : in out Boolean);
   function RGBA_Rows_Complete
     (Data : Graphics_Data_Preview) return Boolean;
   procedure Reset_Metadata (Data : in out Graphics_Data_Preview);
   procedure Reset_Decode_Metadata (Data : in out Graphics_Data_Preview);
   procedure Release (Data : in out Graphics_Data_Preview);
   function Has_Bytes (Data : Graphics_Data_Preview) return Boolean;
   function Byte_At
     (Data : Graphics_Data_Preview;
      Offset : Positive) return Terminal.Common.Bytes.Byte;
   procedure Read_Bytes
     (Data    : Graphics_Data_Preview;
      Process : not null access procedure
        (Bytes : Terminal.Common.Bytes.Byte_Array));
   procedure Extract_Bytes
     (Data  : in out Graphics_Data_Preview;
      Bytes : in out Terminal.App.Owned_Image_Data.Owner);
   function Header_Recognized
     (Data : Graphics_Data_Preview) return Boolean;
   function Has_Data (Data : Graphics_Data_Preview) return Boolean;
   function Encoded_Length (Data : Graphics_Data_Preview) return Natural;
   function Raw_Format (Data : Graphics_Data_Preview) return Natural;
   function Pixel_Width (Data : Graphics_Data_Preview) return Natural;
   function Pixel_Height (Data : Graphics_Data_Preview) return Natural;
   function Decoded_Length
     (Data : Graphics_Data_Preview) return Data_Preview_Length_Range;
   function Decoded_Row_Stride_Bytes
     (Data : Graphics_Data_Preview) return Natural;
   function Decode_Complete (Data : Graphics_Data_Preview) return Boolean;
   function Decode_Status
     (Data : Graphics_Data_Preview) return Data_Decode_Status;
   function Metadata_Preview
     (Header_Recognized : Boolean;
      Has_Data          : Boolean;
      Raw_Format        : Natural;
      Pixel_Width       : Natural;
      Pixel_Height      : Natural) return Graphics_Data_Preview;
   procedure Set_Decode_Failure
     (Data : in out Graphics_Data_Preview; Status : Data_Decode_Status);
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
      Complete                 : Boolean);
   procedure Set_Decoded_Metadata
     (Data                     : in out Graphics_Data_Preview;
      Encoded_Length           : Natural;
      Raw_Format               : Natural;
      Pixel_Width              : Positive;
      Pixel_Height             : Positive;
      Decoded_Length           : Data_Preview_Length_Range;
      Decoded_Row_Stride_Bytes : Positive);
   procedure Adopt_Bytes
     (Data  : in out Graphics_Data_Preview;
      Bytes : in out Terminal.App.Owned_Image_Data.Owner);
   procedure Take_Bytes
     (Data  : in out Graphics_Data_Preview;
      Bytes : in out Terminal.App.Owned_Image_Data.Owner);
   procedure Move
     (Source : in out Graphics_Data_Preview;
      Target : in out Graphics_Data_Preview);
end Terminal.App.Graphics.Preview_Storage;
