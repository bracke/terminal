with Terminal.Common.Bytes;
with Terminal.App.Render_Model;

package Terminal.App.Image_Media is
   Max_Frames : constant := 256;

   type Decode_Status is
     (Decode_Ok,
      Decode_Unavailable,
      Decode_Invalid,
      Decode_Too_Large,
      Decode_Allocation_Failed);

   type Frame_Delay_Array is array (Positive range 1 .. Max_Frames) of Natural;

   type Decoded_Image is record
      Pixel_Width  : Natural := 0;
      Pixel_Height : Natural := 0;
      Frame_Count  : Natural range 0 .. Max_Frames := 0;
      Loop_Count   : Natural := 1;
      Frame_Bytes  : Natural := 0;
      Total_Bytes  : Natural := 0;
      Delays_MS    : Frame_Delay_Array := (others => 100);
      Bytes        : Terminal.App.Render_Model.Image_Data_Access := null;
   end record;

   --  Native GIF decoding is always available. Other media formats remain an
   --  optional runtime extension supplied by MagickWand.
   function Available return Boolean;
   function Extended_Media_Available return Boolean;

   procedure Decode
     (Data                    : Terminal.Common.Bytes.Byte_Array;
      Length                  : Natural;
      Maximum_Decoded_Bytes   : Positive;
      Maximum_Pixel_Dimension : Positive;
      Result                  : in out Decoded_Image;
      Status                  : out Decode_Status);

   procedure Release (Result : in out Decoded_Image);
end Terminal.App.Image_Media;
