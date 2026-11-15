package Terminal.Common.Graphics_Limits is
   pragma Pure;

   Max_Transaction_Bytes     : constant Positive := 8 * 1024 * 1024;
   Max_Pending_Events        : constant Positive := 4_096;
   Max_Pending_Bytes         : constant Positive := 16 * 1024 * 1024;
   Max_Deferred_Input_Bytes  : constant Positive := 16 * 1024 * 1024;
   Max_Pixel_Dimension       : constant Positive := 16_384;
   Max_Image_Objects         : constant Positive := 256;
   Max_Image_Bytes           : constant Positive := 64 * 1024 * 1024;
   Max_Placements            : constant Positive := 16 * 1024;
   Max_Animation_Frames      : constant Positive := 4_096;
   Max_Scroll_Events         : constant Positive := 4_096;
   Max_Core_Preview_Bytes    : constant Positive := 128 * 1024;
   Max_Decoded_Preview_Bytes : constant Positive := 4_096;
   Max_OSC_Bytes             : constant Positive := 1024 * 1024;
   Max_Escape_Preview_Bytes  : constant Positive := 128 * 1024;

end Terminal.Common.Graphics_Limits;
