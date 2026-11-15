with Terminal.Common.Graphics_Limits;

package Terminal.App.Vulkan_Limits is
   --  Backend-specific atlas bounds stay with the Vulkan application layer;
   --  terminal_common contains only protocol and resource-model limits.
   Max_Atlas_Bytes       : constant Positive :=
     Terminal.Common.Graphics_Limits.Max_Image_Bytes;
   Max_Atlas_Dimension   : constant Positive :=
     Terminal.Common.Graphics_Limits.Max_Pixel_Dimension;
   Min_Atlas_Bytes       : constant Positive :=
     Terminal.Common.Graphics_Limits.Max_Image_Objects * 3 * 3 * 4;
   Min_Atlas_Dimension   : constant Positive :=
     Terminal.Common.Graphics_Limits.Max_Image_Objects * 3;
   Default_Atlas_Bytes   : constant Positive := 4 * 1024 * 1024;
   Default_Atlas_Dimension : constant Positive := 4_096;
end Terminal.App.Vulkan_Limits;
