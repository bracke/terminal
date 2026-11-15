with Terminal.Common.Bytes;

private package Terminal.App.Vulkan_Submit.Source_Rows is
   function Raw_Format
     (Batch : Submission_Batch; Index : Positive) return Natural;
   function Pixel_Width
     (Batch : Submission_Batch; Index : Positive) return Natural;
   function Pixel_Height
     (Batch : Submission_Batch; Index : Positive) return Natural;
   procedure Read
     (Batch : Submission_Batch;
      Index : Positive;
      Write : not null access procedure
        (Y        : Natural;
         Row      : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Status : out Image_Source_Read_Status);
end Terminal.App.Vulkan_Submit.Source_Rows;
