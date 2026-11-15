with Terminal.Common.Status;
with Terminal.App.Render_Model;
with Terminal.App.Status_Labels;
with Terminal.App.Vulkan_Submit;

package body Terminal.App.Vulkan_Device_Diagnostics is
   package VD renames Terminal.App.Vulkan_Device;
   package RM renames Terminal.App.Render_Model;
   package VS renames Terminal.App.Vulkan_Submit;
   use type VS.Texture_Source;

   function Trimmed_Natural (Value : Natural) return String
      renames Terminal.Common.Status.Trimmed_Natural;

   function Bounded (Text : String) return String is
     (Terminal.App.Status_Labels.Bounded
        (Text, VD.Max_Status_Label_Length));

   function Select_Status_Label (Status : VD.Select_Status) return String is
     (Bounded
        ("Select device: "
         & Terminal.App.Status_Labels.Humanize (VD.Select_Status'Image (Status))));

   function Create_Status_Label (Status : VD.Create_Status) return String is
     (Bounded
        ("Create device: "
         & Terminal.App.Status_Labels.Humanize (VD.Create_Status'Image (Status))));

   function Render_Status_Label (Status : VD.Render_Status) return String is
     (Bounded
        ("Render device: "
         & Terminal.App.Status_Labels.Humanize (VD.Render_Status'Image (Status))));

   function Operationally_Equivalent
     (Left, Right : VD.Device_Diagnostic_Snapshot) return Boolean
   is
      use type VD.Device_Operational_Diagnostics;
   begin
      return VD.Device_Operational_Diagnostics (Left) =
        VD.Device_Operational_Diagnostics (Right);
   end Operationally_Equivalent;

   function Image_Status_Label
     (Diagnostics : VD.Device_Diagnostic_Snapshot) return String
   is
      function Protocol_Name return String is
      begin
         case Diagnostics.Uploaded_Image_Protocol is
            when RM.Image_Sixel => return "sixel";
            when RM.Image_Kitty => return "kitty";
            when RM.Image_ITerm2 => return "iTerm2";
         end case;
      end Protocol_Name;
   begin
      if Diagnostics.Uploaded_Image_Command_Count = 0 then
         return "";
      end if;

      return
        "uploaded image " & Protocol_Name
        & " size=" & Trimmed_Natural (Diagnostics.Uploaded_Image_Width)
        & "x" & Trimmed_Natural (Diagnostics.Uploaded_Image_Height)
        & (if Diagnostics.Uploaded_Image_Pixel_Width > 0
           and then Diagnostics.Uploaded_Image_Pixel_Height > 0
           then
             " pixels=" & Trimmed_Natural (Diagnostics.Uploaded_Image_Pixel_Width)
             & "x" & Trimmed_Natural (Diagnostics.Uploaded_Image_Pixel_Height)
             & " format=" & Trimmed_Natural (Diagnostics.Uploaded_Image_Raw_Format)
           else "")
        & " vertices=" & Trimmed_Natural (Diagnostics.Uploaded_Image_Vertex_Count)
        & " payload=" & Trimmed_Natural (Diagnostics.Uploaded_Image_Payload_Length)
        & RM.Image_Payload_Status_Suffix
            (Diagnostics.Uploaded_Image_Payload_Preview_Complete)
        & " preview="
        & Trimmed_Natural (Diagnostics.Uploaded_Image_Decoded_Preview_Length)
        & "/"
        & Trimmed_Natural (Diagnostics.Uploaded_Image_Encoded_Preview_Length)
        & Terminal.Common.Status.Preview_Bytes_Label
            (Diagnostics.Uploaded_Image_Decoded_Preview_Bytes,
             Diagnostics.Uploaded_Image_Decoded_Preview_Length)
        & " texture="
        & VS.Texture_Source_Label (Diagnostics.Uploaded_Image_Texture_Source)
        & (if Diagnostics.Uploaded_Image_Placeholder
           then " placeholder" else " textured")
        & (if Diagnostics.Uploaded_Image_Texture_Downgraded
           then " downgraded" else "")
        & (if Diagnostics.Uploaded_Image_Preview_Decode_Complete
           then " decoded" else " partial")
        & RM.Image_Decode_Status_Suffix
            (Diagnostics.Uploaded_Image_Decode_Status);
   end Image_Status_Label;

   function Image_Texture_Status_Label
     (Diagnostics : VD.Device_Diagnostic_Snapshot) return String is
   begin
      if Diagnostics.Uploaded_Image_Command_Count = 0 then
         return "";
      elsif Diagnostics.Uploaded_Image_Texture_Downgraded then
         return
           "device image texture downgraded; texture="
           & VS.Texture_Source_Label (Diagnostics.Uploaded_Image_Texture_Source)
           & " vertices="
           & Trimmed_Natural (Diagnostics.Uploaded_Image_Texture_Vertex_Count);
      elsif Diagnostics.Uploaded_Image_Texture_Source = VS.Texture_Image
        and then not Diagnostics.Uploaded_Image_Placeholder
      then
         return
           "device image texture ready; vertices="
           & Trimmed_Natural (Diagnostics.Uploaded_Image_Texture_Vertex_Count);
      else
         return
           "device image texture unavailable; texture="
           & VS.Texture_Source_Label (Diagnostics.Uploaded_Image_Texture_Source)
           & " vertices="
           & Trimmed_Natural (Diagnostics.Uploaded_Image_Texture_Vertex_Count);
      end if;
   end Image_Texture_Status_Label;

   function Image_Texture_Resource_Status_Label
     (Diagnostics : VD.Device_Diagnostic_Snapshot) return String is
   begin
      if Diagnostics.Uploaded_Image_Command_Count = 0 then
         return "";
      elsif Diagnostics.Uploaded_Image_Texture_Source /= VS.Texture_Image then
         return
           "device image texture resources inactive; texture="
           & VS.Texture_Source_Label (Diagnostics.Uploaded_Image_Texture_Source)
           & " descriptors="
           & Trimmed_Natural (Diagnostics.Image_Texture_Descriptor_Bound_Count)
           & "/" & Trimmed_Natural (Diagnostics.Image_Texture_Descriptor_Capacity);
      elsif Diagnostics.Uploaded_Image_Texture_Vertex_Count = 0 then
         return
           "device image texture resources unavailable; vertices=0"
           & " descriptors="
           & Trimmed_Natural (Diagnostics.Image_Texture_Descriptor_Bound_Count)
           & "/" & Trimmed_Natural (Diagnostics.Image_Texture_Descriptor_Capacity);
      elsif Diagnostics.Image_Texture_Descriptor_Bound_Count >= 2 then
         return
           "device image texture resources ready; vertices="
           & Trimmed_Natural (Diagnostics.Uploaded_Image_Texture_Vertex_Count)
           & " descriptors="
           & Trimmed_Natural (Diagnostics.Image_Texture_Descriptor_Bound_Count)
           & "/" & Trimmed_Natural (Diagnostics.Image_Texture_Descriptor_Capacity);
      else
         return
           "device image texture resources pending; descriptor=atlas-only"
           & " vertices="
           & Trimmed_Natural (Diagnostics.Uploaded_Image_Texture_Vertex_Count)
           & " descriptors="
           & Trimmed_Natural (Diagnostics.Image_Texture_Descriptor_Bound_Count)
           & "/" & Trimmed_Natural (Diagnostics.Image_Texture_Descriptor_Capacity);
      end if;
   end Image_Texture_Resource_Status_Label;
end Terminal.App.Vulkan_Device_Diagnostics;
