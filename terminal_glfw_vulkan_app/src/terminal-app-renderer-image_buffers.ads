with Terminal.Common.Bytes;
with Terminal.App.Graphics;
with Terminal.App.Owned_Image_Data;
with Terminal.App.Render_Model;

private package Terminal.App.Renderer.Image_Buffers is
   package RM renames Terminal.App.Render_Model;

   function Extent
     (Raw_Format   : Natural;
      Pixel_Width  : Natural;
      Pixel_Height : Natural;
      Row_Stride   : Natural) return Natural;

   function Ready
     (Data        : Terminal.App.Graphics.Graphics_Data_Preview;
      Image_Bytes : Terminal.App.Owned_Image_Data.Owner) return Boolean;

   procedure Copy_Preview
     (Source         : Terminal.App.Owned_Image_Data.Owner;
      Decoded_Length : Natural;
      Preview_Length : out Natural;
      Preview_Bytes  : out Terminal.Common.Bytes.Byte_Array);

   procedure Copy_Preview
     (Source         : Terminal.App.Graphics.Graphics_Data_Preview;
      Decoded_Length : Natural;
      Preview_Length : out Natural;
      Preview_Bytes  : out Terminal.Common.Bytes.Byte_Array);

   procedure Copy_Preview
     (Source         : RM.Image_Data_View;
      Decoded_Length : Natural;
      Preview_Length : out Natural;
      Preview_Bytes  : out Terminal.Common.Bytes.Byte_Array);

   procedure Copy_Preview
     (Source         : Terminal.Common.Bytes.Byte_Array;
      Decoded_Length : Natural;
      Preview_Length : out Natural;
      Preview_Bytes  : out Terminal.Common.Bytes.Byte_Array);

   procedure Prepare_Preview_Source
     (Decoded        : RM.Image_Data_View;
      Preview_Length : Natural;
      Preview_Bytes  : Terminal.Common.Bytes.Byte_Array;
      Result         : out RM.Image_Data_View;
      Owner          : in out Terminal.App.Owned_Image_Data.Owner);

   procedure Capture_Preview_Row
     (Preview_Length : in out Natural;
      Preview_Bytes  : in out Terminal.Common.Bytes.Byte_Array;
      Row_Y          : Natural;
      Row            : Terminal.Common.Bytes.Byte_Array;
      Continue       : in out Boolean);

   procedure Capture_Row
     (Data          : Terminal.App.Graphics.Graphics_Data_Preview;
      Image_Owner   : in out Terminal.App.Owned_Image_Data.Owner;
      Row_Y         : Natural;
      Row           : Terminal.Common.Bytes.Byte_Array;
      Max_Bytes     : Positive;
      Max_Dimension : Positive;
      Continue      : in out Boolean);
end Terminal.App.Renderer.Image_Buffers;
