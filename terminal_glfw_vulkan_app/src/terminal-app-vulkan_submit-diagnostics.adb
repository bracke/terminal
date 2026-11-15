with Terminal.Common.Status;
with Terminal.App.Status_Labels;

package body Terminal.App.Vulkan_Submit.Diagnostics is
   package RM renames Terminal.App.Render_Model;
   use type RM.Image_Protocol;

   function Trimmed_Natural (Value : Natural) return String
      renames Terminal.Common.Status.Trimmed_Natural;

   function Status_Label (Status : Build_Status) return String is
      Label : constant String :=
        "Submit build: "
        & Terminal.App.Status_Labels.Humanize (Build_Status'Image (Status));
   begin
      return
        (if Label'Length > Max_Status_Label_Length
         then Label (1 .. Max_Status_Label_Length)
         else Label);
   end Status_Label;

   function Texture_Source_Label (Source : Texture_Source) return String is
     (case Source is
         when Texture_None          => "none",
         when Texture_Text_Atlas    => "text-atlas",
         when Texture_Image         => "image",
         when Texture_Colour_Glyphs => "colour-glyphs");

   function Image_Status_Label (Batch : Submission_Batch) return String
   is
      function Protocol_Name return String is
        (case Batch.Last_Image_Protocol is
            when RM.Image_Sixel  => "sixel",
            when RM.Image_Kitty  => "kitty",
            when RM.Image_ITerm2 => "iTerm2");
   begin
      if Batch.Image_Command_Total = 0 then
         return "";
      end if;

      return
        "submit image " & Protocol_Name
        & " size=" & Trimmed_Natural (Batch.Last_Image_Width)
        & "x" & Trimmed_Natural (Batch.Last_Image_Height)
        & (if Batch.Last_Image_Pixel_Width > 0
           and then Batch.Last_Image_Pixel_Height > 0
           then
             " pixels=" & Trimmed_Natural (Batch.Last_Image_Pixel_Width)
             & "x" & Trimmed_Natural (Batch.Last_Image_Pixel_Height)
             & " format=" & Trimmed_Natural (Batch.Last_Image_Raw_Format)
           else "")
        & " payload=" & Trimmed_Natural (Batch.Last_Image_Payload_Length)
        & RM.Image_Payload_Status_Suffix
            (Batch.Last_Image_Payload_Preview_Complete)
        & " preview="
        & Trimmed_Natural (Batch.Last_Image_Decoded_Preview_Length)
        & "/"
        & Trimmed_Natural (Batch.Last_Image_Encoded_Preview_Length)
        & Terminal.Common.Status.Preview_Bytes_Label
            (Batch.Last_Image_Decoded_Preview_Bytes,
             Batch.Last_Image_Decoded_Preview_Length)
        & " texture=" & Texture_Source_Label (Batch.Last_Image_Texture_Source)
        & (if Batch.Last_Image_Placeholder then " placeholder" else " textured")
        & (if Batch.Last_Image_Texture_Downgraded then " downgraded" else "")
        & (if Batch.Last_Image_Preview_Decode_Complete
           then " decoded"
           else " partial")
        & RM.Image_Decode_Status_Suffix (Batch.Last_Image_Decode_Status);
   end Image_Status_Label;

   function Image_Texture_Status_Label
     (Batch : Submission_Batch) return String is
   begin
      if Batch.Image_Command_Total = 0 then
         return "";
      elsif Batch.Last_Image_Texture_Downgraded then
         return
           "submit image texture downgraded; texture="
           & Texture_Source_Label (Batch.Last_Image_Texture_Source)
           & " vertices=" & Trimmed_Natural (Batch.Image_Texture_Vertex_Total);
      elsif Batch.Last_Image_Texture_Source = Texture_Image
        and then not Batch.Last_Image_Placeholder
      then
         return
           "submit image texture ready; vertices="
           & Trimmed_Natural (Batch.Image_Texture_Vertex_Total);
      else
         return
           "submit image texture unavailable; texture="
           & Texture_Source_Label (Batch.Last_Image_Texture_Source)
           & " vertices=" & Trimmed_Natural (Batch.Image_Texture_Vertex_Total);
      end if;
   end Image_Texture_Status_Label;
end Terminal.App.Vulkan_Submit.Diagnostics;
